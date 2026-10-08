import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_cairn.dart';

/// How the stones are laid out.
enum PebbleStonesScene {
  /// One pebble with two ripples spreading under it: "Small steps, big
  /// ripples". For empty Home.
  ripple,

  /// Three loose stones waiting to be stacked. For an empty History.
  scattered,

  /// One pebble resting on its shadow. For smaller empty states.
  resting,
}

/// Pebble's quiet mascot: the stone from the icon, drawn where a screen has
/// nothing else to show yet. It never moves, never speaks and never appears
/// once there is real content, so it can't get in the way.
class PebbleStones extends StatelessWidget {
  const PebbleStones({
    super.key,
    this.scene = PebbleStonesScene.resting,
    this.size = 96,
  });

  final PebbleStonesScene scene;

  /// Width of the drawing; the height is [size] × 0.6.
  final double size;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size * 0.6,
        child: CustomPaint(
          painter: _StonesPainter(
            scene: scene,
            stone: context.done,
            bg: foundation.bgBase,
          ),
        ),
      ),
    );
  }
}

class _StonesPainter extends CustomPainter {
  _StonesPainter({required this.scene, required this.stone, required this.bg});

  final PebbleStonesScene scene;
  final Color stone;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (scene) {
      case PebbleStonesScene.ripple:
        // The stone has just landed: it sits in the middle of its ripples,
        // not above them.
        final ground = h * 0.70;
        final sw = w * 0.38;
        final sh = sw * 0.52;
        for (final (scale, alpha) in [(0.98, 0.14), (0.66, 0.28)]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(w / 2, ground),
              width: w * scale,
              height: h * 0.34 * scale,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, w / 90)
              ..color = stone.withValues(alpha: alpha),
          );
        }
        _stone(
          canvas,
          Rect.fromCenter(
            center: Offset(w / 2, ground - sh * 0.28),
            width: sw,
            height: sh,
          ),
          stone,
          tilt: -0.04,
        );
      case PebbleStonesScene.scattered:
        final ground = h * 0.86;
        final stones = [
          (0.22, 0.30, 0.06, 0.28),
          (0.52, 0.24, -0.08, 0.0),
          (0.79, 0.20, 0.10, 0.45),
        ];
        for (final (cx, width, tilt, fade) in stones) {
          final sw = w * width;
          final sh = sw * 0.48;
          _shadow(canvas, Offset(w * cx, ground), sw);
          _stone(
            canvas,
            Rect.fromCenter(
              center: Offset(w * cx, ground - sh / 2),
              width: sw,
              height: sh,
            ),
            Color.lerp(stone, bg, fade)!,
            tilt: tilt,
            flip: tilt < 0,
          );
        }
      case PebbleStonesScene.resting:
        final ground = h * 0.86;
        final sw = w * 0.46;
        final sh = sw * 0.50;
        _shadow(canvas, Offset(w / 2, ground), sw * 1.1);
        _stone(
          canvas,
          Rect.fromCenter(
            center: Offset(w / 2, ground - sh / 2),
            width: sw,
            height: sh,
          ),
          stone,
          tilt: 0.05,
        );
    }
  }

  void _shadow(Canvas canvas, Offset at, double width) {
    canvas.drawOval(
      Rect.fromCenter(center: at, width: width * 0.92, height: width * 0.12),
      Paint()..color = stone.withValues(alpha: 0.12),
    );
  }

  void _stone(
    Canvas canvas,
    Rect rect,
    Color base, {
    double tilt = 0,
    bool flip = false,
  }) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(tilt);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    final lit = Color.lerp(base, Colors.white, 0.10)!;
    canvas.drawPath(
      pebblePath(rect, flip: flip),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lit, base],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StonesPainter old) =>
      old.scene != scene || old.stone != stone || old.bg != bg;
}
