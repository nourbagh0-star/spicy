import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/order_tracking/data/datasources/supabase_order_data_source.dart';
import 'package:spicy/features/order_tracking/domain/entities/order.dart';
import 'package:spicy/features/order_tracking/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final SupabaseOrderDataSource _dataSource;

  OrderRepositoryImpl({required SupabaseClient? client})
    : _dataSource = SupabaseOrderDataSource(client: client);

  @override
  Future<List<Order>> getOrders() async {
    return _dataSource.getOrders();
  }

  @override
  Future<Order> getOrderById(String id) async {
    return _dataSource.getOrderById(id);
  }

  @override
  Future<Order> placePickupCashOrder({
    required String branchId,
    required List<CartItem> items,
    required String contactName,
    required String contactPhone,
    required DateTime? pickupAt,
    required String notes,
  }) {
    return _dataSource.placePickupCashOrder(
      branchId: branchId,
      items: items,
      contactName: contactName,
      contactPhone: contactPhone,
      pickupAt: pickupAt,
      notes: notes,
    );
  }

  @override
  Future<List<Order>> getActiveOrders() async {
    final orders = await _dataSource.getOrders();
    return orders.where((order) => order.isActive).toList(growable: false);
  }
}
