import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The two typefaces Pebble ships (DESIGN_DIRECTION.md §3.1).
///
/// Both are bundled under `assets/fonts/` and google_fonts is told never to
/// fetch, so a first launch offline still renders the real fonts. Only the
/// weights in [sansWeights] (plus italic 400) are bundled: every DM Sans style
/// must go through [sans] so a stray `w700` resolves to a bundled file instead
/// of asking google_fonts for one it cannot load.
abstract final class PebbleFonts {
  /// DM Sans weights bundled with the app.
  static const List<FontWeight> sansWeights = [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
  ];

  /// Call once from `main()` before the first frame.
  static void configure() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LicenseRegistry.addLicense(_licenses);
  }

  static Stream<LicenseEntry> _licenses() async* {
    yield LicenseEntryWithLineBreaks(
      const ['DM Sans'],
      await rootBundle.loadString('assets/fonts/OFL-DMSans.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['DM Serif Display'],
      await rootBundle.loadString('assets/fonts/OFL-DMSerifDisplay.txt'),
    );
  }

  /// Snaps [weight] to the nearest bundled DM Sans weight.
  static FontWeight sansWeight(FontWeight? weight) {
    final value = (weight ?? FontWeight.w400).value;
    if (value <= 400) return FontWeight.w400;
    if (value <= 500) return FontWeight.w500;
    return FontWeight.w600;
  }

  /// DM Sans, clamped to the bundled weights. Same arguments as
  /// `GoogleFonts.dmSans`.
  static TextStyle sans({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    double? decorationThickness,
  }) {
    final italic = (fontStyle ?? textStyle?.fontStyle) == FontStyle.italic;
    return GoogleFonts.dmSans(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      // Only italic 400 is bundled.
      fontWeight: italic
          ? FontWeight.w400
          : sansWeight(fontWeight ?? textStyle?.fontWeight),
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
    );
  }

  /// DM Serif Display (regular or italic). It has a single weight, so
  /// [fontWeight] is accepted for call-site symmetry but always 400.
  static TextStyle serif({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    double? decorationThickness,
  }) {
    return GoogleFonts.dmSerifDisplay(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
    );
  }

  /// A DM Sans text theme limited to bundled weights.
  static TextTheme sansTextTheme([TextTheme? base]) {
    // Same as GoogleFonts.dmSansTextTheme, but without first asking
    // google_fonts for an unbundled weight.
    final theme = base ?? ThemeData.light().textTheme;
    TextStyle? fix(TextStyle? s) => s == null ? null : sans(textStyle: s);
    return theme.copyWith(
      displayLarge: fix(theme.displayLarge),
      displayMedium: fix(theme.displayMedium),
      displaySmall: fix(theme.displaySmall),
      headlineLarge: fix(theme.headlineLarge),
      headlineMedium: fix(theme.headlineMedium),
      headlineSmall: fix(theme.headlineSmall),
      titleLarge: fix(theme.titleLarge),
      titleMedium: fix(theme.titleMedium),
      titleSmall: fix(theme.titleSmall),
      bodyLarge: fix(theme.bodyLarge),
      bodyMedium: fix(theme.bodyMedium),
      bodySmall: fix(theme.bodySmall),
      labelLarge: fix(theme.labelLarge),
      labelMedium: fix(theme.labelMedium),
      labelSmall: fix(theme.labelSmall),
    );
  }
}
