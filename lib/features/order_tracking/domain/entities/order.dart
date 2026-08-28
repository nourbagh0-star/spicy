import 'package:equatable/equatable.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';

enum OrderStatus {
  placed,
  confirmed,
  preparing,
  readyForPickup,
  onTheWay,
  delivered,
  cancelled,
}

class Order extends Equatable {
  final String id;
  final int? orderNumber;
  final List<CartItem> items;
  final double totalPrice;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? estimatedDelivery;
  final String deliveryAddress;
  final double? driverLatitude;
  final double? driverLongitude;
  final double restaurantLatitude;
  final double restaurantLongitude;
  final String branchName;
  final String branchId;
  final String fulfillment;

  const Order({
    required this.id,
    this.orderNumber,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.estimatedDelivery,
    this.deliveryAddress = '',
    this.driverLatitude,
    this.driverLongitude,
    this.restaurantLatitude = 24.7136,
    this.restaurantLongitude = 46.6753,
    this.branchName = '',
    this.branchId = '',
    this.fulfillment = 'pickup',
  });

  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;

  String get statusLabel {
    switch (status) {
      case OrderStatus.placed:
        return 'Новый';
      case OrderStatus.confirmed:
        return 'Принят';
      case OrderStatus.preparing:
        return 'Готовится';
      case OrderStatus.readyForPickup:
        return 'Готов';
      case OrderStatus.onTheWay:
        return 'В пути';
      case OrderStatus.delivered:
        return 'Завершён';
      case OrderStatus.cancelled:
        return 'Отменён';
    }
  }

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    items,
    totalPrice,
    status,
    createdAt,
    estimatedDelivery,
    deliveryAddress,
    driverLatitude,
    driverLongitude,
    branchName,
    branchId,
    fulfillment,
  ];
}
