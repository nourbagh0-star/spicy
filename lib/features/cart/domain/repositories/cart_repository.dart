import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';

abstract class CartRepository {
  List<CartItem> getCartItems();
  void addToCart(
    MenuItem menuItem,
    MenuItemVariant variant, {
    int quantity = 1,
    List<MenuItemModifierOption> modifiers = const [],
    String? specialInstructions,
  });
  void removeFromCart(String lineId);
  void updateQuantity(String lineId, int quantity);
  void clearCart();
  double getCartTotal();
  int getCartItemCount();
}
