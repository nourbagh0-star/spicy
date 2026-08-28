import 'package:equatable/equatable.dart';
import 'package:spicy/features/order_tracking/domain/entities/order.dart';

abstract class OrderTrackingState extends Equatable {
  const OrderTrackingState();

  @override
  List<Object?> get props => [];
}

class OrderTrackingInitial extends OrderTrackingState {}

class OrderTrackingLoading extends OrderTrackingState {}

class OrdersLoaded extends OrderTrackingState {
  final List<Order> orders;
  final List<Order> activeOrders;

  const OrdersLoaded({required this.orders, required this.activeOrders});

  @override
  List<Object?> get props => [orders, activeOrders];
}

class OrderDetailLoaded extends OrderTrackingState {
  final Order order;

  const OrderDetailLoaded(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderPlaced extends OrderTrackingState {
  final Order order;

  const OrderPlaced(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderTrackingError extends OrderTrackingState {
  final String message;

  const OrderTrackingError(this.message);

  @override
  List<Object?> get props => [message];
}
