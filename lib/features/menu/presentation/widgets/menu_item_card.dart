import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/core/locale/app_locale.dart';
import 'package:spicy/core/theme/app_theme.dart';
import 'package:spicy/core/widgets/app_network_image.dart';
import 'package:spicy/core/widgets/price_label.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const MenuItemCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      side: BorderSide(color: AppTheme.outline.withValues(alpha: 0.2)),
    );
    return Semantics(
      button: true,
      label: '${item.name}, ${item.price.toStringAsFixed(0)} ₽',
      child: Material(
        color: AppTheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: AppTheme.primary.withValues(alpha: 0.04),
          focusColor: AppTheme.primary.withValues(alpha: 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image — bleeds to top and sides
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'menu-item-image-${item.id}',
                      child: AppNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                        cacheHeight: 675,
                        semanticLabel: item.name,
                      ),
                    ),
                    // Gradient overlay at bottom for text readability
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      child: Container(
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0x33000000), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // Tags
                    if (item.isSpicy || item.isVegetarian || item.isPopular)
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: Row(
                          children: [
                            if (item.isPopular)
                              _buildTag(locale.popular, AppTheme.primary),
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
                  ],
                ),
              ),
              // Content area — padded by md (24px)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
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
                      item.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.secondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PriceLabel(
                          price: item.price,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const Spacer(),
                        if (item.rating > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFF9A825),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onBackground,
                                ),
                              ),
                              if (item.reviewCount > 0)
                                Text(
                                  ' (${item.reviewCount})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
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
      margin: const EdgeInsetsDirectional.only(end: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
