import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pebble_routines/core/theme/colors.dart';

/// WCAG AA minimum for body-size text.
const double kMinBodyTextContrast = 4.5;

/// WCAG AA minimum for large text (18pt, or 14pt bold) and UI glyphs.
const double kMinLargeTextContrast = 3.0;

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// Contrast ratio of [foreground] (composited over [background]) against
/// [background].
double contrastRatio(Color foreground, Color background) {
  final opaqueBackground = background.withValues(alpha: 1);
  final fg = _luminance(Color.alphaBlend(foreground, opaqueBackground));
  final bg = _luminance(opaqueBackground);
  return (math.max(fg, bg) + 0.05) / (math.min(fg, bg) + 0.05);
}

/// Returns [color], nudged toward [strongest] only as far as needed to reach
/// [minContrast] against every colour in [backgrounds].
///
/// Keeps the theme's quiet secondary look wherever it already passes, and
/// only firms it up where it does not.
Color ensureContrast(
  Color color, {
  required List<Color> backgrounds,
  required Color strongest,
  double minContrast = kMinBodyTextContrast,
}) {
  bool passes(Color c) =>
      backgrounds.every((bg) => contrastRatio(c, bg) >= minContrast);
  if (passes(color)) return color;
  final base = Color.alphaBlend(color, backgrounds.first.withValues(alpha: 1));
  final target = Color.alphaBlend(
    strongest,
    backgrounds.first.withValues(alpha: 1),
  );
  for (var step = 1; step <= 20; step++) {
    final candidate = Color.lerp(base, target, step / 20)!;
    if (passes(candidate)) return candidate;
  }
  return target;
}

extension PebbleReadableColors on BuildContext {
  List<Color> get _textBackgrounds {
    final f = darkFoundation;
    return [f.bgBase, f.surfaceLow];
  }

  /// Secondary text (captions, meta lines, hints) that meets 4.5:1 on the
  /// page and on low cards in every theme.
  Color get readableSecondaryText => ensureContrast(
    darkFoundation.textSecondary,
    backgrounds: _textBackgrounds,
    strongest: darkFoundation.textPrimary,
  );

  /// The primary button fill: the theme's action colour, firmed up only as
  /// far as needed for its label ([ColorScheme.onPrimary]) to reach 4.5:1.
  /// Reduced Contrast is deliberately soft and keeps its colour.
  Color get readableActionFill {
    final theme = Theme.of(this);
    final cs = theme.colorScheme;
    if (theme.extension<PebbleThemeX>()?.themeId == ThemeId.reducedContrast) {
      return cs.primary;
    }
    return ensureContrast(
      cs.primary,
      backgrounds: [cs.onPrimary],
      strongest: darkFoundation.textPrimary,
    );
  }

  /// Accent-coloured small text (overlines, status words) that meets 4.5:1.
  Color readableAccentText(Color accent) => ensureContrast(
    accent,
    backgrounds: _textBackgrounds,
    strongest: darkFoundation.textPrimary,
  );
}
