import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_cairn.dart';
import 'package:pebble_routines/features/routines/cover/routine_cover.dart';

/// A cover at full strength: a painted scene in the theme's (or routine's)
/// colours, or the user's photo. Used for the Style Studio tiles; Home shows
/// it through [RoutineCoverBackdrop].
class RoutineCoverArt extends StatelessWidget {
  const RoutineCoverArt({super.key, required this.cover});

  final RoutineCover cover;

  @override
  Widget build(BuildContext context) {
    final f = context.darkFoundation;
    return switch (cover) {
      RoutineCoverSceneChoice(:final scene) => CustomPaint(
        painter: _ScenePainter(
          scene: scene,
          accent: context.done,
          bg: f.bgBase,
          fg: f.textPrimary,
        ),
        child: const SizedBox.expand(),
      ),
      RoutineCoverPhoto(:final path) => Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.expand(),
      ),
    };
  }
}

/// The soft, dimmed header behind the top of Home. The cover is washed
/// toward the page colour and fades out downwards, so the wordmark, the
/// hero text and the buttons read exactly as they do without it.
class RoutineCoverBackdrop extends StatelessWidget {
  const RoutineCoverBackdrop({super.key, required this.cover});

  final RoutineCover cover;

  @override
  Widget build(BuildContext context) {
    final f = context.darkFoundation;
    final isPhoto = cover is RoutineCoverPhoto;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Photos are busier than the painted scenes, so they are washed out
    // more.
    final wash = isPhoto ? (isDark ? 0.72 : 0.66) : 0.30;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.45, 1],
          ).createShader(rect),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RoutineCoverArt(cover: cover),
              ColoredBox(color: f.bgBase.withValues(alpha: wash)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scene,
    required this.accent,
    required this.bg,
    required this.fg,
  });

  final RoutineCoverScene scene;
  final Color accent;
  final Color bg;
  final Color fg;

  Color _tone(double t) => Color.lerp(bg, accent, t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = _tone(0.10));
    switch (scene) {
      case RoutineCoverScene.ripples:
        final c = Offset(w * 0.48, h * 0.13);
        for (var i = 5; i >= 1; i--) {
          canvas.drawOval(
            Rect.fromCenter(
              center: c,
              width: w * 0.08 * i,
              height: w * 0.045 * i,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, w / 320)
              ..color = _tone(0.67 - i * 0.07),
          );
        }
        final sw = w * 0.065;
        canvas.drawPath(
          pebblePath(
            Rect.fromCenter(
              center: c.translate(0, -sw * 0.12),
              width: sw,
              height: sw * 0.5,
            ),
          ),
          Paint()..color = _tone(0.75),
        );
      case RoutineCoverScene.hills:
        for (final (base, amp, phase, tone) in [
          (0.34, 0.065, 0.2, 0.24),
          (0.49, 0.08, 1.5, 0.38),
          (0.66, 0.065, 2.7, 0.53),
        ]) {
          final path = Path()..moveTo(0, h * base);
          for (var x = 0.0; x <= w; x += w / 60) {
            path.lineTo(
              x,
              h * (base - amp * math.sin(x / w * math.pi * 4 + phase)),
            );
          }
          path
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close();
          canvas.drawPath(path, Paint()..color = _tone(tone));
        }
      case RoutineCoverScene.shore:
        final shore = Path()
          ..moveTo(0, h * 0.34)
          ..cubicTo(w * 0.28, h * 0.27, w * 0.47, h * 0.46, w, h * 0.31)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(shore, Paint()..color = _tone(0.35));
        final foam = Path()
          ..moveTo(0, h * 0.36)
          ..cubicTo(w * 0.28, h * 0.29, w * 0.47, h * 0.48, w, h * 0.33);
        canvas.drawPath(
          foam,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, w / 125)
            ..color = bg.withValues(alpha: 0.62),
        );
        final rnd = math.Random(7);
        for (var i = 0; i < 9; i++) {
          final sw = w * (0.04 + rnd.nextDouble() * 0.05);
          final cx = w * (0.06 + i * 0.11 + rnd.nextDouble() * 0.03);
          final cy = h * (0.52 + rnd.nextDouble() * 0.35);
          canvas.drawPath(
            pebblePath(
              Rect.fromCenter(
                center: Offset(cx, cy),
                width: sw,
                height: sw * 0.52,
              ),
              flip: i.isOdd,
            ),
            Paint()..color = _tone(0.30 + rnd.nextDouble() * 0.35),
          );
        }
      case RoutineCoverScene.dawn:
        final horizon = h * 0.58;
        canvas.drawCircle(
          Offset(w * 0.48, h * 0.14),
          w * 0.11,
          Paint()..color = _tone(0.48),
        );
        final land = Path()
          ..moveTo(0, horizon)
          ..cubicTo(w * 0.3, h * 0.51, w * 0.58, h * 0.64, w, h * 0.55)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(land, Paint()..color = _tone(0.22));
      case RoutineCoverScene.night:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Color.lerp(_tone(0.22), fg, 0.08)!,
        );
        final rnd = math.Random(3);
        for (var i = 0; i < 28; i++) {
          canvas.drawCircle(
            Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.8),
            math.max(0.8, w / 400) * (0.6 + rnd.nextDouble()),
            Paint()
              ..color = bg.withValues(alpha: 0.35 + rnd.nextDouble() * 0.4),
          );
        }
        final moon = Offset(w * 0.48, h * 0.14);
        final r = w * 0.05;
        canvas.saveLayer(Offset.zero & size, Paint());
        canvas.drawCircle(moon, r, Paint()..color = bg.withValues(alpha: 0.85));
        canvas.drawCircle(
          moon.translate(r * 0.45, -r * 0.2),
          r,
          Paint()..blendMode = BlendMode.clear,
        );
        canvas.restore();
      case RoutineCoverScene.softGlow:
        for (final (center, radius, strength) in [
          (const Alignment(0.65, -0.65), 0.75, 0.42),
          (const Alignment(-0.85, 0.35), 0.64, 0.26),
        ]) {
          canvas.drawRect(
            Offset.zero & size,
            Paint()
              ..shader = RadialGradient(
                center: center,
                radius: radius,
                colors: [_tone(strength), _tone(0.10).withValues(alpha: 0)],
              ).createShader(Offset.zero & size),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.scene != scene ||
      old.accent != accent ||
      old.bg != bg ||
      old.fg != fg;
}
