import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';

class AccountBackupHeaderAction extends ConsumerWidget {
  const AccountBackupHeaderAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringState = ref.watch(accountBackupRingStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: ringState.semanticsLabel,
      hint: ringState.semanticsHint,
      child: Tooltip(
        message: 'Account Hub',
        child: InkResponse(
          radius: 24,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/account-hub');
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (ringState.showRing)
                  CustomPaint(
                    size: const Size.square(40),
                    painter: _AccountBackupRingPainter(
                      colorScheme: colorScheme,
                      variant: ringState.variant,
                    ),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface.withValues(alpha: 0.58),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Icon(
                    LucideIcons.userRound,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountBackupRingPainter extends CustomPainter {
  const _AccountBackupRingPainter({
    required this.colorScheme,
    required this.variant,
  });

  final ColorScheme colorScheme;
  final AccountBackupRingVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    switch (variant) {
      case AccountBackupRingVariant.none:
        return;
      case AccountBackupRingVariant.available:
        paint.color = colorScheme.primary.withValues(alpha: 0.72);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);
        return;
      case AccountBackupRingVariant.syncing:
        paint.color = colorScheme.primary.withValues(alpha: 0.78);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 1.45, false, paint);
        return;
      case AccountBackupRingVariant.paused:
        paint.color = colorScheme.outline.withValues(alpha: 0.75);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 0.7, false, paint);
        canvas.drawArc(rect, math.pi * 0.35, math.pi * 0.7, false, paint);
        return;
      case AccountBackupRingVariant.consentRequired:
        paint.color = colorScheme.tertiary.withValues(alpha: 0.82);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 0.95, false, paint);
        canvas.drawArc(rect, math.pi * 0.85, math.pi * 0.55, false, paint);
        return;
      case AccountBackupRingVariant.offlinePending:
        paint.color = colorScheme.secondary.withValues(alpha: 0.76);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 1.8, false, paint);
        return;
      case AccountBackupRingVariant.storageWarning:
        paint.color = colorScheme.tertiary.withValues(alpha: 0.82);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 1.72, false, paint);
        return;
      case AccountBackupRingVariant.error:
        paint.color = colorScheme.error.withValues(alpha: 0.82);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 0.75, false, paint);
        canvas.drawArc(rect, math.pi * 0.05, math.pi * 0.75, false, paint);
        canvas.drawArc(rect, math.pi * 1.15, math.pi * 0.45, false, paint);
        return;
    }
  }

  @override
  bool shouldRepaint(covariant _AccountBackupRingPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.colorScheme != colorScheme;
  }
}
