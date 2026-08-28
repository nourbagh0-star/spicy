import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spicy/core/theme/app_theme.dart';

class PriceLabel extends StatelessWidget {
  final double price;
  final TextStyle? style;
  final Color? color;

  const PriceLabel({super.key, required this.price, this.style, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} ₽',
      style:
          style ??
          GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color ?? AppTheme.primary,
          ),
    );
  }
}
