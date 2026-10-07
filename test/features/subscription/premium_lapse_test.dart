import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/account_backup/providers/account_profile_presentation_provider.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/providers/kept_routines_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_lapse_provider.dart';
import 'package:pebble_routines/features/subscription/ui/premium_lapse_ui.dart';

void main() {
  final now = DateTime(2026, 10, 3, 12);
  const locked = RoutineLimitPolicy(
    hasPremiumRoutineAccess: false,
    isInGrace: false,
  );
  const grace = RoutineLimitPolicy(
    hasPremiumRoutineAccess: false,
    isInGrace: true,
  );
  final five = [for (var id = 1; id <= 5; id++) _routine(id)];
  final runs = [
    _run('recent', now.subtract(const Duration(hours: 5))),
    _run('older-1', now.subtract(const Duration(days: 3))),
    _run('older-2', now.subtract(const Duration(days: 10))),
  ];

  group('buildPremiumLapseSummary', () {
    test('active Premium has nothing to say', () {
      final summary = buildPremiumLapseSummary(
        lifecycle: const SubscriptionLifecycle(
          phase: SubscriptionLifecyclePhase.activePremium,
          expiredAt: null,
          graceEndsAt: null,
        ),
        routines: five,
        runs: runs,
        policy: locked,
        keptRoutineIds: const {},
        isSignedIn: true,
        now: now,
      );
      expect(summary.isLapsed, isFalse);
      expect(summary.needsAttention, isFalse);
    });

    test('grace warns about older history with the removal date', () {
      final summary = buildPremiumLapseSummary(
        lifecycle: SubscriptionLifecycle(
          phase: SubscriptionLifecyclePhase.expiredGrace,
          expiredAt: now.subtract(const Duration(days: 2)),
          graceEndsAt: DateTime(2026, 10, 8, 12),
          lapseConfirmed: true,
        ),
        routines: five,
        runs: runs,
        policy: grace,
        keptRoutineIds: const {},
        isSignedIn: false,
        now: now,
      );
      expect(summary.inGrace, isTrue);
      expect(summary.olderHistoryRunCount, 2);
      expect(summary.hasHistoryAtRisk, isTrue);
      // In grace nothing is locked yet, but 3 routines will lock.
      expect(summary.lockedRoutineCount, 3);
      expect(summary.needsAttention, isTrue);
      expect(
        premiumLapseHeadline(summary),
        '2 completed routines older than 48 hours will be removed from this '
        'phone on 8 October. Renew to keep them.',
      );
    });

    test('after grace, locked routines are counted using the kept choice', () {
      final summary = buildPremiumLapseSummary(
        lifecycle: SubscriptionLifecycle(
          phase: SubscriptionLifecyclePhase.expired,
          expiredAt: now.subtract(const Duration(days: 20)),
          graceEndsAt: now.subtract(const Duration(days: 13)),
          lapseConfirmed: true,
        ),
        routines: five,
        runs: const [],
        policy: locked,
        keptRoutineIds: const {4, 5},
        isSignedIn: true,
        now: now,
      );
      expect(summary.inGrace, isFalse);
      expect(summary.lockedRoutineCount, 3);
      expect(
        premiumLapseHeadline(summary),
        '3 routines are locked but still saved. Choose which 2 to keep, or '
        'renew.',
      );
    });

    test('a lapsed user within Free limits is not interrupted', () {
      final summary = buildPremiumLapseSummary(
        lifecycle: SubscriptionLifecycle(
          phase: SubscriptionLifecyclePhase.expired,
          expiredAt: now.subtract(const Duration(days: 20)),
          graceEndsAt: now.subtract(const Duration(days: 13)),
          lapseConfirmed: true,
        ),
        routines: five.take(2).toList(),
        runs: const [],
        policy: locked,
        keptRoutineIds: const {},
        isSignedIn: false,
        now: now,
      );
      expect(summary.isLapsed, isTrue);
      expect(summary.needsAttention, isFalse);
    });
  });

  group('accountPlanPeriodLine', () {
    final endsAt = DateTime(2027, 3, 12, 9);
    const base = SubscriptionAccountState.initial();

    test('renewing plans say when they renew', () {
      expect(
        accountPlanPeriodLine(
          base.copyWith(
            entitlementPeriodEndsAt: endsAt,
            entitlementWillRenew: true,
          ),
        ),
        'Renews on 12 March 2027. Cancel anytime in your store account.',
      );
    });

    test('cancelled plans say Premium stays on until the period end', () {
      expect(
        accountPlanPeriodLine(
          base.copyWith(
            entitlementPeriodEndsAt: endsAt,
            entitlementWillRenew: false,
          ),
        ),
        'Cancelled. Premium stays on until 12 March 2027, then Free limits '
        'apply.',
      );
    });

    test('a billing problem asks for a payment fix', () {
      expect(
        accountPlanPeriodLine(
          base.copyWith(
            entitlementPeriodEndsAt: endsAt,
            entitlementWillRenew: true,
            entitlementBillingIssueAt: DateTime(2027, 3, 12),
          ),
        ),
        contains('Update your payment method'),
      );
    });
  });

  group('KeepRoutinesSheet', () {
    testWidgets('choosing two routines saves them and locks the rest', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routineListProvider.overrideWith((ref) => Stream.value(five)),
          routineLimitPolicyProvider.overrideWithValue(locked),
        ],
      );
      addTearDown(container.dispose);
      await container.read(routineListProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showKeepRoutinesSheet(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Choose 2 routines to keep'), findsOneWidget);
      expect(find.text('2 of 2 chosen. Uncheck one to swap.'), findsOneWidget);

      // Untick the defaults, tick routines 4 and 5.
      await tester.tap(find.text('Routine 1'));
      await tester.tap(find.text('Routine 2'));
      await tester.pump();
      expect(find.text('0 of 2 chosen'), findsOneWidget);
      await tester.tap(find.text('Routine 4'));
      await tester.tap(find.text('Routine 5'));
      await tester.pump();

      // A third choice is not possible while two are chosen.
      final third = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('keep-routine-3')),
      );
      expect(third.onChanged, isNull);

      await tester.tap(find.text('Save choice'));
      await tester.pumpAndSettle();

      expect(container.read(keptRoutinesProvider), {4, 5});
      expect(container.read(restrictedRoutineIdsProvider), {1, 2, 3});
      expect(
        jsonDecode(prefs.getString(KeptRoutinesController.storageKey)!),
        unorderedEquals([4, 5]),
      );
    });

    testWidgets('a tapped locked routine is preselected', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routineListProvider.overrideWith((ref) => Stream.value(five)),
          routineLimitPolicyProvider.overrideWithValue(locked),
        ],
      );
      addTearDown(container.dispose);
      await container.read(routineListProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showKeepRoutinesSheet(context, preselect: 5),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      bool isTicked(int id) => tester
          .widget<CheckboxListTile>(find.byKey(ValueKey('keep-routine-$id')))
          .value!;
      expect(isTicked(5), isTrue);
      expect(isTicked(1), isTrue);
      expect(isTicked(2), isFalse);
    });
  });
}

Routine _routine(int id) {
  final created = DateTime.utc(2026, 6, 1).subtract(Duration(days: id));
  return Routine(
    id: id,
    title: 'Routine $id',
    stepsJson: jsonEncode([const RoutineStep.check(label: 'Step').toJson()]),
    createdAt: created,
    emoji: null,
    colorHex: null,
    isPinned: false,
    pinnedAt: null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: created,
    cloudId: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

RoutineRun _run(String id, DateTime finishedAt) {
  return RoutineRun(
    id: id,
    routineId: '1',
    routineTitle: 'Routine 1',
    finishedAt: finishedAt,
    stepCompletionData: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: finishedAt,
  );
}
