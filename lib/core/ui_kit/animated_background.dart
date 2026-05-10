import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PebbleDynamicBackground extends StatelessWidget {
  final ThemeData theme;
  final Animation<double> ambientAnimation;
  final double scrollOffset;
  const PebbleDynamicBackground({
    super.key,
    required this.theme,
    required this.ambientAnimation,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: ambientAnimation,
        builder: (_, __) => CustomPaint(
          size: size,
          painter: _FluidBackgroundPainter(
            primaryColor: theme.colorScheme.primary,
            secondaryColor: theme.colorScheme.secondary,
            scrollOffset: scrollOffset,
            animationValue: ambientAnimation.value,
          ),
        ),
      ),
    );
  }
}

class _FluidBackgroundPainter extends CustomPainter {
  final Color primaryColor, secondaryColor;
  final double scrollOffset, animationValue;
  _FluidBackgroundPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.scrollOffset,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final base = Paint()
      ..shader = ui.Gradient.radial(
        Offset(
          size.width * (0.78 + animationValue * 0.08),
          -scrollOffset * 0.3 + animationValue * 24,
        ),
        size.width * 0.85,
        [
          primaryColor.withValues(alpha: 0.03),
          secondaryColor.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(rect, base);

    final path = Path();
    final waveHeight = 30 + animationValue * 10;
    path.moveTo(0, size.height * 0.3 - scrollOffset * 0.2);
    for (double x = 0; x <= size.width; x += 2) {
      final y =
          size.height * 0.3 -
          scrollOffset * 0.2 +
          math.sin(
                (x / size.width * 2 * math.pi) + animationValue * 2 * math.pi,
              ) *
              waveHeight;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = secondaryColor.withValues(alpha: 0.02),
    );
  }

  @override
  bool shouldRepaint(covariant _FluidBackgroundPainter old) =>
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor ||
      old.scrollOffset != scrollOffset ||
      old.animationValue != animationValue;
}
