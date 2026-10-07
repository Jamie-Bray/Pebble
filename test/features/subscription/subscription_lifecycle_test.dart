import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('subscriptionLifecycleForAccount', () {
    test('active Premium can upload and uses 21-day retention', () {
      final lifecycle = subscriptionLifecycleForAccount(
        const SubscriptionAccountState.initial().copyWith(
          entitlementTier: UserTier.personalPremium,
          entitlementStatus: EntitlementStatus.personalPremium,
        ),
      );

      expect(lifecycle.phase, SubscriptionLifecyclePhase.activePremium);
      expect(lifecycle.canUploadCloudChanges, isTrue);
      expect(lifecycle.hasPremiumRetention, isTrue);
      expect(lifecycle.localHistoryRetention, const Duration(days: 21));
    });

    test('expired within grace pauses upload but keeps Premium retention', () {
      final expiredAt = DateTime.utc(2026, 5, 1);
      final lifecycle = subscriptionLifecycleForAccount(
        const SubscriptionAccountState.initial().copyWith(
          entitlementStatus: EntitlementStatus.expired,
          lastEntitlementCheckAt: expiredAt,
        ),
        now: expiredAt.add(const Duration(days: 3)),
      );

      expect(lifecycle.phase, SubscriptionLifecyclePhase.expiredGrace);
      expect(lifecycle.canUploadCloudChanges, isFalse);
      expect(lifecycle.hasPremiumRetention, isTrue);
      expect(lifecycle.localHistoryRetention, const Duration(days: 21));
    });

    test('expired after grace reverts to free retention', () {
      final expiredAt = DateTime.utc(2026, 5, 1);
      final lifecycle = subscriptionLifecycleForAccount(
        const SubscriptionAccountState.initial().copyWith(
          entitlementStatus: EntitlementStatus.expired,
          lastEntitlementCheckAt: expiredAt,
          entitlementLapseNoticedAt: expiredAt,
        ),
        now: expiredAt.add(const Duration(days: 8)),
      );

      expect(lifecycle.phase, SubscriptionLifecyclePhase.expired);
      expect(lifecycle.canUploadCloudChanges, isFalse);
      expect(lifecycle.hasPremiumRetention, isFalse);
      expect(lifecycle.localHistoryRetention, const Duration(hours: 48));
    });

    test('grace countdown is anchored to expiry, not the latest check', () {
      final expiredAt = DateTime.utc(2026, 5, 1);
      final lifecycle = subscriptionLifecycleForAccount(
        const SubscriptionAccountState.initial().copyWith(
          entitlementStatus: EntitlementStatus.expired,
          entitlementExpiredAt: expiredAt,
          entitlementLapseNoticedAt: expiredAt,
          // A fresh entitlement check days later must not restart grace.
          lastEntitlementCheckAt: expiredAt.add(const Duration(days: 5)),
        ),
        now: expiredAt.add(const Duration(days: 5)),
      );

      expect(lifecycle.phase, SubscriptionLifecyclePhase.expiredGrace);
      expect(
        lifecycle.graceEndsAt,
        expiredAt.add(SubscriptionLifecycle.graceDuration),
      );
    });
  });

  test(
    'verified personal_premium purchase unlocks Premium entitlement',
    () async {
      final database = LocalDb.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final controller = SubscriptionAccountController(
        database,
        loadOnInit: false,
      );

      expect(PebbleProductIds.personalPremium, 'personal_premium');

      await controller.applyRevenueCatEntitlement(UserTier.personalPremium);

      expect(controller.state.entitlementTier, UserTier.personalPremium);
      expect(
        controller.state.entitlementStatus,
        EntitlementStatus.personalPremium,
      );
      expect(controller.state.entitlementSource, EntitlementSource.revenueCat);
    },
  );

  test(
    'store verified entitlement expires from persisted period end',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final database = LocalDb.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final writer = SubscriptionAccountController(
        database,
        prefs: prefs,
        loadOnInit: false,
      );
      await writer.applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final reader = SubscriptionAccountController(database, prefs: prefs);
      await Future<void>.delayed(Duration.zero);

      expect(reader.state.entitlementTier, UserTier.personalFree);
      expect(reader.state.entitlementStatus, EntitlementStatus.expired);
      expect(reader.state.entitlementPeriodEndsAt, isNull);
    },
  );

  test(
    'repeated expiry checks keep the original expiry anchor for grace',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final database = LocalDb.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final periodEndsAt = DateTime.now().subtract(const Duration(days: 2));
      final controller = SubscriptionAccountController(
        database,
        prefs: prefs,
        loadOnInit: false,
      );
      await controller.applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: periodEndsAt,
      );

      // First expiry detection anchors to the real period end.
      await controller.applyExpiredStoreEntitlement();
      final firstAnchor = controller.state.entitlementExpiredAt;
      expect(firstAnchor, periodEndsAt);

      // A later re-check must not move the anchor forward.
      await controller.applyExpiredStoreEntitlement();
      expect(controller.state.entitlementExpiredAt, firstAnchor);

      // The anchor survives a restart via persisted metadata.
      final reader = SubscriptionAccountController(database, prefs: prefs);
      await Future<void>.delayed(Duration.zero);
      expect(reader.state.entitlementExpiredAt, firstAnchor);

      // Renewing Premium clears the stale anchor.
      await controller.applyRevenueCatEntitlement(UserTier.personalPremium);
      expect(controller.state.entitlementExpiredAt, isNull);
    },
  );

  test('signing out keeps local Premium entitlement', () async {
    final database = LocalDb.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final controller = SubscriptionAccountController(
      database,
      loadOnInit: false,
    );

    await controller.applyRevenueCatEntitlement(
      UserTier.personalPremium,
      periodEndsAt: DateTime.utc(2026, 6),
    );
    await controller.cacheAuthenticatedIdentity(
      userId: 'user-1',
      email: 'jamie@example.com',
      authProvider: 'google',
    );

    await controller.signOutIdentity();

    expect(controller.state.entitlementTier, UserTier.personalPremium);
    expect(
      controller.state.entitlementStatus,
      EntitlementStatus.personalPremium,
    );
    expect(controller.state.entitlementSource, EntitlementSource.revenueCat);
    expect(controller.state.userId, isNull);
    expect(controller.state.email, isNull);
  });

  test('expired server row does not override active store entitlement', () {
    final checkedAt = DateTime.utc(2026, 6, 1, 12);
    final account = const SubscriptionAccountState.initial().copyWith(
      entitlementTier: UserTier.personalPremium,
      entitlementStatus: EntitlementStatus.personalPremium,
      entitlementSource: EntitlementSource.revenueCat,
      entitlementPeriodEndsAt: DateTime.utc(2026, 7),
      lastEntitlementCheckAt: checkedAt,
    );

    expect(
      shouldApplyServerExpiredEntitlement(
        account,
        checkedAt: checkedAt.add(const Duration(minutes: 1)),
        now: checkedAt,
      ),
      isFalse,
    );
  });

  test('new expired server row can expire stale server entitlement', () {
    final checkedAt = DateTime.utc(2026, 6, 1, 12);
    final account = const SubscriptionAccountState.initial().copyWith(
      entitlementTier: UserTier.personalPremium,
      entitlementStatus: EntitlementStatus.personalPremium,
      entitlementSource: EntitlementSource.serverVerified,
      entitlementPeriodEndsAt: DateTime.utc(2026, 7),
      lastEntitlementCheckAt: checkedAt,
    );

    expect(
      shouldApplyServerExpiredEntitlement(
        account,
        checkedAt: checkedAt.add(const Duration(minutes: 1)),
        now: checkedAt,
      ),
      isTrue,
    );
  });

  group('lapse confirmation (state machine)', () {
    final periodEnd = DateTime.utc(2026, 5, 1);

    SubscriptionAccountState expired({DateTime? noticedAt}) =>
        const SubscriptionAccountState.initial().copyWith(
          entitlementStatus: EntitlementStatus.expired,
          entitlementExpiredAt: periodEnd,
          entitlementLapseNoticedAt: noticedAt,
        );

    test('an inferred lapse stays in grace however long ago the period '
        'ended, and keeps Premium history', () {
      final lifecycle = subscriptionLifecycleForAccount(
        expired(),
        now: periodEnd.add(const Duration(days: 40)),
      );
      expect(lifecycle.phase, SubscriptionLifecyclePhase.expiredGrace);
      expect(lifecycle.lapseConfirmed, isFalse);
      expect(lifecycle.localHistoryRetention, const Duration(days: 21));
      expect(lifecycle.canUploadCloudChanges, isFalse);
    });

    test('grace runs 7 days from confirmation when the app learns late', () {
      final noticedAt = periodEnd.add(const Duration(days: 30));
      final account = expired(noticedAt: noticedAt);
      final during = subscriptionLifecycleForAccount(
        account,
        now: noticedAt.add(const Duration(days: 6)),
      );
      expect(during.phase, SubscriptionLifecyclePhase.expiredGrace);
      expect(during.lapseConfirmed, isTrue);
      expect(during.graceEndsAt, noticedAt.add(const Duration(days: 7)));

      final after = subscriptionLifecycleForAccount(
        account,
        now: noticedAt.add(const Duration(days: 7, minutes: 1)),
      );
      expect(after.phase, SubscriptionLifecyclePhase.expired);
      expect(after.localHistoryRetention, const Duration(hours: 48));
    });

    test('confirmation before the period end still counts from the end', () {
      final lifecycle = subscriptionLifecycleForAccount(
        expired(noticedAt: periodEnd.subtract(const Duration(days: 2))),
        now: periodEnd.add(const Duration(days: 6)),
      );
      expect(lifecycle.phase, SubscriptionLifecyclePhase.expiredGrace);
      expect(lifecycle.graceEndsAt, periodEnd.add(const Duration(days: 7)));
    });

    test('free users who never paid are simply free', () {
      final lifecycle = subscriptionLifecycleForAccount(
        const SubscriptionAccountState.initial(),
      );
      expect(lifecycle.phase, SubscriptionLifecyclePhase.free);
      expect(lifecycle.localHistoryRetention, const Duration(hours: 48));
    });
  });

  group('SubscriptionAccountController lapse and renewal bookkeeping', () {
    late LocalDb database;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      database = LocalDb.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    SubscriptionAccountController controller({bool load = false}) =>
        SubscriptionAccountController(database, prefs: prefs, loadOnInit: load);

    test('a period end found at start-up is not a confirmed lapse', () async {
      await controller().applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().subtract(const Duration(days: 20)),
      );

      final reader = controller(load: true);
      await reader.whenLoaded;

      expect(reader.state.entitlementStatus, EntitlementStatus.expired);
      expect(reader.state.entitlementLapseNoticedAt, isNull);
    });

    test('the store confirming no Premium starts the countdown once', () async {
      final writer = controller();
      await writer.applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().subtract(const Duration(days: 20)),
      );
      final reader = controller(load: true);
      await reader.whenLoaded;

      await reader.confirmLapseIfExpired();
      final firstNotice = reader.state.entitlementLapseNoticedAt;
      expect(firstNotice, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await reader.confirmLapseIfExpired();
      expect(reader.state.entitlementLapseNoticedAt, firstNotice);

      final relaunched = controller(load: true);
      await relaunched.whenLoaded;
      expect(relaunched.state.entitlementLapseNoticedAt, firstNotice);
    });

    test('confirming is a no-op for active and never-paid plans', () async {
      final free = controller();
      await free.confirmLapseIfExpired();
      expect(free.state.entitlementLapseNoticedAt, isNull);

      final active = controller();
      await active.applyRevenueCatEntitlement(UserTier.personalPremium);
      await active.confirmLapseIfExpired();
      expect(active.state.entitlementLapseNoticedAt, isNull);
    });

    test('a store expiry confirms the lapse; renewing clears it', () async {
      final account = controller();
      await account.applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().subtract(const Duration(hours: 1)),
        willRenew: false,
      );
      await account.applyExpiredStoreEntitlement();
      expect(account.state.entitlementLapseNoticedAt, isNotNull);
      expect(account.state.entitlementWillRenew, isNull);

      await account.applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().add(const Duration(days: 30)),
        willRenew: true,
      );
      expect(account.state.entitlementLapseNoticedAt, isNull);
      expect(account.state.entitlementExpiredAt, isNull);
      expect(
        subscriptionLifecycleForAccount(account.state).phase,
        SubscriptionLifecyclePhase.activePremium,
      );
    });

    test('renewal and billing details survive a restart', () async {
      final billingIssueAt = DateTime.utc(2026, 9, 30, 8);
      await controller().applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().add(const Duration(days: 3)),
        willRenew: true,
        billingIssueAt: billingIssueAt,
      );

      final reader = controller(load: true);
      await reader.whenLoaded;
      expect(reader.state.entitlementWillRenew, isTrue);
      expect(reader.state.entitlementBillingIssueAt, billingIssueAt);

      // A later check without a billing problem clears it.
      await reader.applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().add(const Duration(days: 30)),
        willRenew: false,
      );
      expect(reader.state.entitlementBillingIssueAt, isNull);
      expect(reader.state.entitlementWillRenew, isFalse);
    });

    test('whenLoaded completes only after the stored plan is read', () async {
      await controller().applyRevenueCatEntitlement(
        UserTier.personalPremium,
        periodEndsAt: DateTime.now().add(const Duration(days: 10)),
      );
      final reader = controller(load: true);
      // Before loading, the state is the Free default.
      expect(reader.state.entitlementTier, UserTier.personalFree);
      await reader.whenLoaded;
      expect(reader.state.entitlementTier, UserTier.personalPremium);
    });
  });
}
