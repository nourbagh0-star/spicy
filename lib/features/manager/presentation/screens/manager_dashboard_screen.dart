import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:go_router/go_router.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  _ManagerDateRange _dateRange = _ManagerDateRange.today;
  DateTime _selectedDay = DateTime.now();
  late Future<_ManagerData> _data = _load();
  RealtimeChannel? _ordersChannel;
  String? _subscribedBranchId;

  void _ensureLiveOrders(String branchId) {
    if (_subscribedBranchId == branchId) return;
    final previousChannel = _ordersChannel;
    if (previousChannel != null) {
      Supabase.instance.client.removeChannel(previousChannel);
    }
    _subscribedBranchId = branchId;
    _ordersChannel = Supabase.instance.client
        .channel('manager-branch-orders-$branchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'branch_id',
            value: branchId,
          ),
          callback: (_) {
            if (mounted) {
              setState(() {
                _data = _load();
              });
            }
          },
        )
        .subscribe();
  }

  Future<_ManagerData> _load() async {
    final db = Supabase.instance.client;
    final userId = db.auth.currentUser!.id;
    final profile = await db
        .from('profiles')
        .select('assigned_branch_id')
        .eq('id', userId)
        .maybeSingle();
    final branchId = profile?['assigned_branch_id'] as String?;
    if (branchId == null) {
      throw StateError('Вам ещё не назначили филиал. Обратитесь к владельцу.');
    }
    final branch = await db
        .from('branches')
        .select('name,address')
        .eq('id', branchId)
        .single();
    final day = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final start = switch (_dateRange) {
      _ManagerDateRange.today => day,
      _ManagerDateRange.yesterday => day.subtract(const Duration(days: 1)),
      _ManagerDateRange.last7Days => day.subtract(const Duration(days: 6)),
      _ManagerDateRange.customDay => day,
    };
    final end = _dateRange == _ManagerDateRange.last7Days
        ? day.add(const Duration(days: 1))
        : start.add(const Duration(days: 1));
    final orders = List<Map<String, dynamic>>.from(
      await db
          .from('orders')
          .select(
            'id,daily_order_number,status,total_kopeks,created_at,contact_name,contact_phone,pickup_at',
          )
          .eq('branch_id', branchId)
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(100),
    );
    final reviews = List<Map<String, dynamic>>.from(
      await db
          .from('order_reviews')
          .select('id,rating,comment,created_at')
          .eq('branch_id', branchId)
          .order('created_at', ascending: false)
          .limit(20),
    );
    return _ManagerData(
      branchId: branchId,
      branchName: branch['name'] as String,
      address: branch['address'] as String,
      orders: orders,
      reviews: reviews,
    );
  }

  String get _dateLabel => switch (_dateRange) {
    _ManagerDateRange.today => 'Сегодня',
    _ManagerDateRange.yesterday => 'Вчера',
    _ManagerDateRange.last7Days => 'Последние 7 дней',
    _ManagerDateRange.customDay =>
      '${_selectedDay.day.toString().padLeft(2, '0')}.${_selectedDay.month.toString().padLeft(2, '0')}.${_selectedDay.year}',
  };

  Future<void> _selectDateRange(_ManagerDateRange range) async {
    var selectedDay = DateTime.now();
    if (range == _ManagerDateRange.customDay) {
      final day = await showDatePicker(
        context: context,
        initialDate: _selectedDay,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        helpText: 'Выберите дату',
      );
      if (day == null || !mounted) return;
      selectedDay = day;
    }
    if (!mounted) return;
    setState(() {
      _dateRange = range;
      _selectedDay = selectedDay;
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Панель менеджера',
        style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: 'Выйти',
          onPressed: () => context.read<AuthCubit>().logout(),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: FutureBuilder<_ManagerData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.error.toString().replaceFirst('Bad state: ', ''),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.secondary),
              ),
            ),
          );
        }
        final data = snapshot.data!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensureLiveOrders(data.branchId);
        });
        final openOrders = data.orders
            .where((order) => !_isFinished(order['status'] as String))
            .toList(growable: false);
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            setState(() {
              _data = _load();
            });
            await _data;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                data.branchName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.address,
                style: GoogleFonts.inter(color: AppTheme.secondary),
              ),
              const SizedBox(height: 14),
              _ManagerDatePicker(
                selected: _dateRange,
                label: _dateLabel,
                onSelected: _selectDateRange,
              ),
              const SizedBox(height: 22),
              _OpenOrderMetric(value: openOrders.length),
              const SizedBox(height: 12),
              _ManagerActionCard(
                icon: Icons.restaurant_menu_rounded,
                title: 'Наличие меню',
                subtitle: 'Отметить, что есть или временно нет',
                onTap: () => context.push('/manager/menu'),
              ),
              const SizedBox(height: 28),
              Text(
                'Отзывы филиала',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (data.reviews.isEmpty)
                const Text('Отзывов пока нет.')
              else
                ...data.reviews.map(
                  (review) => _ManagerReviewCard(review: review),
                ),
              const SizedBox(height: 28),
              Text(
                'Заказы · $_dateLabel',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (data.orders.isEmpty)
                const _ManagerEmptyOrders()
              else
                ...data.orders.map(
                  (order) => _ManagerOrderCard(
                    order: order,
                    onTap: () => context.push('/manager/order/${order['id']}'),
                    onStatusChanged: (nextStatus) async {
                      await Supabase.instance.client.rpc(
                        'manager_update_order_status',
                        params: {
                          'p_order_id': order['id'],
                          'p_next_status': nextStatus,
                        },
                      );
                      if (mounted) {
                        setState(() {
                          _data = _load();
                        });
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  bool _isFinished(String status) =>
      ['completed', 'cancelled', 'rejected'].contains(status);

  @override
  void dispose() {
    final ordersChannel = _ordersChannel;
    if (ordersChannel != null) {
      Supabase.instance.client.removeChannel(ordersChannel);
    }
    super.dispose();
  }
}

enum _ManagerDateRange { today, yesterday, last7Days, customDay }

class _ManagerDatePicker extends StatelessWidget {
  final _ManagerDateRange selected;
  final String label;
  final Future<void> Function(_ManagerDateRange range) onSelected;
  const _ManagerDatePicker({
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _chip('Сегодня', _ManagerDateRange.today),
      _chip('Вчера', _ManagerDateRange.yesterday),
      _chip('7 дней', _ManagerDateRange.last7Days),
      ActionChip(
        avatar: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text(selected == _ManagerDateRange.customDay ? label : 'Дата'),
        onPressed: () => onSelected(_ManagerDateRange.customDay),
      ),
    ],
  );

  Widget _chip(String text, _ManagerDateRange range) => ChoiceChip(
    label: Text(text),
    selected: selected == range,
    selectedColor: AppTheme.primary.withValues(alpha: 0.16),
    onSelected: (_) => onSelected(range),
  );
}

class _ManagerData {
  final String branchId;
  final String branchName;
  final String address;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> reviews;
  const _ManagerData({
    required this.branchId,
    required this.branchName,
    required this.address,
    required this.orders,
    required this.reviews,
  });
}

class _ManagerReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ManagerReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int;
    final createdAt = DateTime.parse(review['created_at'] as String).toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, color: const Color(0xFFF9A825)),
                const SizedBox(width: 4),
                Text(
                  '$rating из 5',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}',
                  style: TextStyle(color: AppTheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review['comment'] as String),
          ],
        ),
      ),
    );
  }
}

class _ManagerActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ManagerActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0x1A6B6661)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
        ],
      ),
    ),
  );
}

class _OpenOrderMetric extends StatelessWidget {
  final int value;
  const _OpenOrderMetric({required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(color: const Color(0x1A6B6661)),
    ),
    child: Row(
      children: [
        const Icon(Icons.receipt_long_rounded, color: AppTheme.primary),
        const SizedBox(width: 12),
        Text('В работе', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(
          '$value',
          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ManagerOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final Future<void> Function(String nextStatus) onStatusChanged;
  const _ManagerOrderCard({
    required this.order,
    required this.onTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nextStatus = switch (order['status'] as String) {
      'pending' => 'accepted',
      'accepted' => 'preparing',
      'preparing' => 'ready_for_pickup',
      'ready_for_pickup' => 'completed',
      _ => null,
    };
    final nextLabel = switch (nextStatus) {
      'accepted' => 'Принять',
      'preparing' => 'Готовить',
      'ready_for_pickup' => 'Готов',
      'completed' => 'Выдан',
      _ => '',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заказ №${order['daily_order_number']}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order['contact_name']} · ${_statusLabel(order['status'] as String)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PriceLabel(
                    price: (order['total_kopeks'] as int) / 100,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (nextStatus != null)
                    TextButton(
                      onPressed: () => onStatusChanged(nextStatus),
                      child: Text(nextLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'pending' => 'Новый',
    'accepted' => 'Принят',
    'preparing' => 'Готовится',
    'ready_for_pickup' => 'Готов',
    'completed' => 'Завершён',
    'cancelled' => 'Отменён',
    'rejected' => 'Отклонён',
    _ => status,
  };
}

class _ManagerEmptyOrders extends StatelessWidget {
  const _ManagerEmptyOrders();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Text(
        'Для этого филиала пока нет заказов.',
        style: GoogleFonts.inter(color: AppTheme.secondary),
      ),
    ),
  );
}
