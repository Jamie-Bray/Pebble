import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

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
        ),
        now: expiredAt.add(const Duration(days: 8)),
      );

      expect(lifecycle.phase, SubscriptionLifecyclePhase.expired);
      expect(lifecycle.canUploadCloudChanges, isFalse);
      expect(lifecycle.hasPremiumRetention, isFalse);
      expect(lifecycle.localHistoryRetention, const Duration(hours: 48));
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

      await controller.applyStoreEntitlement(UserTier.personalPremium);

      expect(controller.state.entitlementTier, UserTier.personalPremium);
      expect(
        controller.state.entitlementStatus,
        EntitlementStatus.personalPremium,
      );
      expect(controller.state.entitlementSource, EntitlementSource.googlePlay);
    },
  );
}
