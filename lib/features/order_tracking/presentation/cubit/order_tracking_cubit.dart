import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/order_tracking/domain/repositories/order_repository.dart';
import 'package:spicy/features/order_tracking/presentation/cubit/order_tracking_state.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';

class OrderTrackingCubit extends Cubit<OrderTrackingState> {
  final OrderRepository _repository;

  OrderTrackingCubit({required this._repository})
    : super(OrderTrackingInitial());

  Future<void> loadOrders() async {
    emit(OrderTrackingLoading());
    try {
      final orders = await _repository.getOrders();
      final activeOrders = await _repository.getActiveOrders();
      emit(OrdersLoaded(orders: orders, activeOrders: activeOrders));
    } catch (e) {
      emit(OrderTrackingError(e.toString()));
    }
  }

  Future<void> loadOrderDetail(String orderId) async {
    emit(OrderTrackingLoading());
    try {
      final order = await _repository.getOrderById(orderId);
      emit(OrderDetailLoaded(order));
    } catch (e) {
      emit(OrderTrackingError(e.toString()));
    }
  }

  Future<void> refreshOrderDetail(String orderId) async {
    try {
      final order = await _repository.getOrderById(orderId);
      emit(OrderDetailLoaded(order));
    } catch (e) {
      emit(OrderTrackingError(e.toString()));
    }
  }

  Future<void> placePickupCashOrder({
    required String branchId,
    required List<CartItem> items,
    required String contactName,
    required String contactPhone,
    required DateTime? pickupAt,
    required String notes,
  }) async {
    emit(OrderTrackingLoading());
    try {
      final placed = await _repository.placePickupCashOrder(
        branchId: branchId,
        items: items,
        contactName: contactName,
        contactPhone: contactPhone,
        pickupAt: pickupAt,
        notes: notes,
      );
      emit(OrderPlaced(placed));
    } catch (e) {
      emit(OrderTrackingError(e.toString()));
    }
  }
}
