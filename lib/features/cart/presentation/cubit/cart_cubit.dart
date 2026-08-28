import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/cart/domain/repositories/cart_repository.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_state.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';

class CartCubit extends Cubit<CartState> {
  final CartRepository _repository;

  CartCubit({required this._repository}) : super(CartInitial());

  void loadCart() {
    _emitUpdated();
  }

  void addToCart(
    MenuItem menuItem,
    MenuItemVariant variant, {
    int quantity = 1,
    List<MenuItemModifierOption> modifiers = const [],
    String? specialInstructions,
  }) {
    _repository.addToCart(
      menuItem,
      variant,
      quantity: quantity,
      modifiers: modifiers,
      specialInstructions: specialInstructions,
    );
    _emitUpdated();
  }

  void removeFromCart(String lineId) {
    _repository.removeFromCart(lineId);
    _emitUpdated();
  }

  void updateQuantity(String lineId, int quantity) {
    _repository.updateQuantity(lineId, quantity);
    _emitUpdated();
  }

  void clearCart() {
    _repository.clearCart();
    _emitUpdated();
  }

  void _emitUpdated() {
    emit(
      CartUpdated(
        items: _repository.getCartItems(),
        totalPrice: _repository.getCartTotal(),
        itemCount: _repository.getCartItemCount(),
      ),
    );
  }
}
