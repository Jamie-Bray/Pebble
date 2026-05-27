import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum ThemeId {
  highNoon,
  nordicNight,
  paperAndInk,
  matcha,
  roseQuartz,
  deepGlacier,
  amberResin,
  terracotta,
  lavenderAsh,
  oatmealAndWalnut,
  midnightSlate,
  canopy,
  parchment,
  dusk,
  still,
  highContrastDark,
  warmSepia,
  reducedContrast,
  colourBlindSafe,
  softPink,
  sageMist,
}

enum ThemePickerCategory { included, premium, accessibility }

/// ---------------------------------------------------------------------------
/// THEME FACTORIES (Core Logic)
/// ---------------------------------------------------------------------------

abstract class _BaseThemeFactory {
  static ThemeData build({
    required ThemeId id,
    required Color bg,
    required Color fg,
    required Color accent,
    bool isDark = false,
    Color? secondary,
    Color? error,
    LinearGradient? gradient,
    PebbleDarkFoundation? darkFoundation,
  }) {
    final foundation =
        darkFoundation ??
        PebbleDarkFoundation.fromPalette(
          bg: bg,
          fg: fg,
          accent: accent,
          isDark: isDark,
        );
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: isDark ? foundation.bgBase : Colors.white,
      secondary: secondary ?? accent.withValues(alpha: 0.8),
      onSecondary: isDark ? foundation.bgBase : Colors.white,
      tertiary: accent.withValues(alpha: 0.2),
      onTertiary: accent,
      error:
          error ?? (isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E)),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      surface: foundation.bgBase,
      onSurface: foundation.textPrimary,
      surfaceTint: Colors.transparent,
      outline: isDark ? foundation.borderSubtle : fg.withValues(alpha: 0.15),
      outlineVariant: isDark
          ? foundation.borderSubtle.withValues(alpha: 0.65)
          : fg.withValues(alpha: 0.05),
      shadow: const Color(0x14000000),
      scrim: const Color(0x33000000),
      inverseSurface: foundation.textPrimary,
      inversePrimary: foundation.bgBase,
      primaryContainer: isDark
          ? foundation.surfaceHigh
          : accent.withValues(alpha: 0.1),
      onPrimaryContainer: foundation.textPrimary,
      secondaryContainer: isDark ? foundation.surfaceLow : bg,
      onSecondaryContainer: foundation.textPrimary,
      tertiaryContainer: isDark ? foundation.surfaceLow : bg,
      onTertiaryContainer: foundation.textPrimary,
      surfaceContainerLowest: foundation.bgBase,
      surfaceContainerLow: isDark ? foundation.surfaceLow : bg,
      surfaceContainer: isDark
          ? foundation.surfaceLow
          : bg.withValues(alpha: 0.95),
      surfaceContainerHigh: isDark
          ? foundation.surfaceHigh
          : Color.lerp(bg, fg, 0.05) ?? bg,
      surfaceContainerHighest: isDark
          ? foundation.surfaceHigh
          : Color.lerp(bg, fg, 0.1) ?? bg,
    );

    final textTheme = GoogleFonts.dmSansTextTheme().apply(
      bodyColor: fg,
      displayColor: fg,
    );

    final templatesTokens = PebbleTemplatesTokens.fromFoundation(
      foundation: foundation,
      accent: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : fg.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: fg.withValues(alpha: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? bg : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? foundation.surfaceHigh.withValues(alpha: 0.74)
            : bg.withValues(alpha: 0.9),
        selectedItemColor: accent,
        unselectedItemColor: foundation.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: scheme.outline,
      iconTheme: IconThemeData(color: fg),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? foundation.surfaceLow : bg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      extensions: [
        PebbleThemeX(
          themeId: id,
          focusRing: accent.withValues(alpha: 0.2),
          gradient: gradient,
        ),
        foundation,
        templatesTokens,
      ],
    );
  }
}

/// 1. High Noon (Free Light)
class HighNoonThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.highNoon,
    bg: const Color(0xFFFDFCF5),
    fg: const Color(0xFF2D3A30),
    accent: const Color(0xFF4A5D4E),
  );
}

/// 2. Pebble Dark (Free Dark)
class NordicNightThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.nordicNight,
    bg: const Color(0xFF1B1813),
    fg: const Color(0xFFF0E9D6),
    accent: const Color(0xFFC4946A),
    isDark: true,
    secondary: const Color(0xFF7FA87E),
    error: const Color(0xFFC07B68),
    darkFoundation: const PebbleDarkFoundation(
      bgBase: Color(0xFF1B1813),
      surfaceLow: Color(0xFF232018),
      surfaceHigh: Color(0xFF2A2720),
      borderSubtle: Color(0xFF2E2922),
      textPrimary: Color(0xFFF0E9D6),
      textSecondary: Color(0xFF8A8070),
      textMuted: Color(0xFF4E4940),
      shadowSoft: Color(0x52000000),
    ),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1B1813), Color(0xFF211E17), Color(0xFF1B1813)],
    ),
  );
}

/// 3. Paper & Ink (Free HC Light)
class PaperAndInkThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.paperAndInk,
    bg: const Color(0xFFFFFFFF),
    fg: const Color(0xFF111111),
    accent: const Color(0xFF8B6B4A),
  );
}

/// 4. Matcha (Free Soft Light)
class MatchaThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.matcha,
    bg: const Color(0xFFF4F7F4),
    fg: const Color(0xFF3A4A3F),
    accent: const Color(0xFF6B8E73),
  );
}

/// 5. Soft Pink (Free Soft Light)
class SoftPinkThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.softPink,
    bg: const Color(0xFFFBF2F4),
    fg: const Color(0xFF4D363C),
    accent: const Color(0xFFA36F7B),
    secondary: const Color(0xFF7C8A70),
  );
}

/// 6. Sage Mist (Free Soft Light -> now Dark Forest)
class SageMistThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.sageMist,
    bg: const Color(0xFF162119), // dark forest
    fg: const Color(0xFFE2EBE5), // soft pale green
    accent: const Color(0xFF6B8A72), // sage accent
    secondary: const Color(0xFF8B9E8E),
    isDark: true,
  );
}

/// 7. Rose Quartz (Premium Spa)
class RoseQuartzThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.roseQuartz,
    bg: const Color(0xFFF9F0F2),
    fg: const Color(0xFF4A2B32),
    accent: const Color(0xFFB87A84),
  );
}

/// 6. Deep Glacier (Premium Cold Dark)
class DeepGlacierThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.deepGlacier,
    bg: const Color(0xFF0A1521),
    fg: const Color(0xFFE6EDF3),
    accent: const Color(0xFF4A80A6),
    isDark: true,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A1521), Color(0xFF14202D), Color(0xFF0A1521)],
    ),
  );
}

/// 7. Amber Resin (Premium Warm Dark)
class AmberResinThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.amberResin,
    bg: const Color(0xFF1A1412),
    fg: const Color(0xFFE8DCC8),
    accent: const Color(0xFFC27D38),
    isDark: true,
    darkFoundation: const PebbleDarkFoundation(
      bgBase: Color(0xFF17110F),
      surfaceLow: Color(0xFF271F19),
      surfaceHigh: Color(0xFF33271D),
      borderSubtle: Color(0x33E8D2B7),
      textPrimary: Color(0xFFF4E7D1),
      textSecondary: Color(0xC9E9D7BE),
      textMuted: Color(0x8CDCC5A9),
      shadowSoft: Color(0x33000000),
    ),
  );
}

/// 8. Terracotta (Premium Earthy Dark)
class TerracottaThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.terracotta,
    bg: const Color(0xFF2C211F),
    fg: const Color(0xFFE8DCD5),
    accent: const Color(0xFFC4714A),
    isDark: true,
    darkFoundation: const PebbleDarkFoundation(
      bgBase: Color(0xFF201714),
      surfaceLow: Color(0xFF30231E),
      surfaceHigh: Color(0xFF3B2A23),
      borderSubtle: Color(0x34E8CFC5),
      textPrimary: Color(0xFFF4E8E1),
      textSecondary: Color(0xCBE9D7CF),
      textMuted: Color(0x8FDCC4B9),
      shadowSoft: Color(0x33000000),
    ),
  );
}

/// 9. Lavender Ash (Premium Muted Dark)
class LavenderAshThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.lavenderAsh,
    bg: const Color(0xFF1E1A24),
    fg: const Color(0xFFDCD9E3),
    accent: const Color(0xFF8A7BBA),
    isDark: true,
  );
}

/// 10. Oatmeal & Walnut (Premium Ultra-Minimal Light)
class OatmealAndWalnutThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.oatmealAndWalnut,
    bg: const Color(0xFFF2EFE9),
    fg: const Color(0xFF40352C),
    accent: const Color(0xFF9A7D64),
  );
}

/// 11. Graphite (Premium Warm Near-Black)
class MidnightSlateThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.midnightSlate,
    bg: const Color(0xFF141210),
    fg: const Color(0xFFD4CFC8),
    accent: const Color(0xFFB8936A),
    isDark: true,
  );
}

/// 12. Canopy (Premium Deep Green Dark)
class CanopyThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.canopy,
    bg: const Color(0xFF121C17),
    fg: const Color(0xFFD1E0D7),
    accent: const Color(0xFF5A8A68),
    isDark: true,
  );
}

/// 13. Parchment (Premium Warm Light)
class ParchmentThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.parchment,
    bg: const Color(0xFFF5EFE0),
    fg: const Color(0xFF3A2E1E),
    accent: const Color(0xFFA07840),
  );
}

/// 14. Dusk (Premium Deep Navy)
class DuskThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.dusk,
    bg: const Color(0xFF141C28),
    fg: const Color(0xFFDDE4F0),
    accent: const Color(0xFFC4946A),
    isDark: true,
  );
}

/// 15. Still (Premium Neutral Dark)
class StillThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.still,
    bg: const Color(0xFF1A1A1A),
    fg: const Color(0xFFD8D4CE),
    accent: const Color(0xFFB89E84),
    isDark: true,
  );
}

/// 16. High Contrast Dark (Accessibility)
class HighContrastDarkThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.highContrastDark,
    bg: const Color(0xFF000000),
    fg: const Color(0xFFFFFFFF),
    accent: const Color(0xFFFFDD00),
    isDark: true,
    darkFoundation: const PebbleDarkFoundation(
      bgBase: Color(0xFF000000),
      surfaceLow: Color(0xFF1A1A1A),
      surfaceHigh: Color(0xFF242424),
      borderSubtle: Color(0xFF333333),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFD6D6D6),
      textMuted: Color(0xFF888888),
      shadowSoft: Color(0x66000000),
    ),
  );
}

/// 17. Warm Sepia (Accessibility)
class WarmSepiaThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.warmSepia,
    bg: const Color(0xFFF0E8D8),
    fg: const Color(0xFF2E2416),
    accent: const Color(0xFF8B6840),
  );
}

/// 18. Reduced Contrast (Accessibility)
class ReducedContrastThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.reducedContrast,
    bg: const Color(0xFF1E1C19),
    fg: const Color(0xFFA09888),
    accent: const Color(0xFF8A7A64),
    isDark: true,
  );
}

/// 19. Colour Blind Safe (Accessibility)
class ColourBlindSafeThemeFactory {
  static ThemeData build() => _BaseThemeFactory.build(
    id: ThemeId.colourBlindSafe,
    bg: const Color(0xFF1B1813),
    fg: const Color(0xFFF0E9D6),
    accent: const Color(0xFFE8844A),
    secondary: const Color(0xFF5B8FD4),
    error: const Color(0xFF9B7FD4),
    isDark: true,
    darkFoundation: const PebbleDarkFoundation(
      bgBase: Color(0xFF1B1813),
      surfaceLow: Color(0xFF232018),
      surfaceHigh: Color(0xFF2A2720),
      borderSubtle: Color(0xFF2E2922),
      textPrimary: Color(0xFFF0E9D6),
      textSecondary: Color(0xFF8A8070),
      textMuted: Color(0xFF4E4940),
      shadowSoft: Color(0x52000000),
    ),
  );
}

/// ------------ PUBLIC FACTORY ------------
class AppTheme {
  static ThemeData fromId(ThemeId id) {
    switch (id) {
      case ThemeId.highNoon:
        return HighNoonThemeFactory.build();
      case ThemeId.nordicNight:
        return NordicNightThemeFactory.build();
      case ThemeId.paperAndInk:
        return PaperAndInkThemeFactory.build();
      case ThemeId.matcha:
        return MatchaThemeFactory.build();
      case ThemeId.roseQuartz:
        return RoseQuartzThemeFactory.build();
      case ThemeId.deepGlacier:
        return DeepGlacierThemeFactory.build();
      case ThemeId.amberResin:
        return AmberResinThemeFactory.build();
      case ThemeId.terracotta:
        return TerracottaThemeFactory.build();
      case ThemeId.lavenderAsh:
        return LavenderAshThemeFactory.build();
      case ThemeId.oatmealAndWalnut:
        return OatmealAndWalnutThemeFactory.build();
      case ThemeId.midnightSlate:
        return MidnightSlateThemeFactory.build();
      case ThemeId.canopy:
        return CanopyThemeFactory.build();
      case ThemeId.parchment:
        return ParchmentThemeFactory.build();
      case ThemeId.dusk:
        return DuskThemeFactory.build();
      case ThemeId.still:
        return StillThemeFactory.build();
      case ThemeId.highContrastDark:
        return HighContrastDarkThemeFactory.build();
      case ThemeId.warmSepia:
        return WarmSepiaThemeFactory.build();
      case ThemeId.reducedContrast:
        return ReducedContrastThemeFactory.build();
      case ThemeId.colourBlindSafe:
        return ColourBlindSafeThemeFactory.build();
      case ThemeId.softPink:
        return SoftPinkThemeFactory.build();
      case ThemeId.sageMist:
        return SageMistThemeFactory.build();
    }
  }
}

/// ------------ THEME EXTENSION (Design System) ------------
class PebbleThemeX extends ThemeExtension<PebbleThemeX> {
  final LinearGradient? gradient;
  final ThemeId? themeId;
  final Color focusRing;

  const PebbleThemeX({
    required this.gradient,
    required this.themeId,
    required this.focusRing,
  });

  @override
  PebbleThemeX copyWith({
    LinearGradient? gradient,
    ThemeId? themeId,
    Color? focusRing,
  }) {
    return PebbleThemeX(
      gradient: gradient ?? this.gradient,
      themeId: themeId ?? this.themeId,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  PebbleThemeX lerp(ThemeExtension<PebbleThemeX>? other, double t) {
    if (other is! PebbleThemeX) return this;
    return PebbleThemeX(
      gradient: LinearGradient.lerp(gradient, other.gradient, t),
      themeId: other.themeId ?? themeId,
      focusRing: Color.lerp(focusRing, other.focusRing, t) ?? focusRing,
    );
  }
}

class PebbleDarkFoundation extends ThemeExtension<PebbleDarkFoundation> {
  final Color bgBase;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shadowSoft;

  const PebbleDarkFoundation({
    required this.bgBase,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shadowSoft,
  });

  factory PebbleDarkFoundation.fromPalette({
    required Color bg,
    required Color fg,
    required Color accent,
    required bool isDark,
  }) {
    if (!isDark) {
      return PebbleDarkFoundation(
        bgBase: bg,
        surfaceLow: Color.lerp(bg, Colors.white, 0.34) ?? bg,
        surfaceHigh: Color.lerp(bg, Colors.white, 0.52) ?? bg,
        borderSubtle: Color.lerp(fg, accent, 0.24)!.withValues(alpha: 0.16),
        textPrimary: fg.withValues(alpha: 0.94),
        textSecondary: fg.withValues(alpha: 0.68),
        textMuted: fg.withValues(alpha: 0.48),
        shadowSoft: Colors.black.withValues(alpha: 0.08),
      );
    }

    const warmNight = Color(0xFF15120F);
    final bgBase = Color.lerp(warmNight, bg, 0.36)!;
    final textPrimary = Color.lerp(const Color(0xFFFFF5E6), fg, 0.34)!;
    final surfaceLow = Color.lerp(bgBase, textPrimary, 0.055)!;
    final surfaceHigh = Color.lerp(bgBase, textPrimary, 0.092)!;
    return PebbleDarkFoundation(
      bgBase: bgBase,
      surfaceLow: Color.lerp(surfaceLow, accent, 0.035)!,
      surfaceHigh: Color.lerp(surfaceHigh, accent, 0.045)!,
      borderSubtle: Color.lerp(
        textPrimary,
        accent,
        0.22,
      )!.withValues(alpha: 0.15),
      textPrimary: textPrimary,
      textSecondary: Color.lerp(
        textPrimary,
        accent,
        0.08,
      )!.withValues(alpha: 0.74),
      textMuted: Color.lerp(textPrimary, accent, 0.14)!.withValues(alpha: 0.52),
      shadowSoft: Colors.black.withValues(alpha: 0.16),
    );
  }

  @override
  PebbleDarkFoundation copyWith({
    Color? bgBase,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? shadowSoft,
  }) {
    return PebbleDarkFoundation(
      bgBase: bgBase ?? this.bgBase,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      shadowSoft: shadowSoft ?? this.shadowSoft,
    );
  }

  @override
  PebbleDarkFoundation lerp(
    ThemeExtension<PebbleDarkFoundation>? other,
    double t,
  ) {
    if (other is! PebbleDarkFoundation) return this;
    return PebbleDarkFoundation(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
    );
  }
}

class PebbleTemplatesTokens extends ThemeExtension<PebbleTemplatesTokens> {
  final Color templatesBg;
  final Color templatesSurface;
  final Color templatesSurfaceRaised;
  final Color templatesBorder;
  final Color templatesTextPrimary;
  final Color templatesTextSecondary;
  final Color templatesTextMuted;
  final Color templatesAccentGroup1;
  final Color templatesAccentGroup2;
  final Color templatesAccentGroup3;

  const PebbleTemplatesTokens({
    required this.templatesBg,
    required this.templatesSurface,
    required this.templatesSurfaceRaised,
    required this.templatesBorder,
    required this.templatesTextPrimary,
    required this.templatesTextSecondary,
    required this.templatesTextMuted,
    required this.templatesAccentGroup1,
    required this.templatesAccentGroup2,
    required this.templatesAccentGroup3,
  });

  factory PebbleTemplatesTokens.fromFoundation({
    required PebbleDarkFoundation foundation,
    required Color accent,
  }) {
    return PebbleTemplatesTokens(
      templatesBg: foundation.bgBase,
      templatesSurface: foundation.surfaceLow,
      templatesSurfaceRaised: foundation.surfaceHigh,
      templatesBorder: foundation.borderSubtle,
      templatesTextPrimary: foundation.textPrimary,
      templatesTextSecondary: foundation.textSecondary,
      templatesTextMuted: foundation.textMuted,
      templatesAccentGroup1: Color.lerp(const Color(0xFFD99B55), accent, 0.18)!,
      templatesAccentGroup2: Color.lerp(const Color(0xFF8DA174), accent, 0.20)!,
      templatesAccentGroup3: Color.lerp(const Color(0xFFC37B58), accent, 0.22)!,
    );
  }

  @override
  PebbleTemplatesTokens copyWith({
    Color? templatesBg,
    Color? templatesSurface,
    Color? templatesSurfaceRaised,
    Color? templatesBorder,
    Color? templatesTextPrimary,
    Color? templatesTextSecondary,
    Color? templatesTextMuted,
    Color? templatesAccentGroup1,
    Color? templatesAccentGroup2,
    Color? templatesAccentGroup3,
  }) {
    return PebbleTemplatesTokens(
      templatesBg: templatesBg ?? this.templatesBg,
      templatesSurface: templatesSurface ?? this.templatesSurface,
      templatesSurfaceRaised:
          templatesSurfaceRaised ?? this.templatesSurfaceRaised,
      templatesBorder: templatesBorder ?? this.templatesBorder,
      templatesTextPrimary: templatesTextPrimary ?? this.templatesTextPrimary,
      templatesTextSecondary:
          templatesTextSecondary ?? this.templatesTextSecondary,
      templatesTextMuted: templatesTextMuted ?? this.templatesTextMuted,
      templatesAccentGroup1:
          templatesAccentGroup1 ?? this.templatesAccentGroup1,
      templatesAccentGroup2:
          templatesAccentGroup2 ?? this.templatesAccentGroup2,
      templatesAccentGroup3:
          templatesAccentGroup3 ?? this.templatesAccentGroup3,
    );
  }

  @override
  PebbleTemplatesTokens lerp(
    ThemeExtension<PebbleTemplatesTokens>? other,
    double t,
  ) {
    if (other is! PebbleTemplatesTokens) return this;
    return PebbleTemplatesTokens(
      templatesBg: Color.lerp(templatesBg, other.templatesBg, t)!,
      templatesSurface: Color.lerp(
        templatesSurface,
        other.templatesSurface,
        t,
      )!,
      templatesSurfaceRaised: Color.lerp(
        templatesSurfaceRaised,
        other.templatesSurfaceRaised,
        t,
      )!,
      templatesBorder: Color.lerp(templatesBorder, other.templatesBorder, t)!,
      templatesTextPrimary: Color.lerp(
        templatesTextPrimary,
        other.templatesTextPrimary,
        t,
      )!,
      templatesTextSecondary: Color.lerp(
        templatesTextSecondary,
        other.templatesTextSecondary,
        t,
      )!,
      templatesTextMuted: Color.lerp(
        templatesTextMuted,
        other.templatesTextMuted,
        t,
      )!,
      templatesAccentGroup1: Color.lerp(
        templatesAccentGroup1,
        other.templatesAccentGroup1,
        t,
      )!,
      templatesAccentGroup2: Color.lerp(
        templatesAccentGroup2,
        other.templatesAccentGroup2,
        t,
      )!,
      templatesAccentGroup3: Color.lerp(
        templatesAccentGroup3,
        other.templatesAccentGroup3,
        t,
      )!,
    );
  }
}

/// ------------ THEME METADATA ------------
class ThemeMetadata {
  final ThemeId id;
  final String name;
  final IconData icon;
  final String subtitle;
  final String description;
  final ThemePickerCategory category;
  final int sortOrder;
  final bool isVisibleOnMainPicker;
  final bool showInMoreOptionsOnly;
  final String? accessibilityNote;

  const ThemeMetadata({
    required this.id,
    required this.name,
    required this.icon,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.sortOrder,
    this.isVisibleOnMainPicker = true,
    this.showInMoreOptionsOnly = false,
    this.accessibilityNote,
  });

  bool get isPremium => category == ThemePickerCategory.premium;
  bool get isAccessibilityTheme =>
      category == ThemePickerCategory.accessibility;

  static const Map<ThemeId, ThemeMetadata> metadata = {
    ThemeId.highNoon: ThemeMetadata(
      id: ThemeId.highNoon,
      name: 'High Noon',
      icon: LucideIcons.sun,
      subtitle: 'Included light theme',
      description: 'Warm cream, quiet ink, and a grounded green accent.',
      category: ThemePickerCategory.included,
      sortOrder: 10,
    ),
    ThemeId.nordicNight: ThemeMetadata(
      id: ThemeId.nordicNight,
      name: 'Pebble Dark',
      icon: LucideIcons.moon,
      subtitle: 'Legacy warm dark',
      description: 'The original warm amber, sage, and clay dark palette.',
      category: ThemePickerCategory.premium,
      sortOrder: 900,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.paperAndInk: ThemeMetadata(
      id: ThemeId.paperAndInk,
      name: 'Paper & Ink',
      icon: LucideIcons.bookOpen,
      subtitle: 'High contrast light',
      description: 'White paper, crisp black text, and a warmer brown accent.',
      category: ThemePickerCategory.accessibility,
      sortOrder: 120,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
      accessibilityNote: 'High contrast light for stronger readability.',
    ),
    ThemeId.matcha: ThemeMetadata(
      id: ThemeId.matcha,
      name: 'Matcha',
      icon: LucideIcons.leaf,
      subtitle: 'Soft light',
      description: 'A fresh green palette for a clear daytime surface.',
      category: ThemePickerCategory.premium,
      sortOrder: 910,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.roseQuartz: ThemeMetadata(
      id: ThemeId.roseQuartz,
      name: 'Rose Quartz',
      icon: LucideIcons.flower,
      subtitle: 'Soft spa light',
      description: 'Warm, gentle, and quietly expressive.',
      category: ThemePickerCategory.premium,
      sortOrder: 30,
    ),
    ThemeId.deepGlacier: ThemeMetadata(
      id: ThemeId.deepGlacier,
      name: 'Deep Glacier',
      icon: LucideIcons.droplets,
      subtitle: 'Archived cold dark',
      description: 'An older cool palette kept for compatibility.',
      category: ThemePickerCategory.premium,
      sortOrder: 990,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.amberResin: ThemeMetadata(
      id: ThemeId.amberResin,
      name: 'Amber Resin',
      icon: LucideIcons.flame,
      subtitle: 'Included dark theme',
      description: 'A warm dark surface with a rich amber glow.',
      category: ThemePickerCategory.included,
      sortOrder: 20,
    ),
    ThemeId.softPink: ThemeMetadata(
      id: ThemeId.softPink,
      name: 'Soft Pink',
      icon: LucideIcons.heart,
      subtitle: 'Included soft light',
      description: 'A warm, grown-up pink surface with muted green balance.',
      category: ThemePickerCategory.included,
      sortOrder: 30,
    ),
    ThemeId.sageMist: ThemeMetadata(
      id: ThemeId.sageMist,
      name: 'Sage Mist',
      icon: LucideIcons.leaf,
      subtitle: 'Included forest dark',
      description: 'A deep, lush forest green surface with a natural feel.',
      category: ThemePickerCategory.included,
      sortOrder: 40,
    ),
    ThemeId.terracotta: ThemeMetadata(
      id: ThemeId.terracotta,
      name: 'Terracotta',
      icon: LucideIcons.sunset,
      subtitle: 'Earthy dark',
      description: 'Baked clay warmth with a steady accent.',
      category: ThemePickerCategory.premium,
      sortOrder: 920,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.lavenderAsh: ThemeMetadata(
      id: ThemeId.lavenderAsh,
      name: 'Lavender Ash',
      icon: LucideIcons.cloud,
      subtitle: 'Muted evening dark',
      description: 'Soft plum and lavender for an evening workspace.',
      category: ThemePickerCategory.premium,
      sortOrder: 40,
    ),
    ThemeId.oatmealAndWalnut: ThemeMetadata(
      id: ThemeId.oatmealAndWalnut,
      name: 'Oatmeal & Walnut',
      icon: LucideIcons.coffee,
      subtitle: 'Minimal warm light',
      description: 'Quiet oatmeal surfaces with a deeper walnut accent.',
      category: ThemePickerCategory.premium,
      sortOrder: 930,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.midnightSlate: ThemeMetadata(
      id: ThemeId.midnightSlate,
      name: 'Graphite',
      icon: LucideIcons.gem,
      subtitle: 'Warm near-black',
      description: 'Near-black with cream text and a warm amber accent.',
      category: ThemePickerCategory.premium,
      sortOrder: 60,
    ),
    ThemeId.canopy: ThemeMetadata(
      id: ThemeId.canopy,
      name: 'Canopy',
      icon: LucideIcons.treePine,
      subtitle: 'Deep green dark',
      description: 'Woodland dark with a muted forest accent.',
      category: ThemePickerCategory.premium,
      sortOrder: 940,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.parchment: ThemeMetadata(
      id: ThemeId.parchment,
      name: 'Parchment',
      icon: LucideIcons.scrollText,
      subtitle: 'Warm premium light',
      description: 'Aged paper warmth with golden-amber interaction.',
      category: ThemePickerCategory.premium,
      sortOrder: 50,
    ),
    ThemeId.dusk: ThemeMetadata(
      id: ThemeId.dusk,
      name: 'Dusk',
      icon: LucideIcons.sunset,
      subtitle: 'Deep navy',
      description: 'Cool navy held steady by a warm amber accent.',
      category: ThemePickerCategory.premium,
      sortOrder: 950,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.still: ThemeMetadata(
      id: ThemeId.still,
      name: 'Still',
      icon: LucideIcons.circle,
      subtitle: 'Neutral dark',
      description:
          'A settled neutral surface for users who want less character.',
      category: ThemePickerCategory.premium,
      sortOrder: 960,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
    ),
    ThemeId.highContrastDark: ThemeMetadata(
      id: ThemeId.highContrastDark,
      name: 'High Contrast Dark',
      icon: LucideIcons.contrast,
      subtitle: 'Low vision',
      description: 'Black, white, and yellow for maximum dark-mode contrast.',
      category: ThemePickerCategory.accessibility,
      sortOrder: 70,
      accessibilityNote: 'High contrast for stronger readability.',
    ),
    ThemeId.warmSepia: ThemeMetadata(
      id: ThemeId.warmSepia,
      name: 'Warm Sepia',
      icon: LucideIcons.circle,
      subtitle: 'Light sensitivity',
      description:
          'Amber-tinted contrast for migraines, Irlen, and visual stress.',
      category: ThemePickerCategory.accessibility,
      sortOrder: 80,
      accessibilityNote: 'Warm tone for light sensitivity.',
    ),
    ThemeId.reducedContrast: ThemeMetadata(
      id: ThemeId.reducedContrast,
      name: 'Reduced Contrast',
      icon: LucideIcons.moon,
      subtitle: 'Cognitive load',
      description:
          'A quieter low-contrast surface for overwhelm and sensory load.',
      category: ThemePickerCategory.accessibility,
      sortOrder: 110,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
      accessibilityNote:
          'Reduced contrast for overwhelm and sensory sensitivity.',
    ),
    ThemeId.colourBlindSafe: ThemeMetadata(
      id: ThemeId.colourBlindSafe,
      name: 'Colour Blind Safe',
      icon: LucideIcons.eye,
      subtitle: 'Colour vision',
      description: 'Orange, blue, and purple accents for clearer distinction.',
      category: ThemePickerCategory.accessibility,
      sortOrder: 100,
      isVisibleOnMainPicker: false,
      showInMoreOptionsOnly: true,
      accessibilityNote:
          'Uses a colour-blind safer orange, blue, and purple accent triad.',
    ),
  };

  static ThemeMetadata get(ThemeId id) => metadata[id]!;
  static List<ThemeMetadata> get all {
    final items = metadata.values.toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  static List<ThemeMetadata> byCategory(ThemePickerCategory category) {
    return all.where((theme) => theme.category == category).toList();
  }
}

extension ThemeHelpers on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;

  LinearGradient? get backgroundGradient =>
      Theme.of(this).extension<PebbleThemeX>()?.gradient;

  Color get focusRing =>
      Theme.of(this).extension<PebbleThemeX>()?.focusRing ??
      const Color(0x33000000);

  PebbleDarkFoundation get darkFoundation {
    final theme = Theme.of(this);
    final existing = theme.extension<PebbleDarkFoundation>();
    if (existing != null) return existing;
    final colorScheme = theme.colorScheme;
    return PebbleDarkFoundation.fromPalette(
      bg: colorScheme.surface,
      fg: colorScheme.onSurface,
      accent: colorScheme.primary,
      isDark: theme.brightness == Brightness.dark,
    );
  }
}
