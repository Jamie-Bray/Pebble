import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';

/// 4-pt spacing scale (DESIGN_DIRECTION.md §3.2).
///
/// Page gutter 24 (20 below 375 wide), card padding 20, compact rows 16,
/// icon-to-text 12, between sections 32, overline to content 12, title to
/// subtitle 8, subtitle to content 24.
///
/// The previous scale used the same names for different values (xs 4, sm 8,
/// lg 24, xl 32, xxl 48), so those names could not be kept as aliases; every
/// call site was moved to the value-equivalent new name instead.
abstract final class PebbleSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double x3 = 40;
  static const double x4 = 56;

  /// Horizontal page gutter for a screen [width] wide.
  static double gutter(double width) => width < 375 ? lg : xl;

  /// The old 48 step, kept for one release.
  @Deprecated('Use PebbleSpacing.x3 (40) or PebbleSpacing.x4 (56).')
  static const double legacy48 = 48;
}

/// Five corner radii (DESIGN_DIRECTION.md §3.3). Concentric rule: an inner
/// radius is the outer radius minus the padding between them.
abstract final class PebbleRadius {
  /// Chips inside cards, thumbnails in strips.
  static const double xs = 8;

  /// Icon tiles, inputs.
  static const double sm = 12;

  /// Small cards, segmented controls.
  static const double md = 16;

  /// Cards, sheets, photo frames.
  static const double lg = 24;

  /// All buttons, chips, the tab bar.
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

class PebbleOpacity {
  static const double verySubtle = 0.05;
  static const double subtle = 0.08;
  static const double low = 0.1;
  static const double medium = 0.3;
  static const double high = 0.65;
  static const double veryHigh = 0.8;
  static const double solid = 0.95;
}

/// Shared motion tokens (DESIGN_DIRECTION.md §4). Settle, don't bounce.
abstract final class PebbleMotion {
  static const Duration tap = Duration(milliseconds: 90);

  /// Fades, colour changes.
  static const Duration quick = Duration(milliseconds: 150);

  /// Enters.
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasized = Duration(milliseconds: 400);

  /// Reduce Motion fallback cross-fade.
  static const Duration reduced = Duration(milliseconds: 120);

  static const Curve enter = Curves.easeOutCubic;

  /// Material 3 emphasized decelerate.
  static const Curve emphasizedCurve = Cubic(0.2, 0.0, 0.0, 1.0);

  /// "Settle": no visible overshoot (< 2%). Use for layout moves.
  static final SpringDescription settle = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.9,
  );

  /// "Land": one small, weighty bounce. Only for pebbles landing on
  /// completion.
  static final SpringDescription land = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 0.62,
  );

  /// [settle] as a 0→1 [Curve], for APIs that take a curve
  /// (CurvedAnimation, AnimatedFoo widgets).
  static const Curve settleCurve = _SpringCurve.settle();
}

/// A critically-damped-ish spring sampled as a 0→1 curve. Precomputed so it
/// can be a const [Curve].
class _SpringCurve extends Curve {
  const _SpringCurve.settle();

  @override
  double transformInternal(double t) {
    // Spring from 0 to 1 with the [PebbleMotion.settle] description,
    // normalised over the time it takes to come to rest (~0.42 s).
    const duration = 0.42;
    final sim = SpringSimulation(PebbleMotion.settle, 0, 1, 0);
    return sim.x(t * duration).clamp(0.0, 1.02);
  }
}

/// Text styles from DESIGN_DIRECTION.md §3.1, built from the theme. Two
/// families only (DM Serif Display for display text, page titles and big
/// numbers; DM Sans for everything else) and weights 400/500/600.
///
/// Read with `PebbleType.of(context)`. [overline] is meant to be shown in
/// UPPERCASE by the caller.
@immutable
class PebbleType extends ThemeExtension<PebbleType> {
  const PebbleType({
    required this.displayXL,
    required this.display,
    required this.title1,
    required this.title2,
    required this.step,
    required this.sheetTitle,
    required this.headline,
    required this.bodyLarge,
    required this.body,
    required this.caption,
    required this.overline,
    required this.button,
  });

  /// Builds the scale in [color] (normally the theme's primary text).
  factory PebbleType.forColor(Color color) {
    TextStyle serif(double size, double line, double tracking) =>
        PebbleFonts.serif(
          fontSize: size,
          height: line / size,
          letterSpacing: tracking,
          color: color,
        );
    TextStyle sans(
      double size,
      double line,
      FontWeight weight, [
      double tracking = 0,
    ]) => PebbleFonts.sans(
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      letterSpacing: tracking,
      color: color,
    );
    return PebbleType(
      displayXL: serif(
        56,
        56,
        -1.0,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      display: serif(44, 46, -0.6),
      title1: serif(34, 38, -0.4),
      title2: serif(26, 30, -0.2),
      step: sans(32, 38, FontWeight.w600, -0.4),
      sheetTitle: sans(22, 28, FontWeight.w600, -0.2),
      headline: sans(18, 24, FontWeight.w600),
      bodyLarge: sans(17, 25, FontWeight.w400),
      body: sans(15, 22, FontWeight.w400),
      caption: sans(13, 18, FontWeight.w500),
      overline: sans(12, 16, FontWeight.w600, 1.2),
      button: sans(17, 20, FontWeight.w600),
    );
  }

  /// The theme's scale, or one built from `onSurface` when a theme has no
  /// [PebbleType] extension.
  static PebbleType of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PebbleType>() ??
        PebbleType.forColor(theme.colorScheme.onSurface);
  }

  /// The time on completion and on the Home "checked" card.
  final TextStyle displayXL;

  /// Home routine name, onboarding heroes, paywall hero.
  final TextStyle display;

  /// Every page title.
  final TextStyle title1;

  /// In-page heroes ("Free plan", "Backup is off").
  final TextStyle title2;

  /// Player step instruction.
  final TextStyle step;

  /// Bottom-sheet titles.
  final TextStyle sheetTitle;

  /// Card and row titles.
  final TextStyle headline;

  /// Lead paragraphs.
  final TextStyle bodyLarge;

  /// Body, row subtitles.
  final TextStyle body;

  /// Meta lines, chips.
  final TextStyle caption;

  /// Section labels ("YOUR NEXT RIPPLE"); show in uppercase.
  final TextStyle overline;

  /// All button labels.
  final TextStyle button;

  @override
  PebbleType copyWith({
    TextStyle? displayXL,
    TextStyle? display,
    TextStyle? title1,
    TextStyle? title2,
    TextStyle? step,
    TextStyle? sheetTitle,
    TextStyle? headline,
    TextStyle? bodyLarge,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? overline,
    TextStyle? button,
  }) {
    return PebbleType(
      displayXL: displayXL ?? this.displayXL,
      display: display ?? this.display,
      title1: title1 ?? this.title1,
      title2: title2 ?? this.title2,
      step: step ?? this.step,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      headline: headline ?? this.headline,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      body: body ?? this.body,
      caption: caption ?? this.caption,
      overline: overline ?? this.overline,
      button: button ?? this.button,
    );
  }

  @override
  PebbleType lerp(ThemeExtension<PebbleType>? other, double t) {
    if (other is! PebbleType) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return PebbleType(
      displayXL: l(displayXL, other.displayXL),
      display: l(display, other.display),
      title1: l(title1, other.title1),
      title2: l(title2, other.title2),
      step: l(step, other.step),
      sheetTitle: l(sheetTitle, other.sheetTitle),
      headline: l(headline, other.headline),
      bodyLarge: l(bodyLarge, other.bodyLarge),
      body: l(body, other.body),
      caption: l(caption, other.caption),
      overline: l(overline, other.overline),
      button: l(button, other.button),
    );
  }
}

/// Legacy type ramp. Prefer [PebbleType].
class PebbleTypography {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tagline = TextStyle(
    fontSize: 14,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
  );
}
