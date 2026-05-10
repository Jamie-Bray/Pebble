import 'dart:math' as math;
import 'package:flutter/material.dart';

enum WallpaperType { none, geometricSwirls, waves, minimalistLines, dots, grid }

class BackgroundPattern extends StatelessWidget {
  final WallpaperType type;
  final double opacity;
  final Color color;

  const BackgroundPattern({
    super.key,
    required this.type,
    this.opacity = 0.05,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (type == WallpaperType.none) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WallpaperPainter(type, color),
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  final WallpaperType type;
  final Color color;

  _WallpaperPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    switch (type) {
      case WallpaperType.geometricSwirls:
        _drawSwirls(canvas, size, paint);
        break;
      case WallpaperType.waves:
        _drawWaves(canvas, size, paint);
        break;
      case WallpaperType.minimalistLines:
        _drawLines(canvas, size, paint);
        break;
      case WallpaperType.dots:
        _drawDots(canvas, size, paint);
        break;
      case WallpaperType.grid:
        _drawGrid(canvas, size, paint);
        break;
      case WallpaperType.none:
        break;
    }
  }

  void _drawSwirls(Canvas canvas, Size size, Paint paint) {
    for (double i = 0; i < size.width + 60; i += 60) {
      for (double j = 0; j < size.height + 60; j += 60) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(i, j), width: 30, height: 30),
          0,
          math.pi * 1.5,
          false,
          paint,
        );
      }
    }
  }

  void _drawWaves(Canvas canvas, Size size, Paint paint) {
    for (double i = -20; i < size.height + 20; i += 40) {
      final path = Path();
      path.moveTo(0, i);
      for (double j = 0; j < size.width + 40; j += 40) {
        path.quadraticBezierTo(j + 10, i + 10, j + 20, i);
        path.quadraticBezierTo(j + 30, i - 10, j + 40, i);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawLines(Canvas canvas, Size size, Paint paint) {
    for (double i = -size.height; i < size.width; i += 60) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height * 0.5, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(i + 30, 0),
        Offset(i + 30 + size.height * 0.2, size.height),
        paint,
      );
    }
  }

  void _drawDots(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    for (double i = 15; i < size.width; i += 40) {
      for (double j = 15; j < size.height; j += 40) {
        canvas.drawCircle(Offset(i, j), 1.0, paint);
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
