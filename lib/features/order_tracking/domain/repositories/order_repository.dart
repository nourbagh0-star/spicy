import 'package:spicy/features/order_tracking/domain/entities/order.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/order_tracking/domain/entities/delivery_quote.dart';

abstract class OrderRepository {
  Future<List<Order>> getOrders();
  Future<Order> getOrderById(String id);
  Future<Order> placePickupCashOrder({
    required String branchId,
    required List<CartItem> items,
    required String contactName,
    required String contactPhone,
    required DateTime? pickupAt,
    required String notes,
  });
  Future<List<Order>> getActiveOrders();
  Future<DeliveryQuote?> getDeliveryQuote({
    required double latitude,
    required double longitude,
    required List<CartItem> items,
  });
  Future<Order> placeDeliveryCashOrder({
    required List<CartItem> items,
    required String contactName,
    required String contactPhone,
    required String deliveryAddress,
    required double latitude,
    required double longitude,
    required DateTime? deliveryScheduledAt,
    required String notes,
  });
}
