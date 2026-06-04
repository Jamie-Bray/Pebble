import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

void main() {
  group('PremiumFeaturePolicy', () {
    test('free signed out has no premium or server access', () {
      final harness = _harness(
        auth: _signedOut,
        account: const SubscriptionAccountState.initial(),
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(policy.localPremiumAccess, LocalPremiumAccess.free);
      expect(policy.canUseUnlimitedRoutines, isFalse);
      expect(policy.hasPremiumHistoryRetention, isFalse);
      expect(policy.canUseSharedAlerts, isFalse);
      expect(policy.needsSignInForServerFeatures, isFalse);
    });

    test('active RevenueCat premium signed out keeps local premium', () {
      final harness = _harness(
        auth: _signedOut,
        account: _premiumAccount(source: EntitlementSource.revenueCat),
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(policy.localPremiumAccess, LocalPremiumAccess.active);
      expect(policy.canUseUnlimitedRoutines, isTrue);
      expect(policy.canUsePremiumThemes, isTrue);
      expect(policy.canUseSharedAlerts, isFalse);
      expect(policy.needsSignInForServerFeatures, isTrue);
      expect(policy.serverFeatureStatus, ServerFeatureStatus.signedOut);
    });

    test('active premium signed in waits for Supabase server mirror', () {
      final harness = _harness(
        auth: _signedIn,
        account: _premiumAccount(source: EntitlementSource.revenueCat),
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(policy.localPremiumAccess, LocalPremiumAccess.active);
      expect(policy.serverFeatureStatus, ServerFeatureStatus.verifying);
      expect(policy.canUseSharedAlerts, isFalse);
      expect(policy.canUseCloudBackup, isFalse);
    });

    test('active premium signed in exposes retryable mirror failure', () {
      final harness = _harness(
        auth: _signedIn,
        account: _premiumAccount(source: EntitlementSource.revenueCat).copyWith(
          entitlementError:
              'Premium is active, but backup could not be set up yet. Try again.',
        ),
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(policy.localPremiumAccess, LocalPremiumAccess.active);
      expect(
        policy.serverFeatureStatus,
        ServerFeatureStatus.verificationFailed,
      );
      expect(policy.canUseUnlimitedRoutines, isTrue);
      expect(policy.canUseSharedAlerts, isFalse);
      expect(policy.canUseCloudBackup, isFalse);
      expect(policy.userFacingStatus, contains('backup could not be set up'));
    });

    test('server verified premium unlocks alerts before backup consent', () {
      final harness = _harness(
        auth: _signedIn,
        account: _premiumAccount(source: EntitlementSource.serverVerified),
        consent: const CloudBackupConsentState(
          isLoading: false,
          record: null,
          lastError: null,
          isRemoteConfirmed: false,
        ),
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(
        policy.serverFeatureStatus,
        ServerFeatureStatus.needsBackupConsent,
      );
      expect(policy.hasServerVerifiedPremium, isTrue);
      expect(policy.canUseSharedAlerts, isTrue);
      expect(policy.canUseCloudBackup, isFalse);
    });

    test('server verified premium with consent unlocks cloud backup', () {
      final harness = _harness(
        auth: _signedIn,
        account: _premiumAccount(source: EntitlementSource.serverVerified),
        consent: _acceptedConsent,
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(policy.serverFeatureStatus, ServerFeatureStatus.ready);
      expect(policy.canUseSharedAlerts, isTrue);
      expect(policy.canUseCloudBackup, isTrue);
    });

    test('expired grace keeps history only', () {
      final harness = _harness(
        auth: _signedIn,
        account: const SubscriptionAccountState.initial().copyWith(
          entitlementStatus: EntitlementStatus.expired,
          lastEntitlementCheckAt: DateTime.now().subtract(
            const Duration(days: 3),
          ),
        ),
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(policy.localPremiumAccess, LocalPremiumAccess.historyGrace);
      expect(policy.hasPremiumHistoryRetention, isTrue);
      expect(policy.canUseUnlimitedRoutines, isFalse);
      expect(policy.canUsePremiumThemes, isFalse);
    });

    test('expired after grace returns to free behavior', () {
      final harness = _harness(
        auth: _signedIn,
        account: const SubscriptionAccountState.initial().copyWith(
          entitlementStatus: EntitlementStatus.expired,
          lastEntitlementCheckAt: DateTime.now().subtract(
            const Duration(days: 8),
          ),
        ),
      );
      addTearDown(harness.dispose);

      final policy = harness.container.read(premiumFeaturePolicyProvider);

      expect(policy.localPremiumAccess, LocalPremiumAccess.expired);
      expect(policy.hasPremiumHistoryRetention, isFalse);
      expect(policy.canUseUnlimitedRoutines, isFalse);
    });
  });
}

const _signedOut = AuthSessionSummary(
  isSignedIn: false,
  userId: null,
  email: null,
  provider: null,
);

const _signedIn = AuthSessionSummary(
  isSignedIn: true,
  userId: '11111111-1111-4111-8111-111111111111',
  email: 'jamie@example.com',
  provider: 'emailOtp',
);

final _acceptedConsent = CloudBackupConsentState(
  isLoading: false,
  record: CloudBackupConsentRecord(
    userId: _signedIn.userId!,
    feature: cloudBackupConsentFeature,
    featureEnabled: true,
    appVersion: cloudBackupConsentAppVersion,
    privacyVersion: cloudBackupConsentPrivacyVersion,
    termsVersion: cloudBackupConsentTermsVersion,
    consentTextHash: cloudBackupConsentTextHash,
    consentedAt: DateTime.utc(2026, 5, 1),
    withdrawnAt: null,
  ),
  lastError: null,
  isRemoteConfirmed: true,
);

SubscriptionAccountState _premiumAccount({required EntitlementSource source}) {
  return SubscriptionAccountState(
    entitlementTier: UserTier.personalPremium,
    pendingTier: null,
    bootstrapStatus: BootstrapStatus.ready,
    userId: _signedIn.userId,
    email: _signedIn.email,
    authProvider: _signedIn.provider,
    lastBootstrapAt: null,
    lastSyncAt: null,
    lastSyncError: null,
    entitlementStatus: EntitlementStatus.personalPremium,
    entitlementSource: source,
    lastEntitlementCheckAt: DateTime.utc(2026, 5, 1),
    entitlementPeriodEndsAt: DateTime.utc(2026, 6, 1),
  );
}

_PolicyHarness _harness({
  required AuthSessionSummary auth,
  required SubscriptionAccountState account,
  CloudBackupConsentState consent = const CloudBackupConsentState(
    isLoading: false,
    record: null,
    lastError: null,
    isRemoteConfirmed: false,
  ),
}) {
  final database = LocalDb.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      localDbProvider.overrideWithValue(database),
      authSessionProvider.overrideWithValue(auth),
      subscriptionAccountControllerProvider.overrideWith(
        (ref) => _TestSubscriptionAccountController(database, account),
      ),
      purchaseRepositoryProvider.overrideWith(
        (ref) => _FakePurchaseRepository(),
      ),
      cloudBackupConsentStateProvider.overrideWithValue(consent),
    ],
  );
  return _PolicyHarness(container: container, database: database);
}

class _PolicyHarness {
  const _PolicyHarness({required this.container, required this.database});

  final ProviderContainer container;
  final LocalDb database;

  Future<void> dispose() async {
    container.dispose();
    await database.close();
  }
}

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(super.db, SubscriptionAccountState initial)
    : super(loadOnInit: false) {
    state = initial;
  }
}

class _FakePurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  @override
  bool get billingAvailable => true;

  @override
  bool get isPurchaseAvailable => true;

  @override
  DateTime? get lastPurchaseCheckAt => DateTime.utc(2026, 5, 1);

  @override
  Set<String> get loadedProductIds => {PebbleProductIds.personalPremium};

  @override
  String? get manageSubscriptionsUrl => null;

  @override
  List<PremiumProduct> get personalPremiumProducts =>
      getPlaceholderPremiumCatalog(isPurchasable: true);

  @override
  String? get unavailableReason => null;

  @override
  Future<void> logOut() async {}

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    return PurchaseResult(
      tier: UserTier.personalPremium,
      plan: plan,
      requiresSignIn: false,
      message: 'Purchased',
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return const PurchaseResult(
      tier: UserTier.personalPremium,
      plan: BillingPlan.monthly,
      requiresSignIn: false,
      message: 'Restored',
    );
  }

  @override
  Future<void> syncPurchasesSilently({
    bool waitForServerMirror = false,
  }) async {}
}
