import 'package:flutter/material.dart';
import 'package:pebble_routines/core/theme/tokens.dart';

class ZenErrorView extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const ZenErrorView({
    super.key,
    this.title = "Something went wrong",
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PebbleSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 48,
              color: cs.onSurface.withValues(alpha: PebbleOpacity.medium),
            ),
            const SizedBox(height: PebbleSpacing.xl),
            Text(
              title,
              style: PebbleTypography.title.copyWith(
                color: cs.onSurface.withValues(alpha: PebbleOpacity.high),
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: PebbleSpacing.md),
              Text(
                message!,
                style: PebbleTypography.bodyMedium.copyWith(
                  color: cs.onSurface.withValues(alpha: PebbleOpacity.medium),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: PebbleSpacing.xxl),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Try again',
                  style: PebbleTypography.label,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  backgroundColor: cs.primary.withValues(
                    alpha: PebbleOpacity.verySubtle,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: PebbleSpacing.xl,
                    vertical: PebbleSpacing.md,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
