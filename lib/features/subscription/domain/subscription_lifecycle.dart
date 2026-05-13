import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';

enum SubscriptionLifecyclePhase { free, activePremium, expiredGrace, expired }

class SubscriptionLifecycle {
  const SubscriptionLifecycle({
    required this.phase,
    required this.expiredAt,
    required this.graceEndsAt,
  });

  static const graceDuration = Duration(days: 7);

  final SubscriptionLifecyclePhase phase;
  final DateTime? expiredAt;
  final DateTime? graceEndsAt;

  bool get hasPremiumRetention =>
      phase == SubscriptionLifecyclePhase.activePremium ||
      phase == SubscriptionLifecyclePhase.expiredGrace;

  bool get canUploadCloudChanges =>
      phase == SubscriptionLifecyclePhase.activePremium;

  Duration get localHistoryRetention => hasPremiumRetention
      ? const Duration(days: ProofMediaFairUsePolicy.cloudRetentionDays)
      : ProofMediaFairUsePolicy.localRetentionDuration;

  String get label {
    switch (phase) {
      case SubscriptionLifecyclePhase.free:
        return 'Free';
      case SubscriptionLifecyclePhase.activePremium:
        return 'Personal Premium';
      case SubscriptionLifecyclePhase.expiredGrace:
        return 'Premium grace';
      case SubscriptionLifecyclePhase.expired:
        return 'Expired';
    }
  }
}

SubscriptionLifecycle subscriptionLifecycleForAccount(
  SubscriptionAccountState account, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final isPaidTier =
      account.entitlementTier == UserTier.personalPremium ||
      account.entitlementTier == UserTier.pebbleHousehold;

  if (account.entitlementStatus == EntitlementStatus.expired) {
    final expiredAt = account.lastEntitlementCheckAt ?? clock;
    final graceEndsAt = expiredAt.add(SubscriptionLifecycle.graceDuration);
    return SubscriptionLifecycle(
      phase: clock.isBefore(graceEndsAt)
          ? SubscriptionLifecyclePhase.expiredGrace
          : SubscriptionLifecyclePhase.expired,
      expiredAt: expiredAt,
      graceEndsAt: graceEndsAt,
    );
  }

  if (isPaidTier &&
      (account.entitlementStatus == EntitlementStatus.personalPremium ||
          account.entitlementStatus == EntitlementStatus.household)) {
    return const SubscriptionLifecycle(
      phase: SubscriptionLifecyclePhase.activePremium,
      expiredAt: null,
      graceEndsAt: null,
    );
  }

  return const SubscriptionLifecycle(
    phase: SubscriptionLifecyclePhase.free,
    expiredAt: null,
    graceEndsAt: null,
  );
}
