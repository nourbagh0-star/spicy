import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  _DashboardDateRange _dateRange = _DashboardDateRange.today;
  DateTime _selectedDay = DateTime.now();
  String? _reviewBranchFilter;
  int? _reviewRatingFilter;
  late Future<List<Map<String, dynamic>>> _orders = _loadOrders();
  late Future<List<Map<String, dynamic>>> _reviews = _loadReviews();

  Future<List<Map<String, dynamic>>> _loadReviews() async {
    final response = await Supabase.instance.client
        .from('order_reviews')
        .select('id,rating,comment,created_at,branches(name)')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    final day = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final start = switch (_dateRange) {
      _DashboardDateRange.today => day,
      _DashboardDateRange.yesterday => day.subtract(const Duration(days: 1)),
      _DashboardDateRange.last7Days => day.subtract(const Duration(days: 6)),
      _DashboardDateRange.customDay => day,
    };
    final end = switch (_dateRange) {
      _DashboardDateRange.last7Days => day.add(const Duration(days: 1)),
      _ => start.add(const Duration(days: 1)),
    };
    final response = await Supabase.instance.client
        .from('orders')
        .select(
          'id, daily_order_number, status, total_kopeks, created_at, branches(name)',
        )
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(response);
  }

  String _dateRangeLabel(AppLocale locale) => switch (_dateRange) {
    _DashboardDateRange.today => locale.text(
      ru: 'Сегодня',
      en: 'Today',
      ar: 'اليوم',
    ),
    _DashboardDateRange.yesterday => locale.text(
      ru: 'Вчера',
      en: 'Yesterday',
      ar: 'أمس',
    ),
    _DashboardDateRange.last7Days => locale.text(
      ru: 'Последние 7 дней',
      en: 'Last 7 days',
      ar: 'آخر 7 أيام',
    ),
    _DashboardDateRange.customDay =>
      '${_selectedDay.day.toString().padLeft(2, '0')}.${_selectedDay.month.toString().padLeft(2, '0')}.${_selectedDay.year}',
  };

  Future<void> _changeDateRange(_DashboardDateRange range) async {
    final locale = context.read<AppLocale>();
    var selectedDay = DateTime.now();
    if (range == _DashboardDateRange.customDay) {
      final day = await showDatePicker(
        context: context,
        initialDate: _selectedDay,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        helpText: locale.text(
          ru: 'Выберите дату',
          en: 'Choose a date',
          ar: 'اختر تاريخاً',
        ),
      );
      if (day == null || !mounted) return;
      selectedDay = day;
    }
    if (!mounted) return;
    setState(() {
      _dateRange = range;
      _selectedDay = selectedDay;
      _orders = _loadOrders();
      _reviews = _loadReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          locale.text(
            ru: 'Панель владельца',
            en: 'Owner Dashboard',
            ar: 'لوحة المالك',
          ),
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: locale.logout,
            onPressed: () => context.read<AuthCubit>().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return _DashboardError(error: snapshot.error.toString());
          }
          final orders = snapshot.data ?? const [];
          final validOrders = orders
              .where(
                (order) => !['cancelled', 'rejected'].contains(order['status']),
              )
              .toList(growable: false);
          final total = validOrders.fold<int>(
            0,
            (sum, order) => sum + (order['total_kopeks'] as int),
          );
          final active = orders.where((order) {
            final status = order['status'] as String;
            return !['completed', 'cancelled', 'rejected'].contains(status);
          }).length;
          final branches = <String, List<Map<String, dynamic>>>{};
          for (final order in validOrders) {
            final branch = order['branches'] as Map<String, dynamic>?;
            final name =
                branch?['name'] as String? ??
                locale.text(ru: 'Филиал', en: 'Branch', ar: 'الفرع');
            (branches[name] ??= []).add(order);
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              setState(() {
                _orders = _loadOrders();
                _reviews = _loadReviews();
              });
              await _orders;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  locale.text(
                    ru: 'Здравствуйте, ${user.name}',
                    en: 'Hello, ${user.name}',
                    ar: 'مرحباً، ${user.name}',
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${locale.text(ru: 'Все филиалы', en: 'All branches', ar: 'كل الفروع')} · ${_dateRangeLabel(locale)}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _DateRangePicker(
                  selected: _dateRange,
                  label: _dateRangeLabel(locale),
                  onSelected: _changeDateRange,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.receipt_long_rounded,
                        label: locale.orders,
                        value: '${validOrders.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.payments_outlined,
                        label: locale.text(
                          ru: 'Сумма заказов',
                          en: 'Order revenue',
                          ar: 'إجمالي الطلبات',
                        ),
                        valueWidget: PriceLabel(
                          price: total / 100,
                          style: GoogleFonts.inter(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onBackground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (active > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    locale.text(
                      ru: 'В работе: $active',
                      en: 'In progress: $active',
                      ar: 'قيد التنفيذ: $active',
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    locale.text(
                      ru: 'По филиалам',
                      en: 'By branch',
                      ar: 'حسب الفرع',
                    ),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...branches.entries.map(
                    (entry) => _BranchSummaryCard(
                      name: entry.key,
                      orders: entry.value,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  locale.text(
                    ru: 'Управление',
                    en: 'Management',
                    ar: 'الإدارة',
                  ),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _ManagementCard(
                  icon: Icons.restaurant_menu_rounded,
                  title: locale.text(
                    ru: 'Меню и цены',
                    en: 'Menu and prices',
                    ar: 'القائمة والأسعار',
                  ),
                  subtitle: locale.text(
                    ru: 'Блюда, варианты, изображения и доступность',
                    en: 'Items, options, images and availability',
                    ar: 'الأصناف والخيارات والصور والتوفر',
                  ),
                  onTap: () => context.push('/owner/menu'),
                ),
                _ManagementCard(
                  icon: Icons.tune_rounded,
                  title: locale.text(
                    ru: 'Добавки и удаления',
                    en: 'Add-ons and removals',
                    ar: 'الإضافات والحذف',
                  ),
                  subtitle: locale.text(
                    ru: 'Бесплатные или платные опции для каждого блюда',
                    en: 'Free or paid choices for each item',
                    ar: 'خيارات مجانية أو مدفوعة لكل صنف',
                  ),
                  onTap: () => context.push('/owner/modifiers'),
                ),
                _ManagementCard(
                  icon: Icons.storefront_rounded,
                  title: locale.text(
                    ru: 'Филиалы и менеджеры',
                    en: 'Branches and managers',
                    ar: 'الفروع والمديرون',
                  ),
                  subtitle: locale.text(
                    ru: 'Адреса, работа филиалов и доступ сотрудников',
                    en: 'Addresses, branch operations and staff access',
                    ar: 'العناوين وتشغيل الفروع وصلاحيات الموظفين',
                  ),
                  onTap: () => context.push('/owner/branches'),
                ),
                _ManagementCard(
                  icon: Icons.delivery_dining_rounded,
                  title: locale.text(
                    ru: 'Доставка и водители',
                    en: 'Delivery and drivers',
                    ar: 'التوصيل والسائقون',
                  ),
                  subtitle: locale.text(
                    ru: 'Радиус, тарифы и список водителей для каждого филиала',
                    en: 'Radius, fees, and driver lists for every branch',
                    ar: 'النطاق والرسوم وقائمة السائقين لكل فرع',
                  ),
                  onTap: () => context.go('/owner/delivery'),
                ),
                const SizedBox(height: 28),
                Text(
                  locale.text(
                    ru: 'Последние отзывы',
                    en: 'Latest reviews',
                    ar: 'أحدث التقييمات',
                  ),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _reviews,
                  builder: (context, reviewsSnapshot) {
                    if (reviewsSnapshot.connectionState !=
                        ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (reviewsSnapshot.hasError) {
                      return Text(
                        locale.text(
                          ru: 'Не удалось загрузить отзывы.',
                          en: 'Could not load reviews.',
                          ar: 'تعذر تحميل التقييمات.',
                        ),
                      );
                    }
                    final allReviews = reviewsSnapshot.data ?? const [];
                    final branchNames =
                        allReviews
                            .map(
                              (review) =>
                                  (review['branches']
                                          as Map<String, dynamic>?)?['name']
                                      as String? ??
                                  locale.text(
                                    ru: 'Филиал',
                                    en: 'Branch',
                                    ar: 'الفرع',
                                  ),
                            )
                            .toSet()
                            .toList()
                          ..sort();
                    final reviews = allReviews
                        .where((review) {
                          final branchName =
                              (review['branches']
                                      as Map<String, dynamic>?)?['name']
                                  as String? ??
                              locale.text(
                                ru: 'Филиал',
                                en: 'Branch',
                                ar: 'الفرع',
                              );
                          final rating = review['rating'] as int;
                          return (_reviewBranchFilter == null ||
                                  _reviewBranchFilter == branchName) &&
                              (_reviewRatingFilter == null ||
                                  _reviewRatingFilter == rating);
                        })
                        .toList(growable: false);
                    final filters = Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 240,
                          child: _ReviewFilter<String>(
                            label: locale.text(
                              ru: 'Филиал',
                              en: 'Branch',
                              ar: 'الفرع',
                            ),
                            value: _reviewBranchFilter,
                            allLabel: locale.text(
                              ru: 'Все филиалы',
                              en: 'All branches',
                              ar: 'كل الفروع',
                            ),
                            values: branchNames,
                            onChanged: (value) =>
                                setState(() => _reviewBranchFilter = value),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: _ReviewFilter<int>(
                            label: locale.text(
                              ru: 'Оценка',
                              en: 'Rating',
                              ar: 'التقييم',
                            ),
                            value: _reviewRatingFilter,
                            allLabel: locale.text(
                              ru: 'Все оценки',
                              en: 'All ratings',
                              ar: 'كل التقييمات',
                            ),
                            values: List.generate(5, (index) => index + 1),
                            valueLabel: (rating) => '$rating ★',
                            onChanged: (value) =>
                                setState(() => _reviewRatingFilter = value),
                          ),
                        ),
                      ],
                    );
                    if (allReviews.isEmpty) {
                      return Text(locale.noReviews);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        filters,
                        const SizedBox(height: 12),
                        if (reviews.isEmpty)
                          Text(
                            locale.text(
                              ru: 'По выбранным фильтрам отзывов нет.',
                              en: 'No reviews match the selected filters.',
                              ar: 'لا توجد تقييمات تطابق عوامل التصفية المختارة.',
                            ),
                          )
                        else
                          ...reviews.map(
                            (review) => _OwnerReviewCard(review: review),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  locale.text(
                    ru: 'Заказы за выбранный период',
                    en: 'Orders for selected period',
                    ar: 'طلبات الفترة المختارة',
                  ),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (orders.isEmpty)
                  const _EmptyOrders()
                else
                  ...orders.map(
                    (order) => _OwnerOrderCard(
                      order: order,
                      onTap: () => context.push('/tracking/${order['id']}'),
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
                            _orders = _loadOrders();
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
  }
}

class _ReviewFilter<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String allLabel;
  final List<T> values;
  final String Function(T value)? valueLabel;
  final ValueChanged<T?> onChanged;

  const _ReviewFilter({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.values,
    required this.onChanged,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 2),
      DropdownButton<T?>(
        value: value,
        isExpanded: true,
        underline: Container(height: 1, color: AppTheme.primary),
        items: [
          DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
          ...values.map(
            (item) => DropdownMenuItem<T?>(
              value: item,
              child: Text(valueLabel?.call(item) ?? item.toString()),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    ],
  );
}

class _OwnerReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _OwnerReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final branch = review['branches'] as Map<String, dynamic>?;
    final rating = review['rating'] as int;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.star_rounded, color: Color(0xFFF9A825)),
        title: Text(
          '${locale.ratingOutOfFive(rating)} · ${branch?['name'] ?? locale.text(ru: 'Филиал', en: 'Branch', ar: 'الفرع')}',
        ),
        subtitle: Text(review['comment'] as String),
      ),
    );
  }
}

enum _DashboardDateRange { today, yesterday, last7Days, customDay }

class _DateRangePicker extends StatelessWidget {
  final _DashboardDateRange selected;
  final String label;
  final Future<void> Function(_DashboardDateRange value) onSelected;
  const _DateRangePicker({
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _dateChip(
        context.watch<AppLocale>().text(
          ru: 'Сегодня',
          en: 'Today',
          ar: 'اليوم',
        ),
        _DashboardDateRange.today,
      ),
      _dateChip(
        context.watch<AppLocale>().text(
          ru: 'Вчера',
          en: 'Yesterday',
          ar: 'أمس',
        ),
        _DashboardDateRange.yesterday,
      ),
      _dateChip(
        context.watch<AppLocale>().text(
          ru: '7 дней',
          en: '7 days',
          ar: '7 أيام',
        ),
        _DashboardDateRange.last7Days,
      ),
      ActionChip(
        avatar: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text(
          selected == _DashboardDateRange.customDay
              ? label
              : context.watch<AppLocale>().text(
                  ru: 'Дата',
                  en: 'Date',
                  ar: 'التاريخ',
                ),
        ),
        onPressed: () => onSelected(_DashboardDateRange.customDay),
      ),
    ],
  );

  Widget _dateChip(String text, _DashboardDateRange value) => ChoiceChip(
    label: Text(text),
    selected: selected == value,
    selectedColor: AppTheme.primary.withValues(alpha: 0.16),
    onSelected: (_) => onSelected(value),
  );
}

class _BranchSummaryCard extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> orders;
  const _BranchSummaryCard({required this.name, required this.orders});

  @override
  Widget build(BuildContext context) {
    final total = orders.fold<int>(
      0,
      (sum, order) => sum + (order['total_kopeks'] as int),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0x1A6B6661)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.watch<AppLocale>().text(
                  ru: '${orders.length} заказов',
                  en: '${orders.length} orders',
                  ar: '${orders.length} طلبات',
                ),
                style: GoogleFonts.inter(fontSize: 12),
              ),
              const SizedBox(height: 3),
              PriceLabel(
                price: total / 100,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  const _MetricCard({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(color: const Color(0x1A6B6661)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(height: 16),
        valueWidget ??
            Text(
              value ?? '',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.secondary),
        ),
      ],
    ),
  );
}

class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ManagementCard({
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0x1A6B6661)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 14),
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
          Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
        ],
      ),
    ),
  );
}

class _OwnerOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final Future<void> Function(String nextStatus) onStatusChanged;
  const _OwnerOrderCard({
    required this.order,
    required this.onTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final branch = order['branches'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        title: Text(
          locale.orderNumber(order['daily_order_number']),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${branch?['name'] ?? locale.text(ru: 'Филиал', en: 'Branch', ar: 'الفرع')} · ${locale.databaseOrderStatus(order['status'] as String)}',
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PriceLabel(
              price: (order['total_kopeks'] as int) / 100,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            if (_nextStatus != null)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: onStatusChanged,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _nextStatus!,
                    child: Text(_nextLabel(locale)),
                  ),
                ],
                child: Text(
                  _nextLabel(locale),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? get _nextStatus => switch (order['status'] as String) {
    'pending' => 'accepted',
    'accepted' => 'preparing',
    'preparing' => 'ready_for_pickup',
    'ready_for_pickup' => 'completed',
    _ => null,
  };

  String _nextLabel(AppLocale locale) => switch (_nextStatus) {
    'accepted' => locale.text(ru: 'Принять', en: 'Accept', ar: 'قبول'),
    'preparing' => locale.text(ru: 'Готовить', en: 'Prepare', ar: 'تحضير'),
    'ready_for_pickup' => locale.text(ru: 'Готов', en: 'Ready', ar: 'جاهز'),
    'completed' => locale.text(ru: 'Завершить', en: 'Complete', ar: 'إكمال'),
    _ => '',
  };
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: Text(context.watch<AppLocale>().noOrders)),
  );
}

class _DashboardError extends StatelessWidget {
  final String error;
  const _DashboardError({required this.error});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        context.watch<AppLocale>().text(
          ru: 'Не удалось загрузить панель: $error',
          en: 'Could not load dashboard: $error',
          ar: 'تعذر تحميل لوحة التحكم: $error',
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
