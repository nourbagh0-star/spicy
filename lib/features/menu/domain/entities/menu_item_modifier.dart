import 'package:equatable/equatable.dart';

/// A customer-facing group such as "Remove ingredients" or "Add extras".
class MenuItemModifierGroup extends Equatable {
  final String id;
  final String name;
  final int minimumSelections;
  final int maximumSelections;
  final List<MenuItemModifierOption> options;

  const MenuItemModifierGroup({
    required this.id,
    required this.name,
    required this.minimumSelections,
    required this.maximumSelections,
    required this.options,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    minimumSelections,
    maximumSelections,
    options,
  ];
}

/// An owner-controlled option. Price is per one menu item, in kopeks.
class MenuItemModifierOption extends Equatable {
  final String id;
  final String name;
  final int priceKopeks;

  const MenuItemModifierOption({
    required this.id,
    required this.name,
    required this.priceKopeks,
  });

  double get priceRubles => priceKopeks / 100;

  @override
  List<Object?> get props => [id, name, priceKopeks];
}
