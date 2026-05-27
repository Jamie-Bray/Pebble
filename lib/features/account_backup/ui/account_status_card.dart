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
          _PlanBadge(label: state.planLabel, tone: tone),
          const SizedBox(height: 14),
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
          if (state.limitChips.isNotEmpty) ...[
            const SizedBox(height: 18),
            _LimitChipRow(chips: state.limitChips),
          ],
          if (state.featureHighlights.isNotEmpty) ...[
            const SizedBox(height: 18),
            _FeatureHighlightList(
              highlights: state.featureHighlights,
              tone: tone,
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
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
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
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
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

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: tone,
          ),
        ),
      ),
    );
  }
}

class _LimitChipRow extends StatelessWidget {
  const _LimitChipRow({required this.chips});

  final List<AccountPlanChip> chips;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.12)),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final chip in chips) ...[
              Expanded(child: _LimitChip(chip: chip)),
              if (chip != chips.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({required this.chip});

  final AccountPlanChip chip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              chip.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: chip.value.length > 4 ? 17 : 20,
                height: 1,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            chip.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHighlightList extends StatelessWidget {
  const _FeatureHighlightList({required this.highlights, required this.tone});

  final List<AccountFeatureHighlight> highlights;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.12)),
        const SizedBox(height: 14),
        for (final highlight in highlights) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: highlight.emphasis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      TextSpan(text: ' ${highlight.detail}'),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.42,
                    color: colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
              ),
            ],
          ),
          if (highlight != highlights.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
