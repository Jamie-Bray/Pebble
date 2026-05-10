import 'package:flutter/material.dart';

class BigHeader extends StatelessWidget {
  final String line1; // e.g., 'Visual'
  final String line2; // e.g., 'Preferences'
  final String? meta; // e.g., 'Current theme: Dusk'
  final Animation<double>? fadeIn, slideUp;
  const BigHeader({
    super.key,
    required this.line1,
    required this.line2,
    this.meta,
    this.fadeIn,
    this.slideUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line1,
            style: TextStyle(
              fontSize: 48,
              height: 1.0,
              fontWeight: FontWeight.w200,
              letterSpacing: -2,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            line2,
            style: TextStyle(
              fontSize: 48,
              height: 1.1,
              fontWeight: FontWeight.w200,
              letterSpacing: -2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          if (meta != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 1,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Text(
                  meta!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    Widget wrapped = fadeIn == null && slideUp == null
        ? content
        : FadeTransition(
            opacity: fadeIn!,
            child: AnimatedBuilder(
              animation: slideUp!,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, 20 * (1 - slideUp!.value)),
                child: child,
              ),
              child: content,
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: wrapped,
    );
  }
}
