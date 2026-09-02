import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const List<String> arabicFallback = ['NotoSansArabic'];
  // The warm SPICY palette changes together when the application theme changes.
  static Brightness _brightness = Brightness.light;

  static const Color _lightSurface = Color(0xFFFFF8F3);
  static const Color _lightSurfaceDim = Color(0xFFE0D9D2);
  static const Color _lightBackground = Color(0xFFFFF8F3);
  static const Color _lightOnBackground = Color(0xFF1E1B17);
  static const Color _lightSecondary = Color(0xFF5F5E5E);
  static const Color _lightOutline = Color(0xFF8D716B);

  static const Color _darkSurface = Color(0xFF211A17);
  static const Color _darkSurfaceDim = Color(0xFF342A26);
  static const Color _darkBackground = Color(0xFF171210);
  static const Color _darkOnBackground = Color(0xFFF5EDEA);
  static const Color _darkSecondary = Color(0xFFD8C2BB);
  static const Color _darkOutline = Color(0xFFBEA29A);

  static Color get surface =>
      _brightness == Brightness.dark ? _darkSurface : _lightSurface;
  static Color get surfaceDim =>
      _brightness == Brightness.dark ? _darkSurfaceDim : _lightSurfaceDim;
  static Color get background =>
      _brightness == Brightness.dark ? _darkBackground : _lightBackground;
  static Color get onBackground =>
      _brightness == Brightness.dark ? _darkOnBackground : _lightOnBackground;
  static Color get secondary =>
      _brightness == Brightness.dark ? _darkSecondary : _lightSecondary;
  static Color get outline =>
      _brightness == Brightness.dark ? _darkOutline : _lightOutline;

  static void setBrightness(Brightness brightness) => _brightness = brightness;

  static const Color primary = Color(0xFFAA301A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFCB4830);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFF5C5C58);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

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

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color surfaceColor,
    required Color backgroundColor,
    required Color onBackgroundColor,
    required Color secondaryColor,
    required Color outlineColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondaryColor,
        onSecondary: onSecondary,
        tertiary: tertiary,
        onTertiary: onTertiary,
        error: error,
        onError: onError,
        surface: surfaceColor,
        onSurface: onBackgroundColor,
        outline: outlineColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02 * 48,
          height: 56 / 48,
          color: onBackgroundColor,
        ).copyWith(fontFamilyFallback: arabicFallback),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 40 / 32,
          color: onBackgroundColor,
        ).copyWith(fontFamilyFallback: arabicFallback),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 32 / 24,
          color: onBackgroundColor,
        ).copyWith(fontFamilyFallback: arabicFallback),
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 28 / 18,
          color: secondaryColor,
        ).copyWith(fontFamilyFallback: arabicFallback),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: secondaryColor,
        ).copyWith(fontFamilyFallback: arabicFallback),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.01 * 14,
          height: 20 / 14,
          color: secondaryColor,
        ).copyWith(fontFamilyFallback: arabicFallback),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05 * 12,
          height: 16 / 12,
          color: secondaryColor,
        ).copyWith(fontFamilyFallback: arabicFallback),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onBackgroundColor,
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

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    surfaceColor: _lightSurface,
    backgroundColor: _lightBackground,
    onBackgroundColor: _lightOnBackground,
    secondaryColor: _lightSecondary,
    outlineColor: _lightOutline,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    surfaceColor: _darkSurface,
    backgroundColor: _darkBackground,
    onBackgroundColor: _darkOnBackground,
    secondaryColor: _darkSecondary,
    outlineColor: _darkOutline,
  );
}
