import 'package:flutter/material.dart';
import 'package:pebble_routines/core/theme/tokens.dart';

/// A one-time hint: a small dark bubble with one sentence and "Got it".
///
/// The caller decides when it shows (see OnboardingTour) and hides it when
/// [onDismiss] is called. The pointer sits under the bubble when
/// [pointsDown], else above it.
class PebbleHintBubble extends StatelessWidget {
  const PebbleHintBubble({
    super.key,
    required this.message,
    required this.onDismiss,
    this.pointsDown = true,
  });

  final String message;
  final VoidCallback onDismiss;
  final bool pointsDown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = PebbleType.of(context);
    final background = scheme.inverseSurface;
    final foreground = scheme.onInverseSurface;
    final pointer = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomPaint(
        size: const Size(14, 7),
        painter: _PointerPainter(color: background, down: pointsDown),
      ),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: pointsDown
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (!pointsDown) pointer,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(PebbleRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: type.caption.copyWith(
                      color: foreground,
                      height: 1.35,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(48, 40),
                  ),
                  child: Text(
                    'Got it',
                    style: type.caption.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pointsDown) pointer,
        ],
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter({required this.color, required this.down});

  final Color color;
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final path = down
        ? (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width, 0)
            ..lineTo(size.width / 2, size.height)
            ..close())
        : (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width, size.height)
            ..lineTo(size.width / 2, 0)
            ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.color != color || old.down != down;
}
