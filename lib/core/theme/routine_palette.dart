import 'package:flutter/material.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

/// One routine colour: a calm "stone" tone with a light-theme and a
/// dark-theme value. The light value is what gets stored in
/// `Routines.colorHex`, so it is the stone's identity on every device.
class RoutineStone {
  const RoutineStone({
    required this.key,
    required this.name,
    required this.light,
    required this.dark,
    this.isPremium = false,
  });

  final String key;
  final String name;
  final Color light;
  final Color dark;
  final bool isPremium;

  int get storedHex => light.toARGB32();

  Color forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// The routine colours offered in Style Studio. Earthy tones that sit with
/// Pebble's themes, in place of the old stock Material swatches. The first
/// four are free so everyone can make a routine their own.
class RoutinePalette {
  const RoutinePalette._();

  static const List<RoutineStone> stones = [
    RoutineStone(
      key: 'moss',
      name: 'Moss',
      light: Color(0xFF557A58),
      dark: Color(0xFF9DBF9A),
    ),
    RoutineStone(
      key: 'clay',
      name: 'Clay',
      light: Color(0xFFA85B42),
      dark: Color(0xFFE2A08A),
    ),
    RoutineStone(
      key: 'slate',
      name: 'Slate',
      light: Color(0xFF4F6578),
      dark: Color(0xFFA6B8CA),
    ),
    RoutineStone(
      key: 'sand',
      name: 'Sand',
      light: Color(0xFF8C6F45),
      dark: Color(0xFFD9BE8F),
    ),
    RoutineStone(
      key: 'heather',
      name: 'Heather',
      light: Color(0xFF7A5E8C),
      dark: Color(0xFFC6AFD6),
      isPremium: true,
    ),
    RoutineStone(
      key: 'tide',
      name: 'Tide',
      light: Color(0xFF3A757C),
      dark: Color(0xFF8FC7CC),
      isPremium: true,
    ),
    RoutineStone(
      key: 'rosehip',
      name: 'Rosehip',
      light: Color(0xFFA05468),
      dark: Color(0xFFE5A5B5),
      isPremium: true,
    ),
    RoutineStone(
      key: 'ochre',
      name: 'Ochre',
      light: Color(0xFF8E6E1F),
      dark: Color(0xFFE2C374),
      isPremium: true,
    ),
    RoutineStone(
      key: 'pine',
      name: 'Pine',
      light: Color(0xFF2F5D50),
      dark: Color(0xFF7FB3A2),
      isPremium: true,
    ),
    RoutineStone(
      key: 'flint',
      name: 'Flint',
      light: Color(0xFF555350),
      dark: Color(0xFFC2BEB7),
      isPremium: true,
    ),
  ];

  /// The stone stored as [colorHex], or null for no colour or a colour from
  /// before the stone palette.
  static RoutineStone? match(int? colorHex) {
    if (colorHex == null || colorHex == 0) return null;
    for (final stone in stones) {
      if (stone.storedHex == colorHex || stone.dark.toARGB32() == colorHex) {
        return stone;
      }
    }
    return null;
  }

  /// [colorHex] if a free user may keep it, otherwise null (theme colour).
  /// Colours from before the stone palette stay as they are.
  static int? sanitizeForStorage(
    int? colorHex, {
    required bool hasPremiumAccess,
  }) {
    final stone = match(colorHex);
    if (stone != null && stone.isPremium && !hasPremiumAccess) return null;
    return colorHex;
  }
}

/// Routine colours as they appear on screen.
extension RoutineAccentColors on BuildContext {
  /// The routine's colour for the current theme, firmed up where needed so
  /// it reads as text on the page and on low cards (the same bar as
  /// [ThemeHelpers.done]). Null when the routine has no colour, or in an
  /// accessibility theme, where the theme's own colours always win.
  Color? routineAccent(int? colorHex) {
    if (colorHex == null || colorHex == 0) return null;
    final theme = Theme.of(this);
    final themeId = theme.extension<PebbleThemeX>()?.themeId;
    if (themeId != null && ThemeMetadata.get(themeId).isAccessibilityTheme) {
      return null;
    }
    final stone = RoutinePalette.match(colorHex);
    final raw = stone?.forBrightness(theme.brightness) ?? Color(colorHex);
    final f = darkFoundation;
    return ensureContrast(
      raw.withValues(alpha: 1),
      backgrounds: [f.bgBase, f.surfaceLow],
      strongest: f.textPrimary,
    );
  }
}

/// Paints everything below it in the routine's colour: the check stroke,
/// the trail, the progress bar, the cairn and the "Checked" card all read
/// [ThemeHelpers.done], so swapping it here carries the routine's colour
/// through the player, the completion screen and Home without touching
/// each widget. Passes [child] through untouched when the routine has no
/// colour.
class RoutineAccentScope extends StatelessWidget {
  const RoutineAccentScope({
    super.key,
    required this.colorHex,
    required this.child,
  });

  final int? colorHex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = context.routineAccent(colorHex);
    final theme = Theme.of(context);
    final x = theme.extension<PebbleThemeX>();
    if (accent == null || x == null) return child;
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((e) => e is! PebbleThemeX),
          x.copyWith(
            done: accent,
            doneContainer: accent.withValues(alpha: 0.10),
            // One colour family, so the cairn stacks in the routine's tones.
            categoryAccents: [accent],
          ),
        ],
      ),
      child: child,
    );
  }
}
