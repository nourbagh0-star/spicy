import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/app_network_image.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/widgets/app_button.dart';
import 'package:spicy/core/widgets/quantity_selector.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/core/widgets/responsive_content.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:spicy/features/cart/presentation/cubit/cart_state.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale.cart,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state is CartUpdated && state.items.isNotEmpty) {
            return ResponsiveContent(
              maxWidth: 1180,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final items = _CartItemsList(items: state.items);
                  final summary = _CartSummary(
                    totalPrice: state.totalPrice,
                    locale: locale,
                    card: wide,
                  );

                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: items),
                          const SizedBox(width: 24),
                          SizedBox(width: 360, child: summary),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(child: items),
                      summary,
                    ],
                  );
                },
              ),
            );
          }

          // Empty cart state
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 80,
                  color: AppTheme.outline.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 24),
                Text(
                  locale.emptyCart,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  locale.emptyCartSub,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: locale.browseMenu,
                  variant: AppButtonVariant.outlined,
                  width: 200,
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CartItemsList extends StatelessWidget {
  final List<CartItem> items;

  const _CartItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _CartItemWidget(item: items[index]),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double totalPrice;
  final AppLocale locale;
  final bool card;

  const _CartSummary({
    required this.totalPrice,
    required this.locale,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: card ? 24 : MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: const Color(0x1A6B6661)),
        borderRadius: card ? BorderRadius.circular(AppTheme.radiusLg) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SummaryRow(
            label: locale.subtotal,
            value: PriceLabel(price: totalPrice, color: AppTheme.onBackground),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: locale.delivery,
            value: Flexible(
              child: Text(
                locale.deliveryCalculatedAtCheckout,
                textAlign: TextAlign.end,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondary,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0x1A6B6661)),
          ),
          _SummaryRow(
            label: locale.total,
            labelStyle: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.onBackground,
            ),
            value: PriceLabel(
              price: totalPrice,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: locale.proceedToCheckout,
            icon: Icons.payment_rounded,
            onPressed: () => context.push('/checkout'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final TextStyle? labelStyle;
  final Widget value;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style:
              labelStyle ??
              GoogleFonts.inter(fontSize: 14, color: AppTheme.secondary),
        ),
        const SizedBox(width: 16),
        const Spacer(),
        value,
      ],
    );
  }
}

class _CartItemWidget extends StatelessWidget {
  final CartItem item;

  const _CartItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0x1A6B6661)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: AppNetworkImage(
              imageUrl: item.menuItem.imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              cacheWidth: 240,
              cacheHeight: 240,
              semanticLabel: item.menuItem.name,
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onBackground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.variant.name,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.secondary,
                  ),
                ),
                if (item.modifiers.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.modifiers.map((modifier) => modifier.name).join(', '),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                PriceLabel(
                  price: item.unitPrice,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    QuantitySelector(
                      quantity: item.quantity,
                      onChanged: (val) {
                        context.read<CartCubit>().updateQuantity(
                          item.lineId,
                          val,
                        );
                      },
                      min: 0,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      onPressed: () {
                        context.read<CartCubit>().removeFromCart(item.lineId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
