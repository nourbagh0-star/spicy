import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:spicy/core/locale/app_locale.dart';

class CheckoutBar extends StatelessWidget {
  final int itemCount;
  final double totalPrice;
  final VoidCallback onCheckout;

  const CheckoutBar({
    super.key,
    required this.itemCount,
    required this.totalPrice,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    final locale = context.watch<AppLocale>();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.9),
              border: const Border(
                top: BorderSide(color: Color(0x1A6B6661), width: 1),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D2C2C2C),
                  blurRadius: 30,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        locale.items(itemCount),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppTheme.secondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${totalPrice.toStringAsFixed(totalPrice == totalPrice.truncateToDouble() ? 0 : 2)} ₽',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onCheckout,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                      label: Text(
                        locale.viewCart,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusDefault,
                          ),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
