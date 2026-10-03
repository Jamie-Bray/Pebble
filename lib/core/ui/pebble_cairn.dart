import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';

/// The cairn from the app icon, one pebble per step (DESIGN_DIRECTION.md
/// Moment 2). Checked steps are solid pebbles; skipped steps are drawn as
/// outlines, so the record stays honest. At most [maxPebbles] are drawn; for
/// longer routines the bottom pebble carries a "×N" count.
class PebbleCairn extends StatelessWidget {
  const PebbleCairn({
    super.key,
    required this.total,
    this.skipped = 0,
    this.size = 120,
    this.drops,
    this.compress = 0,
    this.showCount = true,
  });

  static const int maxPebbles = 5;

  /// Steps in the run.
  final int total;

  /// Of which skipped.
  final int skipped;
  final double size;

  /// Per pebble (bottom first): (vertical offset in logical px, opacity).
  /// Null draws every pebble at rest.
  final List<(double, double)>? drops;

  /// 0-1: how much of the 2% "settle" squash to apply.
  final double compress;

  /// Draw the "×N" count on the bottom pebble for long routines.
  final bool showCount;

  /// How many pebbles are drawn for [total] steps.
  static int pebbleCount(int total) => total.clamp(1, maxPebbles);

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final done = context.done;
    final x = Theme.of(context).extension<PebbleThemeX>();
    final bg = foundation.bgBase;
    // "done, done at 70%, the category accents" (DESIGN_DIRECTION.md
    // Moment 2). Single-accent themes step the done colour gently lighter up
    // the stack instead, one calm family like the icon's three tones.
    final accents = x != null && x.categoryAccents.length > 1
        ? [
            for (final c in x.categoryAccents)
              if (c != done) Color.lerp(c, bg, 0.12)!,
          ]
        : <Color>[];
    final palette = accents.isEmpty
        ? [
            for (var i = 0; i < maxPebbles; i++)
              Color.lerp(done, bg, 0.14 * i)!,
          ]
        : <Color>[done, Color.lerp(done, bg, 0.30)!, ...accents];
    final count = pebbleCount(total);
    final label = skipped > 0
        ? '${total - skipped} of $total steps checked, $skipped skipped'
        : '$total of $total steps checked';
    return Semantics(
      label: label,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _CairnPainter(
            count: count,
            outlined: skipped.clamp(0, total).toInt() >= total
                ? count
                : math.min(
                    _scaledSkips(skipped, total, count),
                    count - 1,
                  ),
            palette: palette,
            outlineColor: foundation.textSecondary.withValues(alpha: 0.6),
            drops: drops,
            compress: compress,
            countLabel: showCount && total > maxPebbles ? '×$total' : null,
            countStyle: PebbleType.of(context).caption.copyWith(
              color: _onPebble(palette.first),
              fontWeight: FontWeight.w600,
              fontSize: size * 0.11,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// Skipped steps as a share of the drawn pebbles (at least one when any
  /// step was skipped).
  static int _scaledSkips(int skipped, int total, int count) {
    if (skipped <= 0) return 0;
    if (total <= maxPebbles) return skipped;
    return math.max(1, (skipped * count / total).round());
  }

  static Color _onPebble(Color c) =>
      c.computeLuminance() > 0.4 ? const Color(0xFF1B1813) : Colors.white;
}

class _CairnPainter extends CustomPainter {
  _CairnPainter({
    required this.count,
    required this.outlined,
    required this.palette,
    required this.outlineColor,
    required this.drops,
    required this.compress,
    required this.countLabel,
    required this.countStyle,
  });

  final int count;

  /// The top [outlined] pebbles are outlines (skipped).
  final int outlined;
  final List<Color> palette;
  final Color outlineColor;
  final List<(double, double)>? drops;
  final double compress;
  final String? countLabel;
  final TextStyle countStyle;

  // Gentle alternating offsets and tilts, like the stacked icon.
  static const _dx = [0.0, -0.035, 0.045, -0.03, 0.035];
  static const _tilt = [0.0, -0.035, 0.03, -0.03, 0.035];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Widths shrink up the stack from 76 to 44 (on a 120 box).
    final widths = <double>[
      for (var i = 0; i < count; i++)
        count == 1 ? 0.63 * s : (0.63 - (0.27 * i / (count - 1))) * s,
    ];
    final heights = [for (final w in widths) w * 0.46];
    const overlapFactor = 0.10;
    var stack = 0.0;
    for (var i = 0; i < count; i++) {
      stack += heights[i] * (i == 0 ? 1 : 1 - overlapFactor);
    }
    // Fit the stack in the box, bottom-anchored with a small base margin.
    final fit = math.min(1.0, (s * 0.92) / stack);
    final squash = 1 - 0.02 * compress;
    canvas.save();
    canvas.translate(0, s * 0.96);
    canvas.scale(1, squash);
    var bottom = 0.0;
    for (var i = 0; i < count; i++) {
      final w = widths[i] * fit;
      final h = heights[i] * fit;
      final drop = drops == null || i >= drops!.length ? (0.0, 1.0) : drops![i];
      final opacity = drop.$2.clamp(0.0, 1.0);
      final top = bottom - h;
      if (opacity > 0) {
        final cx = s / 2 + _dx[i % _dx.length] * s;
        final rect = Rect.fromLTWH(cx - w / 2, top + drop.$1, w, h);
        canvas.save();
        canvas.translate(rect.center.dx, rect.center.dy);
        canvas.rotate(_tilt[i % _tilt.length]);
        canvas.translate(-rect.center.dx, -rect.center.dy);
        final path = pebblePath(rect, flip: i.isOdd);
        final isOutline = i >= count - outlined;
        if (isOutline) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, s / 80)
              ..color = outlineColor.withValues(
                alpha: outlineColor.a * opacity,
              ),
          );
        } else {
          final base = palette[i % palette.length];
          final lit = Color.lerp(base, Colors.white, 0.06)!;
          canvas.drawPath(
            path,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lit.withValues(alpha: lit.a * opacity),
                  base.withValues(alpha: base.a * opacity),
                ],
              ).createShader(rect),
          );
        }
        if (i == 0 && countLabel != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: countLabel,
              style: countStyle.copyWith(
                color: isOutline ? outlineColor : countStyle.color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(
              rect.center.dx - tp.width / 2,
              rect.center.dy - tp.height / 2,
            ),
          );
        }
        canvas.restore();
      }
      bottom = top + h * overlapFactor;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CairnPainter old) =>
      old.count != count ||
      old.outlined != outlined ||
      old.palette != palette ||
      old.drops != drops ||
      old.compress != compress ||
      old.countLabel != countLabel;
}

/// A soft, slightly asymmetric pebble in [r]: flatter underneath, fuller on
/// top, like the stones in the app icon.
Path pebblePath(Rect r, {bool flip = false}) {
  final w = r.width, h = r.height;
  final cx = r.center.dx + (flip ? -0.04 : 0.04) * w;
  final cy = r.center.dy + 0.04 * h;
  const k = 0.66; // > 0.552 (ellipse): squarer shoulders.
  final left = Offset(r.left, cy);
  final right = Offset(r.right, cy - 0.02 * h);
  final top = Offset(cx, r.top);
  final bottom = Offset(r.center.dx, r.bottom);
  return Path()
    ..moveTo(left.dx, left.dy)
    ..cubicTo(
      left.dx,
      left.dy - (left.dy - r.top) * k,
      top.dx - (top.dx - r.left) * k,
      top.dy,
      top.dx,
      top.dy,
    )
    ..cubicTo(
      top.dx + (r.right - top.dx) * k,
      top.dy,
      right.dx,
      right.dy - (right.dy - r.top) * k,
      right.dx,
      right.dy,
    )
    ..cubicTo(
      right.dx,
      right.dy + (r.bottom - right.dy) * k * 1.05,
      bottom.dx + (r.right - bottom.dx) * k * 1.05,
      bottom.dy,
      bottom.dx,
      bottom.dy,
    )
    ..cubicTo(
      bottom.dx - (bottom.dx - r.left) * k * 1.05,
      bottom.dy,
      left.dx,
      left.dy + (r.bottom - left.dy) * k * 1.05,
      left.dx,
      left.dy,
    )
    ..close();
}

/// Where pebble [index] is [elapsed] after the cairn starts building: it
/// falls from 48 px above on the "land" spring (one small, weighty bounce).
(double, double) cairnDropAt(int index, Duration elapsed) {
  final start = cairnPebbleStart(index);
  final t = (elapsed - start).inMicroseconds / 1e6;
  if (t <= 0) return (-48, 0);
  final sim = SpringSimulation(PebbleMotion.land, -48, 0, 0);
  final opacity = (t / 0.12).clamp(0.0, 1.0);
  if (sim.isDone(t)) return (0, 1);
  return (sim.x(t), opacity);
}

/// When pebble [index] starts to fall: 200 + i·110 ms.
Duration cairnPebbleStart(int index) =>
    Duration(milliseconds: 200 + index * 110);

/// When a falling pebble first touches down (its "tap" haptic).
const Duration cairnTouchDown = Duration(milliseconds: 90);
