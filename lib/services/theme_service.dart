import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class ThemeService extends ChangeNotifier {
  static const String _theme_key = 'app_theme';
  ThemeMeta _currentThemeMeta = themes.first;
  bool _isInitialized = false;

  ThemeService() {
    _isInitialized = true;
    notifyListeners();
  }

  ThemeData get currentTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _currentThemeMeta.background,
      cardColor: _currentThemeMeta.cardBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _currentThemeMeta.accent,
        background: _currentThemeMeta.background,
        primary: _currentThemeMeta.accent,
        onPrimary: Colors.white,
        surface: _currentThemeMeta.cardBackground,
        onSurface: _currentThemeMeta.primaryText,
        brightness: Brightness.light,
      ),
      textTheme: Typography.material2021().black.apply(
        bodyColor: _currentThemeMeta.primaryText,
        displayColor: _currentThemeMeta.primaryText,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _currentThemeMeta.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  ThemeMeta get currentThemeMeta => _currentThemeMeta;
  bool get isInitialized => _isInitialized;

  Future<void> setThemeByKey(String key) async {
    final found = themes.firstWhere((t) => t.key == key, orElse: () => themes.first);
    if (_currentThemeMeta.key == found.key) return;
    _currentThemeMeta = found;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_theme_key, key);
  }

  Future<void> setTheme(ThemeMeta theme) async {
    await setThemeByKey(theme.key);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_theme_key);
    if (key != null) {
      await setThemeByKey(key);
    }
  }
} 