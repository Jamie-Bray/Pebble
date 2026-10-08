import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/providers/kept_routines_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

/// What the end of Premium means for this user's saved things, in one place,
/// so every screen tells the same story.
class PremiumLapseSummary {
  const PremiumLapseSummary({
    required this.isLapsed,
    required this.inGrace,
    required this.graceEndsAt,
    required this.olderHistoryRunCount,
    required this.routineCount,
    required this.lockedRoutineCount,
    required this.freeRoutineLimit,
    required this.isSignedIn,
  });

  static const none = PremiumLapseSummary(
    isLapsed: false,
    inGrace: false,
    graceEndsAt: null,
    olderHistoryRunCount: 0,
    routineCount: 0,
    lockedRoutineCount: 0,
    freeRoutineLimit: 2,
    isSignedIn: false,
  );

  /// Premium ended on this phone (grace or after).
  final bool isLapsed;

  /// Premium history and routines are still kept, until [graceEndsAt].
  final bool inGrace;
  final DateTime? graceEndsAt;

  /// Completed routines older than the 48-hour Free window. During grace
  /// these are hidden (not deleted) when grace ends.
  final int olderHistoryRunCount;

  final int routineCount;

  /// Routines locked now (after grace) or that will lock when grace ends.
  final int lockedRoutineCount;
  final int freeRoutineLimit;
  final bool isSignedIn;

  bool get hasMoreRoutinesThanFree => routineCount > freeRoutineLimit;

  bool get hasHistoryAtRisk => inGrace && olderHistoryRunCount > 0;

  /// Worth interrupting Home for: something will change on a date, or
  /// routines are locked and the user may want to choose which stay.
  bool get needsAttention =>
      isLapsed &&
      (hasHistoryAtRisk ||
          (inGrace && hasMoreRoutinesThanFree) ||
          lockedRoutineCount > 0);

  String get graceEndDateLabel {
    final endsAt = graceEndsAt;
    if (endsAt == null) return '';
    return DateFormat('d MMMM').format(endsAt.toLocal());
  }
}

PremiumLapseSummary buildPremiumLapseSummary({
  required SubscriptionLifecycle lifecycle,
  required List<Routine> routines,
  required List<RoutineRun> runs,
  required RoutineLimitPolicy policy,
  required Set<int> keptRoutineIds,
  required bool isSignedIn,
  DateTime? now,
}) {
  final isLapsed =
      lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace ||
      lifecycle.phase == SubscriptionLifecyclePhase.expired;
  if (!isLapsed) return PremiumLapseSummary.none;
  final inGrace = lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace;
  final cutoff = (now ?? DateTime.now()).subtract(
    ProofMediaFairUsePolicy.localRetentionDuration,
  );
  final olderRuns = runs.where((run) => !run.finishedAt.isAfter(cutoff)).length;
  final lockedCount = routines.length <= policy.freeRoutineLimit
      ? 0
      : routines.length -
            unlockedRoutineIds(
              routines: routines,
              limit: policy.freeRoutineLimit,
              keptRoutineIds: keptRoutineIds,
            ).length;
  return PremiumLapseSummary(
    isLapsed: true,
    inGrace: inGrace,
    graceEndsAt: inGrace ? lifecycle.graceEndsAt : null,
    olderHistoryRunCount: olderRuns,
    routineCount: routines.length,
    lockedRoutineCount: lockedCount,
    freeRoutineLimit: policy.freeRoutineLimit,
    isSignedIn: isSignedIn,
  );
}

final premiumLapseSummaryProvider = Provider<PremiumLapseSummary>((ref) {
  final lifecycle = ref.watch(subscriptionLifecycleProvider);
  if (lifecycle.phase != SubscriptionLifecyclePhase.expiredGrace &&
      lifecycle.phase != SubscriptionLifecyclePhase.expired) {
    return PremiumLapseSummary.none;
  }
  return buildPremiumLapseSummary(
    lifecycle: lifecycle,
    routines: ref.watch(routineListProvider).valueOrNull ?? const [],
    runs: ref.watch(storedRoutineRunsProvider).valueOrNull ?? const [],
    policy: ref.watch(routineLimitPolicyProvider),
    keptRoutineIds: ref.watch(keptRoutinesProvider),
    isSignedIn: ref.watch(authSessionProvider).isSignedIn,
  );
});
