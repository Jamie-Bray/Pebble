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

    test(
      'recomputed identical policies are equal, so providers stay quiet',
      () {
        // The routine player provider watches this policy. Without value
        // equality, the silent purchase sync on every app resume produced a
        // new instance, rebuilt the player controller mid-session, and lost
        // in-flight photo attaches.
        expect(
          lockedPolicy,
          const RoutineLimitPolicy(
            hasPremiumRoutineAccess: false,
            isInGrace: false,
          ),
        );
        expect(lockedPolicy, isNot(gracePolicy));
      },
    );

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

  group('choosing which routines stay unlocked', () {
    const lockedPolicy = RoutineLimitPolicy(
      hasPremiumRoutineAccess: false,
      isInGrace: false,
    );
    final five = [
      for (var id = 1; id <= 5; id++) _routine(id: id, stepCount: 3),
    ];

    test('without a choice, the first two in list order stay unlocked', () {
      expect(restrictedRoutineIds(routines: five, policy: lockedPolicy), {
        3,
        4,
        5,
      });
    });

    test('kept routines stay unlocked wherever they are in the list', () {
      expect(
        restrictedRoutineIds(
          routines: five,
          policy: lockedPolicy,
          keptRoutineIds: {5, 3},
        ),
        {1, 2, 4},
      );
    });

    test('one kept routine is topped up from list order', () {
      expect(
        restrictedRoutineIds(
          routines: five,
          policy: lockedPolicy,
          keptRoutineIds: {4},
        ),
        {2, 3, 5},
      );
    });

    test('deleted or extra kept ids never unlock more than the limit', () {
      final restricted = restrictedRoutineIds(
        routines: five,
        policy: lockedPolicy,
        keptRoutineIds: {99, 5, 4, 3},
      );
      // Only existing kept routines count, in list order, up to the limit.
      expect(restricted, {1, 2, 5});
    });

    test('nothing is locked with Premium, in grace, or within the limit', () {
      const premium = RoutineLimitPolicy(
        hasPremiumRoutineAccess: true,
        isInGrace: false,
      );
      const grace = RoutineLimitPolicy(
        hasPremiumRoutineAccess: false,
        isInGrace: true,
      );
      expect(restrictedRoutineIds(routines: five, policy: premium), isEmpty);
      expect(restrictedRoutineIds(routines: five, policy: grace), isEmpty);
      expect(
        restrictedRoutineIds(
          routines: five.take(2).toList(),
          policy: lockedPolicy,
        ),
        isEmpty,
      );
    });

    test('access states follow the kept choice', () {
      final states = buildRoutineAccessStates(
        routines: five,
        policy: lockedPolicy,
        keptRoutineIds: {5, 4},
      );
      expect(
        [
          for (final state in states)
            if (!state.isRestricted) state.routine.id,
        ],
        [4, 5],
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
