import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/cart/domain/repositories/cart_repository.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';

class CartRepositoryImpl implements CartRepository {
  final List<CartItem> _items = [];

  @override
  List<CartItem> getCartItems() => List.unmodifiable(_items);

  @override
  void addToCart(
    MenuItem menuItem,
    MenuItemVariant variant, {
    int quantity = 1,
    List<MenuItemModifierOption> modifiers = const [],
    String? specialInstructions,
  }) {
    final lineId =
        '${menuItem.id}:${variant.id}:${modifiers.map((item) => item.id).join(',')}';
    final existingIndex = _items.indexWhere((item) => item.lineId == lineId);
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _items.add(
        CartItem(
          menuItem: menuItem,
          variant: variant,
          quantity: quantity,
          modifiers: List.unmodifiable(modifiers),
          specialInstructions: specialInstructions,
        ),
      );
    }
  }

  @override
  void removeFromCart(String lineId) {
    _items.removeWhere((item) => item.lineId == lineId);
  }

  @override
  void updateQuantity(String lineId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(lineId);
      return;
    }
    final index = _items.indexWhere((item) => item.lineId == lineId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
  }

  @override
  void clearCart() => _items.clear();

  @override
  double getCartTotal() => _items.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  int getCartItemCount() => _items.fold(0, (sum, item) => sum + item.quantity);
}
