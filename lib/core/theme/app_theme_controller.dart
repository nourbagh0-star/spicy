import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spicy/core/theme/app_theme.dart';

/// Stores the person's display choice only on their current device.
class AppThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static const _preferenceKey = 'spicy_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  AppThemeController() {
    WidgetsBinding.instance.addObserver(this);
    _syncPalette();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    _themeMode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _syncPalette();
  }

  Future<void> select(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _syncPalette();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, mode.name);
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode != ThemeMode.system) return;
    _syncPalette();
    notifyListeners();
  }

  void _syncPalette() {
    final brightness = switch (_themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    AppTheme.setBrightness(brightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
