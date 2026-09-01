import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/price_label.dart';

class ManagerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const ManagerOrderDetailScreen({super.key, required this.orderId});

  @override
  State<ManagerOrderDetailScreen> createState() =>
      _ManagerOrderDetailScreenState();
}

class _ManagerOrderDetailScreenState extends State<ManagerOrderDetailScreen> {
  late Future<Map<String, dynamic>> _order = _load();
  String? _selectedDriverId;

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    await Supabase.instance.client
        .from('orders')
        .select(
          'id,branch_id,daily_order_number,fulfillment,status,total_kopeks,contact_name,contact_phone,pickup_at,delivery_scheduled_at,delivery_address,delivery_distance_meters,delivery_fee_kopeks,delivery_driver_id,driver_name,customer_notes,'
          'order_items(item_name,variant_name,quantity,line_total_kopeks,special_instructions,modifier_snapshot,localization_snapshot)',
        )
        .eq('id', widget.orderId)
        .single(),
  );

  Future<void> _updateStatus(String status, {String? reason}) async {
    final current = await _order;
    if (status == 'out_for_delivery') {
      final driverId =
          _selectedDriverId ?? current['delivery_driver_id'] as String?;
      if (driverId == null) {
        throw StateError('Сначала выберите водителя');
      }
      await Supabase.instance.client.rpc(
        'assign_order_driver',
        params: {'p_order_id': widget.orderId, 'p_driver_id': driverId},
      );
    }
    await Supabase.instance.client.rpc(
      'manager_update_order_status',
      params: {
        'p_order_id': widget.orderId,
        'p_next_status': status,
        'p_reason': reason,
      },
    );
    if (mounted) {
      setState(() {
        _order = _load();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadDrivers(String branchId) async {
    final response = await Supabase.instance.client.rpc(
      'get_branch_drivers_for_assignment',
      params: {'p_branch_id': branchId},
    );
    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  Future<void> _cancelOrder() async {
    final locale = context.read<AppLocale>();
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          locale.text(
            ru: 'Отменить заказ?',
            en: 'Cancel order?',
            ar: 'إلغاء الطلب؟',
          ),
        ),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: locale.text(
              ru: 'Причина для клиента (необязательно)',
              en: 'Reason for customer (optional)',
              ar: 'سبب للعميل (اختياري)',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(locale.text(ru: 'Назад', en: 'Back', ar: 'رجوع')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text(locale.text(ru: 'Отменить', en: 'Cancel', ar: 'إلغاء')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus('cancelled', reason: reason.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale.text(
            ru: 'Детали заказа',
            en: 'Order details',
            ar: 'تفاصيل الطلب',
          ),
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _order,
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
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final order = snapshot.data!;
          final status = order['status'] as String;
          final isDelivery = order['fulfillment'] == 'delivery';
          final items = List<Map<String, dynamic>>.from(
            order['order_items'] as List<dynamic>? ?? const [],
          );
          final nextStatus = _nextStatus(status, isDelivery);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                locale.orderNumber(order['daily_order_number']),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(locale.databaseOrderStatus(status)),
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 20),
              _DetailBlock(
                icon: Icons.person_outline_rounded,
                title: locale.text(ru: 'Клиент', en: 'Customer', ar: 'العميل'),
                lines: [
                  order['contact_name'] as String,
                  if ((order['contact_phone'] as String? ?? '').isNotEmpty)
                    order['contact_phone'] as String,
                ],
              ),
              _DetailBlock(
                icon: Icons.schedule_outlined,
                title: locale.text(
                  ru: isDelivery ? 'Доставка' : 'Получение',
                  en: isDelivery ? 'Delivery' : 'Pickup',
                  ar: isDelivery ? 'التوصيل' : 'الاستلام',
                ),
                lines: [
                  (isDelivery
                              ? order['delivery_scheduled_at']
                              : order['pickup_at']) ==
                          null
                      ? locale.asSoonAsReady
                      : _formatDate(
                          DateTime.parse(
                            (isDelivery
                                    ? order['delivery_scheduled_at']
                                    : order['pickup_at'])
                                as String,
                          ).toLocal(),
                        ),
                  isDelivery
                      ? locale.text(
                          ru: 'Наличными при доставке',
                          en: 'Cash on delivery',
                          ar: 'الدفع نقداً عند التوصيل',
                        )
                      : locale.cashAtPickup,
                ],
              ),
              if (isDelivery) ...[
                _DetailBlock(
                  icon: Icons.location_on_outlined,
                  title: locale.text(
                    ru: 'Адрес доставки',
                    en: 'Delivery address',
                    ar: 'عنوان التوصيل',
                  ),
                  lines: [
                    order['delivery_address'] as String? ?? '',
                    if (order['delivery_distance_meters'] != null)
                      '${((order['delivery_distance_meters'] as int) / 1000).toStringAsFixed(1)} км',
                  ],
                ),
                if (status == 'preparing' || status == 'out_for_delivery')
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadDrivers(order['branch_id'] as String),
                    builder: (context, driversSnapshot) {
                      final drivers =
                          driversSnapshot.data ??
                          const <Map<String, dynamic>>[];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              _selectedDriverId ??
                              order['delivery_driver_id'] as String?,
                          decoration: InputDecoration(
                            labelText: locale.text(
                              ru: 'Водитель доставки',
                              en: 'Delivery driver',
                              ar: 'سائق التوصيل',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          items: drivers
                              .map(
                                (driver) => DropdownMenuItem<String>(
                                  value: driver['id'] as String,
                                  child: Text(
                                    '${driver['full_name']}${(driver['phone'] as String? ?? '').isEmpty ? '' : ' · ${driver['phone']}'}',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: status == 'preparing'
                              ? (value) =>
                                    setState(() => _selectedDriverId = value)
                              : null,
                        ),
                      );
                    },
                  ),
              ],
              if ((order['customer_notes'] as String? ?? '').trim().isNotEmpty)
                _DetailBlock(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: locale.text(
                    ru: 'Комментарий клиента',
                    en: 'Customer note',
                    ar: 'ملاحظة العميل',
                  ),
                  lines: [order['customer_notes'] as String],
                ),
              const SizedBox(height: 16),
              Text(
                locale.text(
                  ru: 'Состав заказа',
                  en: 'Order items',
                  ar: 'محتويات الطلب',
                ),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => _OrderItemCard(item: item)),
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  locale.total,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: PriceLabel(
                  price: (order['total_kopeks'] as int) / 100,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (nextStatus != null)
                FilledButton(
                  onPressed: () async {
                    try {
                      await _updateStatus(nextStatus);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.toString().replaceFirst('Bad state: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_nextLabel(nextStatus, locale)),
                ),
              if (!_isFinished(status)) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _cancelOrder,
                  child: Text(
                    locale.text(
                      ru: 'Отменить заказ',
                      en: 'Cancel order',
                      ar: 'إلغاء الطلب',
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String? _nextStatus(String status, bool isDelivery) {
    // Delivery replaces the pickup-only "ready" step with dispatch.
    return switch (status) {
      'pending' => 'accepted',
      'accepted' => 'preparing',
      'preparing' => isDelivery ? 'out_for_delivery' : 'ready_for_pickup',
      'ready_for_pickup' => 'completed',
      'out_for_delivery' => 'completed',
      _ => null,
    };
  }

  String _nextLabel(String status, AppLocale locale) => switch (status) {
    'accepted' => locale.text(
      ru: 'Принять заказ',
      en: 'Accept order',
      ar: 'قبول الطلب',
    ),
    'preparing' => locale.text(
      ru: 'Начать готовить',
      en: 'Start preparing',
      ar: 'بدء التحضير',
    ),
    'out_for_delivery' => locale.text(
      ru: 'Передать водителю',
      en: 'Send with driver',
      ar: 'إرسال مع السائق',
    ),
    'ready_for_pickup' => locale.text(
      ru: 'Отметить готовым',
      en: 'Mark as ready',
      ar: 'تحديد كجاهز',
    ),
    'completed' => locale.text(
      ru: 'Отметить выданным',
      en: 'Mark as completed',
      ar: 'تحديد كمكتمل',
    ),
    _ => locale.text(
      ru: 'Обновить заказ',
      en: 'Update order',
      ar: 'تحديث الطلب',
    ),
  };

  bool _isFinished(String status) =>
      ['completed', 'cancelled', 'rejected'].contains(status);

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _DetailBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  const _DetailBlock({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              ...lines.map(
                (line) => Text(
                  line,
                  style: GoogleFonts.inter(color: AppTheme.secondary),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OrderItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _OrderItemCard({required this.item});

  Map<String, dynamic> _localizedSnapshot(AppLocale locale) {
    final raw = item['localization_snapshot'];
    if (raw is! Map) return const {};
    final selected = raw[locale.languageCode] ?? raw['ru'];
    return selected is Map ? Map<String, dynamic>.from(selected) : const {};
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final localized = _localizedSnapshot(locale);
    final modifierSource =
        localized['modifiers'] ?? item['modifier_snapshot'] ?? const [];
    final modifiers = List<Map<String, dynamic>>.from(
      modifierSource as List<dynamic>,
    );
    final notes = item['special_instructions'] as String? ?? '';
    final itemName = localized['item_name'] ?? item['item_name'];
    final variantName = localized['variant_name'] ?? item['variant_name'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${item['quantity']} × $itemName',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(variantName as String),
            if (modifiers.isNotEmpty)
              Text(
                modifiers
                    .map((option) => option['option_name'] ?? option['name'])
                    .join(', '),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.secondary,
                ),
              ),
            if (notes.trim().isNotEmpty)
              Text(
                notes,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary),
              ),
          ],
        ),
        trailing: PriceLabel(price: (item['line_total_kopeks'] as int) / 100),
      ),
    );
  }
}
