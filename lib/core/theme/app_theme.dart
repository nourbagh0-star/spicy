import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color surface = Color(0xFFFFF8F3);
  static const Color surfaceDim = Color(0xFFE0D9D2);
  static const Color primary = Color(0xFFAA301A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFCB4830);
  static const Color secondary = Color(0xFF5F5E5E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFF5C5C58);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFF8F3);
  static const Color onBackground = Color(0xFF1E1B17);
  static const Color outline = Color(0xFF8D716B);

  // Spacing
  static const double spacingBase = 8.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 24.0;
  static const double spacingLg = 40.0;
  static const double spacingXl = 64.0;

  // BorderRadius
  static const double radiusSm = 4.0;
  static const double radiusDefault = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        tertiary: tertiary,
        onTertiary: onTertiary,
        error: error,
        onError: onError,
        surface: surface,
        onSurface: onBackground,
        outline: outline,
      ),
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02 * 48,
          height: 56 / 48,
          color: onBackground,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 40 / 32,
          color: onBackground,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 32 / 24,
          color: onBackground,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 28 / 18,
          color: secondary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: secondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.01 * 14,
          height: 20 / 14,
          color: secondary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05 * 12,
          height: 16 / 12,
          color: secondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onBackground,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
        ),
      ),
    );
  }
}
