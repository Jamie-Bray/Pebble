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
      _routeToPremium(context, PremiumEntrySource.routineLimit);
      return false;
    }
    final stepLimit = currentTier.maxStepCount;
    if (stepCount != null && stepLimit != null && stepCount > stepLimit) {
      _routeToPremium(context, PremiumEntrySource.stepLimit);
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
      _routeToPremium(context, PremiumEntrySource.stepLimit);
      return false;
    }
    return true;
  }

  static void _routeToPremium(BuildContext context, PremiumEntrySource source) {
    HapticFeedback.mediumImpact();
    GoRouter.of(context).push(premiumRoute(source: source));
  }
}
