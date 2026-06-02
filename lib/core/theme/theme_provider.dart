// theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pebble_routines/data/repositories/theme_repository.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'colors.dart';

/// Clean theme state class - just color theme selection
class ThemeState {
  final ThemeId selectedColorTheme;
  final int?
  version; // Force rebuild counter, nullable for backward compatibility

  const ThemeState({required this.selectedColorTheme, this.version});

  ThemeState copyWith({ThemeId? selectedColorTheme, int? version}) {
    return ThemeState(
      selectedColorTheme: selectedColorTheme ?? this.selectedColorTheme,
      version: version ?? ((this.version ?? 0) + 1), // Handle null version
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeState &&
        other.selectedColorTheme == selectedColorTheme &&
        (other.version ?? 0) == (version ?? 0); // Handle null versions
  }

  @override
  int get hashCode => Object.hash(selectedColorTheme, version ?? 0);

  @override
  String toString() =>
      'ThemeState(selectedColorTheme: $selectedColorTheme, version: ${version ?? 0})';
}

/// Theme notifier with simplified state management
class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _colorThemeKey = 'color_theme';

  ThemeNotifier()
    : super(
        const ThemeState(selectedColorTheme: ThemeId.highNoon, version: 0),
      ) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final colorThemeIndex =
        prefs.getInt(_colorThemeKey) ?? ThemeId.highNoon.index;

    // Protect against out-of-bounds if previously selected a theme that no longer exists
    final validIndex = colorThemeIndex < ThemeId.values.length
        ? colorThemeIndex
        : ThemeId.highNoon.index;

    state = ThemeState(
      selectedColorTheme: ThemeId.values[validIndex],
      version: 0, // Initialize with version 0
    );
  }

  Future<void> setColorTheme(ThemeId colorTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorThemeKey, colorTheme.index);
    state = state.copyWith(selectedColorTheme: colorTheme);
  }

  /// Get current ThemeData based on selected color theme
  ThemeData get currentThemeData {
    return AppTheme.fromId(state.selectedColorTheme);
  }
}

/// Provider for theme state
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

/// Convenient providers for accessing theme data
final currentThemeDataProvider = Provider<ThemeData>((ref) {
  final themeState = ref.watch(themeProvider);
  final themeData = AppTheme.fromId(themeState.selectedColorTheme);
  return themeData;
});

final currentColorThemeProvider = Provider<ThemeId>((ref) {
  final themeState = ref.watch(themeProvider);
  return themeState.selectedColorTheme;
});

final availableThemesProvider = Provider<List<ThemeMetadata>>((ref) {
  final canUsePremiumThemes = ref
      .watch(premiumFeaturePolicyProvider)
      .canUsePremiumThemes;
  final repository = ref.watch(themeRepositoryProvider);
  return repository.getAvailableThemes(
    canUsePremiumThemes: canUsePremiumThemes,
  );
});

final mainPickerThemesProvider =
    Provider.family<List<ThemeMetadata>, ThemePickerCategory>((ref, category) {
      final repository = ref.watch(themeRepositoryProvider);
      return repository.getMainPickerThemes(category);
    });

final moreThemeOptionsProvider =
    Provider.family<List<ThemeMetadata>, ThemePickerCategory>((ref, category) {
      final repository = ref.watch(themeRepositoryProvider);
      return repository.getMoreOptionsThemes(category);
    });

/// Helper provider to check if current theme is dark
final isDarkThemeProvider = Provider<bool>((ref) {
  final themeData = ref.watch(currentThemeDataProvider);
  return themeData.brightness == Brightness.dark;
});
