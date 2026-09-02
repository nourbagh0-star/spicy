import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/app_network_image.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/core/widgets/quantity_selector.dart';
import 'package:spicy/core/widgets/responsive_content.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:spicy/features/branch/presentation/cubit/branch_state.dart';
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
  MenuItem? _item;
  MenuItemVariant? _selectedVariant;
  bool _isLoading = true;
  String? _loadError;
  int quantity = 1;
  final Set<String> _selectedModifierIds = {};

  @override
  void initState() {
    super.initState();
    final menuState = context.read<MenuCubit>().state;
    if (menuState is MenuLoaded) {
      final item = _findItem(menuState.items);
      if (item != null && item.variants.isNotEmpty) {
        _item = item;
        _selectedVariant = item.variants.first;
        _isLoading = false;
        return;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (_loadError != null || _item == null || _selectedVariant == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.restaurant_menu_outlined,
                  size: 52,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  locale.somethingWentWrong,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondary),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: locale.returnToMenu,
                  onPressed: () => context.go('/'),
                  width: 240,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final item = _item!;
    final selectedVariant = _selectedVariant!;
    return Scaffold(
      body: ResponsiveContent(
        maxWidth: 960,
        child: CustomScrollView(
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
                    icon: Icon(Icons.arrow_back, color: AppTheme.onBackground),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: 'menu-item-image-${item.id}',
                  child: AppNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 1600,
                    cacheHeight: 1000,
                    semanticLabel: item.name,
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
                        if (item.reviewCount > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xFFF9A825),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.rating.toStringAsFixed(1)} (${item.reviewCount})',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onBackground,
                            ),
                          ),
                        ] else
                          Text(
                            locale.noRatingsYet,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.secondary,
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
                                    setState(() => _selectedVariant = variant),
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
      ),

      // Bottom add-to-cart bar
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: Color(0x1A6B6661), width: 1)),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final total = _ProductTotal(
                        label: locale.total,
                        price: _unitPrice * quantity,
                      );
                      final quantityControl = QuantitySelector(
                        quantity: quantity,
                        onChanged: (val) => setState(() => quantity = val),
                      );
                      final addButton = _buildAddButton(
                        locale: locale,
                        item: item,
                        variant: selectedVariant,
                      );

                      if (compact) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(child: total),
                                quantityControl,
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: addButton),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 3, child: total),
                          quantityControl,
                          const SizedBox(width: 12),
                          Expanded(flex: 4, child: addButton),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
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

  Widget _buildAddButton({
    required AppLocale locale,
    required MenuItem item,
    required MenuItemVariant variant,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          context.read<CartCubit>().addToCart(
            item,
            variant,
            quantity: quantity,
            modifiers: _selectedModifiers,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale.addedToCart(item.name)),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
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
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          ),
        ),
      ),
    );
  }

  List<MenuItemModifierOption> get _selectedModifiers => _item!.modifierGroups
      .expand((group) => group.options)
      .where((option) => _selectedModifierIds.contains(option.id))
      .toList(growable: false);

  double get _unitPrice =>
      _selectedVariant!.priceRubles +
      _selectedModifiers.fold<double>(
        0,
        (sum, modifier) => sum + modifier.priceRubles,
      );

  MenuItem? _findItem(List<MenuItem> items) {
    for (final item in items) {
      if (item.id == widget.productId) return item;
    }
    return null;
  }

  Future<void> _loadProduct() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final locale = context.read<AppLocale>();
      final branchState = context.read<BranchCubit>().state;
      if (branchState is! BranchLoaded || branchState.selectedBranch == null) {
        throw StateError(locale.chooseBranchFirst);
      }
      final items = await context.read<MenuCubit>().loadMenu(
        branchState.selectedBranch!.id,
      );
      final item = _findItem(items);
      if (item == null || item.variants.isEmpty) {
        throw StateError(locale.branchUnavailable);
      }
      if (!mounted) return;
      setState(() {
        _item = item;
        _selectedVariant = item.variants.first;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString().replaceFirst('Bad state: ', '');
        _isLoading = false;
      });
    }
  }
}

class _ProductTotal extends StatelessWidget {
  final String label;
  final double price;

  const _ProductTotal({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.secondary),
        ),
        const SizedBox(height: 2),
        PriceLabel(
          price: price,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.onBackground,
          ),
        ),
      ],
    );
  }
}

bool _isSimpleSingleOption(MenuItemModifierGroup group) =>
    group.options.length == 1 &&
    group.name.trim().toLowerCase() ==
        group.options.single.name.trim().toLowerCase();
