import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';
import 'package:spicy/features/order_tracking/domain/entities/order.dart';

class SupabaseOrderDataSource {
  final SupabaseClient? client;
  final AppLocale locale;

  SupabaseOrderDataSource({required this.client, required this.locale});

  Future<Order> placePickupCashOrder({
    required String branchId,
    required List<CartItem> items,
    required String contactName,
    required String contactPhone,
    required DateTime? pickupAt,
    required String notes,
  }) async {
    final orderId = await _requireClient().rpc(
      'place_cash_order',
      params: {
        'p_fulfillment': 'pickup',
        'p_branch_id': branchId,
        'p_items': items
            .map(
              (item) => {
                'menu_item_id': item.menuItem.id,
                'menu_item_variant_id': item.variant.id,
                'quantity': item.quantity,
                'special_instructions': item.specialInstructions,
                'modifier_option_ids': item.modifiers
                    .map((modifier) => modifier.id)
                    .toList(growable: false),
              },
            )
            .toList(growable: false),
        'p_contact_name': contactName.trim(),
        'p_contact_phone': contactPhone.trim(),
        'p_pickup_at': pickupAt?.toUtc().toIso8601String(),
        'p_customer_notes': notes.trim(),
      },
    );

    return getOrderById(orderId as String);
  }

  Future<List<Order>> getOrders() async {
    final rows = await _baseQuery().order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _toOrder(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Order> getOrderById(String id) async {
    final row = await _baseQuery().eq('id', id).single();
    return _toOrder(row);
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _baseQuery() {
    return _requireClient()
        .from('orders')
        .select(
          'id, daily_order_number, fulfillment, status, total_kopeks, created_at, '
          'pickup_at, delivery_address, branch_id, '
          'branches(name, address), '
          'order_items(menu_item_id, menu_item_variant_id, item_name, '
          'item_description, image_url, quantity, unit_price_kopeks, variant_name, '
          'modifier_snapshot, localization_snapshot, special_instructions)',
        );
  }

  Order _toOrder(Map<String, dynamic> data) {
    final branch = data['branches'] as Map<String, dynamic>?;
    final itemRows = data['order_items'] as List<dynamic>? ?? const [];
    return Order(
      id: data['id'] as String,
      orderNumber: data['daily_order_number'] as int?,
      items: itemRows
          .map((row) => _toCartItem(row as Map<String, dynamic>))
          .toList(growable: false),
      totalPrice: (data['total_kopeks'] as int) / 100,
      status: _statusFromDatabase(data['status'] as String),
      createdAt: DateTime.parse(data['created_at'] as String),
      estimatedDelivery: data['pickup_at'] == null
          ? null
          : DateTime.parse(data['pickup_at'] as String),
      deliveryAddress:
          data['delivery_address'] as String? ??
          branch?['address'] as String? ??
          '',
      branchName: branch?['name'] as String? ?? '',
      branchId: data['branch_id'] as String? ?? '',
      fulfillment: data['fulfillment'] as String? ?? 'pickup',
    );
  }

  CartItem _toCartItem(Map<String, dynamic> data) {
    final priceKopeks = data['unit_price_kopeks'] as int;
    final translation = _translationFor(data['localization_snapshot']);
    final menuItemId = data['menu_item_id'] as String? ?? 'removed-menu-item';
    final variantId =
        data['menu_item_variant_id'] as String? ?? 'removed-variant';
    final variant = MenuItemVariant(
      id: variantId,
      name:
          translation['variant_name'] as String? ??
          data['variant_name'] as String,
      code: 'snapshot',
      priceKopeks: priceKopeks,
    );
    return CartItem(
      menuItem: MenuItem(
        id: menuItemId,
        name:
            translation['item_name'] as String? ?? data['item_name'] as String,
        description:
            translation['item_description'] as String? ??
            data['item_description'] as String? ??
            '',
        displayPrice: '',
        prices: [variant.priceRubles],
        variants: [variant],
        heatLevel: 0,
        image: data['image_url'] as String? ?? '',
        category: '',
      ),
      variant: variant,
      quantity: data['quantity'] as int,
      specialInstructions: data['special_instructions'] as String?,
      modifiers: _snapshotModifiers(
        translation['modifiers'] ?? data['modifier_snapshot'],
      ),
    );
  }

  Map<String, dynamic> _translationFor(dynamic rawSnapshot) {
    if (rawSnapshot is! Map) return const {};
    final snapshots = Map<String, dynamic>.from(rawSnapshot);
    final selected = snapshots[locale.languageCode] ?? snapshots['ru'];
    if (selected is! Map) return const {};
    return Map<String, dynamic>.from(selected);
  }

  List<MenuItemModifierOption> _snapshotModifiers(dynamic rawSnapshot) {
    if (rawSnapshot is! List) return const [];
    return rawSnapshot
        .whereType<Map<String, dynamic>>()
        .map((row) {
          return MenuItemModifierOption(
            id: row['id'] as String? ?? '',
            name: row['name'] as String? ?? '',
            priceKopeks: row['price_kopeks'] as int? ?? 0,
          );
        })
        .where((option) => option.id.isNotEmpty)
        .toList(growable: false);
  }

  OrderStatus _statusFromDatabase(String status) {
    return switch (status) {
      'pending' => OrderStatus.placed,
      'accepted' => OrderStatus.confirmed,
      'preparing' => OrderStatus.preparing,
      'ready_for_pickup' => OrderStatus.readyForPickup,
      'out_for_delivery' => OrderStatus.onTheWay,
      'completed' => OrderStatus.delivered,
      'cancelled' || 'rejected' => OrderStatus.cancelled,
      _ => OrderStatus.placed,
    };
  }

  SupabaseClient _requireClient() {
    final configuredClient = client;
    if (configuredClient == null) {
      throw StateError(
        'This build is not connected to Supabase. Check the app configuration.',
      );
    }
    return configuredClient;
  }
}
