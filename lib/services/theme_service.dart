import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

enum AppThemeMode {
  day,
  night,
  blush,
  blushNight,
  jungle,
  sky,
}

class ThemeService extends ChangeNotifier {
  static const String _theme_key = 'app_theme';
  late AppThemeMode _currentThemeMode;
  bool _isInitialized = false;

  ThemeService() {
    print('DEBUG: ThemeService constructor called');
    _currentThemeMode = AppThemeMode.day;
    _isInitialized = true;
    print('DEBUG: ThemeService initialized synchronously');
    notifyListeners();
  }

  ThemeData get currentTheme {
    switch (_currentThemeMode) {
      case AppThemeMode.day:
        return AppTheme.dayTheme;
      case AppThemeMode.night:
        return AppTheme.nightTheme;
      case AppThemeMode.blush:
        return AppTheme.blushTheme;
      case AppThemeMode.blushNight:
        return AppTheme.blushNightTheme;
      case AppThemeMode.jungle:
        return AppTheme.jungleTheme;
      case AppThemeMode.sky:
        return AppTheme.skyTheme;
    }
  }
  
  AppThemeMode get currentThemeMode => _currentThemeMode;
  bool get isInitialized => _isInitialized;

  Future<void> setTheme(AppThemeMode themeMode) async {
    if (_currentThemeMode == themeMode) return;

    _currentThemeMode = themeMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_theme_key, themeMode.name);
  }

  ThemeData getThemeByKey(String? key) {
    switch (key) {
      case 'green_forest':
        return AppTheme.jungleTheme;
      case 'yellow_sunset':
        return AppTheme.blushTheme;
      case 'blue_mountains':
        return AppTheme.nightTheme;
      case 'pink_dawn':
        return AppTheme.skyTheme;
      default:
        return currentTheme;
    }
  }
} 