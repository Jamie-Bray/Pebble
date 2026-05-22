import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

class SubscriptionGuard {
  static bool canCreateRoutine(
    BuildContext context,
    WidgetRef ref,
    int currentRoutineCount, {
    int? stepCount,
  }) {
    final currentTier = ref.read(subscriptionProvider);
    final routineLimit = currentTier.maxRoutineCount;
    if (routineLimit != null && currentRoutineCount >= routineLimit) {
      _showRoutineLimitExplanation(context, routineLimit);
      return false;
    }
    final stepLimit = currentTier.maxStepCount;
    if (stepCount != null && stepLimit != null && stepCount > stepLimit) {
      _showStepLimitExplanation(context, stepLimit);
      return false;
    }
    return true;
  }

  static bool canAddStep(
    BuildContext context,
    WidgetRef ref,
    int currentStepCount,
  ) {
    final currentTier = ref.read(subscriptionProvider);
    final limit = currentTier.maxStepCount;
    if (limit != null && currentStepCount >= limit) {
      _showStepLimitExplanation(context, limit);
      return false;
    }
    return true;
  }

  static void _showRoutineLimitExplanation(BuildContext context, int limit) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'You have reached the free routine limit',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pebble is free to use with no login and no ads. Free includes $limit routines; unlimited routines are part of Pebble Premium.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  GoRouter.of(
                    context,
                  ).push(premiumRoute(source: PremiumEntrySource.routineLimit));
                },
                child: const Text('View Pebble Premium'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showStepLimitExplanation(BuildContext context, int limit) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'You have reached the free step limit',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pebble is free to use with no login and no ads. Free includes $limit steps per routine; unlimited steps are part of Pebble Premium.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  GoRouter.of(
                    context,
                  ).push(premiumRoute(source: PremiumEntrySource.stepLimit));
                },
                child: const Text('View Pebble Premium'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
