import 'package:equatable/equatable.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';

abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {}

class CartUpdated extends CartState {
  final List<CartItem> items;
  final double totalPrice;
  final int itemCount;

  const CartUpdated({
    required this.items,
    required this.totalPrice,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [items, totalPrice, itemCount];
}
