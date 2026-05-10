import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';

class ThemeRepository {
  final Ref ref;

  ThemeRepository(this.ref);

  List<ThemeMetadata> getAvailableThemes(UserTier currentTier) {
    if (currentTier.hasPremiumThemes) {
      return ThemeMetadata.all;
    }

    return ThemeMetadata.all
        .where((theme) => !theme.isPremium)
        .toList(growable: false);
  }

  List<ThemeMetadata> getMainPickerThemes(ThemePickerCategory category) {
    return ThemeMetadata.byCategory(
      category,
    ).where((theme) => theme.isVisibleOnMainPicker).toList(growable: false);
  }

  List<ThemeMetadata> getMoreOptionsThemes(ThemePickerCategory category) {
    return ThemeMetadata.byCategory(
      category,
    ).where((theme) => theme.showInMoreOptionsOnly).toList(growable: false);
  }
}

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return ThemeRepository(ref);
});
