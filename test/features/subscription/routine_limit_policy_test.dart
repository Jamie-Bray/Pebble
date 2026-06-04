import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';

void main() {
  group('RoutineLimitPolicy', () {
    const lockedPolicy = RoutineLimitPolicy(
      hasPremiumRoutineAccess: false,
      isInGrace: false,
    );
    const gracePolicy = RoutineLimitPolicy(
      hasPremiumRoutineAccess: false,
      isInGrace: true,
    );

    test('keeps routines visible but marks items beyond the free limit', () {
      expect(lockedPolicy.isRoutineRestricted(0), isFalse);
      expect(lockedPolicy.isRoutineRestricted(1), isFalse);
      expect(lockedPolicy.isRoutineRestricted(2), isTrue);
    });

    test('keeps the grace period unlocked until it expires', () {
      expect(gracePolicy.isRoutineRestricted(2), isFalse);
      expect(gracePolicy.isStepRestricted(10), isFalse);
    });

    test('marks steps from index 10 onward as restricted', () {
      expect(lockedPolicy.isStepRestricted(9), isFalse);
      expect(lockedPolicy.isStepRestricted(10), isTrue);
      expect(lockedPolicy.lockedStepCount(14), 4);
    });

    test('detects when routine risk card can be hidden', () {
      expect(
        isFreeTierFootprint(
          routines: [
            _routine(id: 1, stepCount: 10),
            _routine(id: 2, stepCount: 4),
          ],
          policy: lockedPolicy,
        ),
        isTrue,
      );

      expect(
        isFreeTierFootprint(
          routines: [_routine(id: 1, stepCount: 11)],
          policy: lockedPolicy,
        ),
        isFalse,
      );
    });
  });
}

Routine _routine({required int id, required int stepCount}) {
  final now = DateTime.utc(2026, 6, 1);
  return Routine(
    id: id,
    title: 'Routine $id',
    stepsJson: jsonEncode([
      for (var index = 0; index < stepCount; index++)
        RoutineStep.check(label: 'Step ${index + 1}').toJson(),
    ]),
    createdAt: now.subtract(Duration(minutes: id)),
    emoji: null,
    colorHex: null,
    isPinned: false,
    pinnedAt: null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: now,
    cloudId: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}
