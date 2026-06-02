import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/core/ui/background_pattern.dart';

final wallpaperProvider =
    StateNotifierProvider<WallpaperNotifier, WallpaperType>((ref) {
      return WallpaperNotifier(ref);
    });

class WallpaperNotifier extends StateNotifier<WallpaperType> {
  final Ref _ref;
  static const String _key = 'selected_wallpaper';

  WallpaperNotifier(this._ref) : super(WallpaperType.none) {
    _ref.listen<PremiumFeaturePolicy>(premiumFeaturePolicyProvider, (
      previous,
      next,
    ) async {
      if (!next.canUsePremiumThemes && state != WallpaperType.none) {
        state = WallpaperType.none;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_key, WallpaperType.none.index);
      }
    });
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;

    // Check if user still has access
    final policy = _ref.read(premiumFeaturePolicyProvider);
    if (!policy.canUsePremiumThemes && index != 0) {
      state = WallpaperType.none;
      return;
    }

    if (index < WallpaperType.values.length) {
      state = WallpaperType.values[index];
    }
  }

  Future<void> setWallpaper(WallpaperType type) async {
    final policy = _ref.read(premiumFeaturePolicyProvider);
    if (!policy.canUsePremiumThemes && type != WallpaperType.none) {
      return;
    }

    state = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, type.index);
  }
}
