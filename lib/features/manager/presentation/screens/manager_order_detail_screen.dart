import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    await Supabase.instance.client
        .from('orders')
        .select(
          'id,daily_order_number,status,total_kopeks,contact_name,contact_phone,pickup_at,customer_notes,'
          'order_items(item_name,variant_name,quantity,line_total_kopeks,special_instructions,modifier_snapshot)',
        )
        .eq('id', widget.orderId)
        .single(),
  );

  Future<void> _updateStatus(String status, {String? reason}) async {
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

  Future<void> _cancelOrder() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заказ?'),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Причина для клиента (необязательно)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus('cancelled', reason: reason.text);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Детали заказа',
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
        final items = List<Map<String, dynamic>>.from(
          order['order_items'] as List<dynamic>? ?? const [],
        );
        final nextStatus = _nextStatus(status);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Заказ №${order['daily_order_number']}',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(_statusLabel(status)),
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 20),
            _DetailBlock(
              icon: Icons.person_outline_rounded,
              title: 'Клиент',
              lines: [
                order['contact_name'] as String,
                if ((order['contact_phone'] as String? ?? '').isNotEmpty)
                  order['contact_phone'] as String,
              ],
            ),
            _DetailBlock(
              icon: Icons.schedule_outlined,
              title: 'Получение',
              lines: [
                order['pickup_at'] == null
                    ? 'Как только будет готов'
                    : _formatDate(
                        DateTime.parse(order['pickup_at'] as String).toLocal(),
                      ),
                'Наличными при получении',
              ],
            ),
            if ((order['customer_notes'] as String? ?? '').trim().isNotEmpty)
              _DetailBlock(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Комментарий клиента',
                lines: [order['customer_notes'] as String],
              ),
            const SizedBox(height: 16),
            Text(
              'Состав заказа',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map(_OrderItemCard.new),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Итого',
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
                onPressed: () => _updateStatus(nextStatus),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_nextLabel(nextStatus)),
              ),
            if (!_isFinished(status)) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _cancelOrder,
                child: const Text('Отменить заказ'),
              ),
            ],
          ],
        );
      },
    ),
  );

  String? _nextStatus(String status) => switch (status) {
    'pending' => 'accepted',
    'accepted' => 'preparing',
    'preparing' => 'ready_for_pickup',
    'ready_for_pickup' => 'completed',
    _ => null,
  };

  String _nextLabel(String status) => switch (status) {
    'accepted' => 'Принять заказ',
    'preparing' => 'Начать готовить',
    'ready_for_pickup' => 'Отметить готовым',
    'completed' => 'Отметить выданным',
    _ => 'Обновить заказ',
  };

  bool _isFinished(String status) =>
      ['completed', 'cancelled', 'rejected'].contains(status);

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
  const _OrderItemCard(this.item);

  @override
  Widget build(BuildContext context) {
    final modifiers = List<Map<String, dynamic>>.from(
      item['modifier_snapshot'] as List<dynamic>? ?? const [],
    );
    final notes = item['special_instructions'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${item['quantity']} × ${item['item_name']}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['variant_name'] as String),
            if (modifiers.isNotEmpty)
              Text(
                modifiers.map((option) => option['name']).join(', '),
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
