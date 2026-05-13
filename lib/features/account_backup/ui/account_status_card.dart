import 'package:flutter/material.dart';

import 'package:pebble_routines/features/account_backup/providers/account_status_mapper.dart';

class AccountStatusCard extends StatelessWidget {
  const AccountStatusCard({
    super.key,
    required this.state,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
    this.isPrimaryBusy = false,
    this.isSecondaryBusy = false,
  });

  final AccountStatusPresentation state;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final bool isPrimaryBusy;
  final bool isSecondaryBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone = _toneColor(colorScheme);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(state.icon, size: 25, color: tone),
          ),
          const SizedBox(height: 18),
          Text(
            state.title,
            style: TextStyle(
              fontSize: 29,
              height: 1.04,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            state.body,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: colorScheme.onSurface.withValues(alpha: 0.70),
            ),
          ),
          if (state.supportingDetail != null) ...[
            const SizedBox(height: 14),
            Text(
              state.supportingDetail!,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
          ],
          if (state.showPremiumNote) ...[
            const SizedBox(height: 14),
            Text(
              'Premium adds longer history and backup.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colorScheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
          ],
          if (state.primaryActionLabel != null ||
              state.secondaryActionLabel != null) ...[
            const SizedBox(height: 22),
            if (state.primaryActionLabel != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isPrimaryBusy ? null : onPrimaryAction,
                  child: isPrimaryBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(state.primaryActionLabel!),
                ),
              ),
            if (state.secondaryActionLabel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isSecondaryBusy ? null : onSecondaryAction,
                  child: isSecondaryBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(state.secondaryActionLabel!),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Color _toneColor(ColorScheme colorScheme) {
    return switch (state.tone) {
      AccountStatusTone.neutral => colorScheme.onSurface.withValues(
        alpha: 0.70,
      ),
      AccountStatusTone.ready => colorScheme.tertiary,
      AccountStatusTone.active => colorScheme.primary,
      AccountStatusTone.paused => colorScheme.secondary,
      AccountStatusTone.attention => colorScheme.error,
    };
  }
}
