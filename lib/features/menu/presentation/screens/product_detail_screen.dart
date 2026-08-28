import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/core/widgets/quantity_selector.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_modifier.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_cubit.dart';
import 'package:spicy/features/menu/presentation/cubit/menu_state.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final MenuItem item;
  late MenuItemVariant selectedVariant;
  int quantity = 1;
  final Set<String> _selectedModifierIds = {};

  @override
  void initState() {
    super.initState();
    final menuState = context.read<MenuCubit>().state;
    if (menuState is MenuLoaded) {
      item = menuState.items.firstWhere(
        (i) => i.id == widget.productId,
        orElse: () => throw Exception('Item not found: ${widget.productId}'),
      );
      selectedVariant = item.variants.first;
    } else {
      throw Exception('Menu not loaded');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.surface,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: AppTheme.surface.withValues(alpha: 0.8),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppTheme.onBackground,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppTheme.surfaceDim,
                  child: const Icon(
                    Icons.restaurant,
                    size: 64,
                    color: AppTheme.outline,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  Text(
                    locale.translateCategory(item.category).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Name
                  Text(
                    item.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rating & prep time row
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFF9A825),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.rating} (${item.reviewCount})',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: AppTheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.preparationTimeMinutes} ${locale.prepTime}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tags
                  if (item.isSpicy || item.isVegetarian)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (item.isSpicy)
                            _buildTag(locale.spicy, const Color(0xFFD84315)),
                          if (item.isVegetarian)
                            _buildTag(
                              locale.vegetarian,
                              const Color(0xFF2E7D32),
                            ),
                        ],
                      ),
                    ),

                  // Description
                  Text(
                    item.description,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.secondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (item.variants.length > 1) ...[
                    Text(
                      locale.sizeOrVariant,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.variants
                          .map((variant) {
                            final selected = variant.id == selectedVariant.id;
                            return ChoiceChip(
                              label: Text(
                                '${variant.name} · ${variant.priceRubles.toStringAsFixed(0)} ₽',
                              ),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => selectedVariant = variant),
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (item.modifierGroups.isNotEmpty) ...[
                    for (final group in item.modifierGroups) ...[
                      if (!_isSimpleSingleOption(group)) ...[
                        Text(
                          group.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.maximumSelections == 1
                              ? locale.selectUpToOne
                              : locale.selectUpTo(group.maximumSelections),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ...group.options.map(
                        (option) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(option.name),
                          subtitle: option.priceKopeks == 0
                              ? Text(locale.free)
                              : Text(
                                  '+${option.priceRubles.toStringAsFixed(0)} ₽',
                                ),
                          value: _selectedModifierIds.contains(option.id),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                final groupIds = group.options
                                    .map((item) => item.id)
                                    .where(_selectedModifierIds.contains)
                                    .length;
                                if (groupIds < group.maximumSelections) {
                                  _selectedModifierIds.add(option.id);
                                }
                              } else {
                                _selectedModifierIds.remove(option.id);
                              }
                            });
                          },
                          activeColor: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Ingredients
                  if (item.ingredients.isNotEmpty) ...[
                    Text(
                      locale.ingredients,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.ingredients.map((ingredient) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.outline.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusXl,
                            ),
                          ),
                          child: Text(
                            ingredient,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.secondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom add-to-cart bar
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: Color(0x1A6B6661), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.total,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    PriceLabel(
                      price: _unitPrice * quantity,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onBackground,
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity
              QuantitySelector(
                quantity: quantity,
                onChanged: (val) => setState(() => quantity = val),
              ),
              const SizedBox(width: 10),

              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<CartCubit>().addToCart(
                        item,
                        selectedVariant,
                        quantity: quantity,
                        modifiers: _selectedModifiers,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(locale.addedToCart(item.name)),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusDefault,
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: Text(locale.addToCart),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusDefault,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  List<MenuItemModifierOption> get _selectedModifiers => item.modifierGroups
      .expand((group) => group.options)
      .where((option) => _selectedModifierIds.contains(option.id))
      .toList(growable: false);

  double get _unitPrice =>
      selectedVariant.priceRubles +
      _selectedModifiers.fold<double>(
        0,
        (sum, modifier) => sum + modifier.priceRubles,
      );
}

bool _isSimpleSingleOption(MenuItemModifierGroup group) =>
    group.options.length == 1 &&
    group.name.trim().toLowerCase() ==
        group.options.single.name.trim().toLowerCase();
