import 'package:equatable/equatable.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';

class MenuItem extends Equatable {
  final String id;
  final String name;
  final String description;
  final String displayPrice;
  final List<double> prices;
  final int heatLevel;
  final String image;
  final String category;
  final String? sandwichType;
  // Fallbacks for UI compatibility
  final double rating;
  final int reviewCount;
  final bool isPopular;
  final List<String> ingredients;
  final int preparationTimeMinutes;
  final List<MenuItemVariant> variants;
  final List<MenuItemModifierGroup> modifierGroups;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.displayPrice,
    required this.prices,
    required this.heatLevel,
    required this.image,
    required this.category,
    this.sandwichType,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isPopular = false,
    this.ingredients = const [],
    this.preparationTimeMinutes = 20,
    this.variants = const [],
    this.modifierGroups = const [],
  });

  bool get isSpicy => heatLevel > 0;
  bool get isVegetarian => false; // Derived if needed
  double get price => variants.isNotEmpty
      ? variants.first.priceRubles
      : prices.isNotEmpty
      ? prices.first
      : 0.0;
  String get imageUrl => image;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    displayPrice,
    prices,
    heatLevel,
    image,
    category,
    sandwichType,
    rating,
    reviewCount,
    isPopular,
    ingredients,
    preparationTimeMinutes,
    variants,
    modifierGroups,
  ];
}
