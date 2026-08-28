import 'package:equatable/equatable.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';

class CartItem extends Equatable {
  final MenuItem menuItem;
  final MenuItemVariant variant;
  final int quantity;
  final String? specialInstructions;
  final List<MenuItemModifierOption> modifiers;

  const CartItem({
    required this.menuItem,
    required this.variant,
    this.quantity = 1,
    this.specialInstructions,
    this.modifiers = const [],
  });

  String get lineId =>
      '${menuItem.id}:${variant.id}:${modifiers.map((item) => item.id).join(',')}';
  double get unitPrice =>
      variant.priceRubles +
      modifiers.fold<double>(0, (sum, modifier) => sum + modifier.priceRubles);
  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({
    MenuItem? menuItem,
    MenuItemVariant? variant,
    int? quantity,
    String? specialInstructions,
    List<MenuItemModifierOption>? modifiers,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      modifiers: modifiers ?? this.modifiers,
    );
  }

  @override
  List<Object?> get props => [
    menuItem,
    variant,
    quantity,
    specialInstructions,
    modifiers,
  ];
}
