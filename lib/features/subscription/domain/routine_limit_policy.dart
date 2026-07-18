import 'dart:convert';
import 'dart:math' as math;

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';

class RoutineLimitPolicy {
  const RoutineLimitPolicy({
    required this.hasPremiumRoutineAccess,
    required this.isInGrace,
    this.freeRoutineLimit = 2,
    this.freeStepLimit = 10,
  });

  factory RoutineLimitPolicy.fromPremiumPolicy(PremiumFeaturePolicy policy) {
    return RoutineLimitPolicy(
      hasPremiumRoutineAccess: policy.canUseUnlimitedRoutines,
      isInGrace: policy.localPremiumAccess == LocalPremiumAccess.historyGrace,
    );
  }

  final bool hasPremiumRoutineAccess;
  final bool isInGrace;
  final int freeRoutineLimit;
  final int freeStepLimit;

  bool get shouldSoftLockFreeLimits => !hasPremiumRoutineAccess && !isInGrace;

  bool isRoutineRestricted(int index) {
    return shouldSoftLockFreeLimits && index >= freeRoutineLimit;
  }

  bool isStepRestricted(int index) {
    return shouldSoftLockFreeLimits && index >= freeStepLimit;
  }

  int lockedStepCount(int stepCount) {
    if (!shouldSoftLockFreeLimits) return 0;
    return math.max(0, stepCount - freeStepLimit);
  }

  // Value equality so providers that recompute an identical policy (e.g. the
  // silent purchase sync on every app resume) do not notify watchers. The
  // routine player provider watches this policy; without equality, each
  // resume rebuilt the player controller mid-session and could race an
  // in-flight photo save.
  @override
  bool operator ==(Object other) {
    return other is RoutineLimitPolicy &&
        other.hasPremiumRoutineAccess == hasPremiumRoutineAccess &&
        other.isInGrace == isInGrace &&
        other.freeRoutineLimit == freeRoutineLimit &&
        other.freeStepLimit == freeStepLimit;
  }

  @override
  int get hashCode => Object.hash(
    hasPremiumRoutineAccess,
    isInGrace,
    freeRoutineLimit,
    freeStepLimit,
  );
}

class RoutineAccessState {
  const RoutineAccessState({
    required this.routine,
    required this.index,
    required this.stepCount,
    required this.isRestricted,
    required this.lockedStepCount,
  });

  final Routine routine;
  final int index;
  final int stepCount;
  final bool isRestricted;
  final int lockedStepCount;

  bool get hasLockedSteps => lockedStepCount > 0;
}

List<RoutineAccessState> buildRoutineAccessStates({
  required List<Routine> routines,
  required RoutineLimitPolicy policy,
}) {
  return List.generate(routines.length, (index) {
    final routine = routines[index];
    final stepCount = routineStepCount(routine);
    return RoutineAccessState(
      routine: routine,
      index: index,
      stepCount: stepCount,
      isRestricted: policy.isRoutineRestricted(index),
      lockedStepCount: policy.lockedStepCount(stepCount),
    );
  });
}

bool isFreeTierFootprint({
  required List<Routine> routines,
  required RoutineLimitPolicy policy,
}) {
  if (routines.length > policy.freeRoutineLimit) {
    return false;
  }
  for (final routine in routines) {
    if (routineStepCount(routine) > policy.freeStepLimit) {
      return false;
    }
  }
  return true;
}

int routineStepCount(Routine routine) {
  try {
    if (routine.stepsJson.isEmpty) return 0;
    final decoded = jsonDecode(routine.stepsJson);
    return decoded is List ? decoded.length : 0;
  } catch (_) {
    return 0;
  }
}
