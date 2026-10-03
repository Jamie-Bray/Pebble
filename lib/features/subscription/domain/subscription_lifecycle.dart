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
    this.lapseConfirmed = false,
  });

  /// How long a lapsed subscriber keeps Premium history (and their extra
  /// routines) on this phone. It is counted from the later of the period end
  /// and the moment this device confirmed the lapse, so a user who opens the
  /// app weeks after Premium ended still gets the full warning window before
  /// anything is removed.
  static const graceDuration = Duration(days: 7);

  final SubscriptionLifecyclePhase phase;
  final DateTime? expiredAt;
  final DateTime? graceEndsAt;

  /// True once the store or server confirmed the lapse. While false the end
  /// is only inferred from a cached period end, so nothing destructive may
  /// happen yet (the renewal may simply not have been seen).
  final bool lapseConfirmed;

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
        return 'Premium recently ended';
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
    final expiredAt =
        account.entitlementExpiredAt ?? account.lastEntitlementCheckAt ?? clock;
    final noticedAt = account.entitlementLapseNoticedAt;
    // Unconfirmed lapses stay in grace: the countdown only starts once the
    // store or server has said Premium really ended.
    final graceStart = noticedAt == null
        ? (clock.isAfter(expiredAt) ? clock : expiredAt)
        : (noticedAt.isAfter(expiredAt) ? noticedAt : expiredAt);
    final graceEndsAt = graceStart.add(SubscriptionLifecycle.graceDuration);
    return SubscriptionLifecycle(
      phase: clock.isBefore(graceEndsAt)
          ? SubscriptionLifecyclePhase.expiredGrace
          : SubscriptionLifecyclePhase.expired,
      expiredAt: expiredAt,
      graceEndsAt: graceEndsAt,
      lapseConfirmed: noticedAt != null,
    );
  }

  if (isPaidTier &&
      (account.entitlementStatus == EntitlementStatus.personalPremium ||
          account.entitlementStatus == EntitlementStatus.household ||
          account.entitlementStatus == EntitlementStatus.free)) {
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
