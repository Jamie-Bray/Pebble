import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_reminder_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_status_mapper.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(
    super.db,
    SubscriptionAccountState initialState,
  ) : super(loadOnInit: false) {
    state = initialState;
  }
}

class _UiHarness {
  const _UiHarness({required this.container, required this.database});

  final ProviderContainer container;
  final LocalDb database;
}

class _FakeProofStorage implements RoutineSessionProofStorage {
  @override
  Future<void> enforceRetentionPolicy({required bool isPremium}) async {}

  @override
  Future<void> deleteSessionProofs(String sessionId) async {}

  @override
  Future<void> deleteStoredProof(String storedPath) async {}

  @override
  Future<void> deleteProofAsset(RoutineSessionProofAsset asset) async {}

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<File?> resolveStoredFile(String storedPath) async => null;

  @override
  Future<File?> resolveProofAssetFile(RoutineSessionProofAsset asset) async =>
      null;

  @override
  Future<String> resolveStoredPath(String storedPath) async => storedPath;

  @override
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  }) async {
    return asset;
  }
}

class _OfflineRoutineDataSource extends RemoteRoutineDataSource {
  _OfflineRoutineDataSource() : super(null);

  @override
  Future<void> upsert(Map<String, dynamic> payload) {
    throw const SocketException('offline');
  }
}

class _CapturingRoutineDataSource extends RemoteRoutineDataSource {
  _CapturingRoutineDataSource() : super(null);

  final List<Map<String, dynamic>> upserts = [];

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    upserts.add(Map<String, dynamic>.from(payload));
  }
}

class _CapturingReminderDataSource extends RemoteRoutineReminderDataSource {
  _CapturingReminderDataSource() : super(null);

  final List<Map<String, dynamic>> upserts = [];

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    upserts.add(Map<String, dynamic>.from(payload));
  }
}

class _CapturingRunDataSource extends RemoteRoutineRunDataSource {
  _CapturingRunDataSource() : super(null);

  final List<Map<String, dynamic>> upserts = [];

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    upserts.add(Map<String, dynamic>.from(payload));
  }
}

class _AccountTestPurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  @override
  bool get isPurchaseAvailable => true;

  @override
  bool get billingAvailable => true;

  @override
  DateTime? get lastPurchaseCheckAt => DateTime.utc(2026, 5, 26);

  @override
  Set<String> get loadedProductIds => {PebbleProductIds.personalPremium};

  @override
  String? get manageSubscriptionsUrl =>
      'https://play.google.com/store/account/subscriptions';

  @override
  List<PremiumProduct> get personalPremiumProducts =>
      getPlaceholderPremiumCatalog(isPurchasable: true);

  @override
  String? get unavailableReason => null;

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    return PurchaseResult(
      tier: UserTier.personalPremium,
      plan: plan,
      requiresSignIn: false,
      message: 'Welcome to Personal Premium.',
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return const PurchaseResult(
      tier: UserTier.personalPremium,
      plan: BillingPlan.monthly,
      requiresSignIn: false,
      message: 'Premium restored.',
    );
  }

  @override
  Future<void> syncPurchasesSilently({
    bool waitForServerMirror = false,
  }) async {}

  @override
  Future<void> logOut() async {}
}

class _UnavailableAccountTestPurchaseRepository
    extends _AccountTestPurchaseRepository {
  @override
  bool get isPurchaseAvailable => false;

  @override
  bool get billingAvailable => false;

  @override
  List<PremiumProduct> get personalPremiumProducts =>
      getPlaceholderPremiumCatalog(isPurchasable: false);

  @override
  String? get unavailableReason => 'Store is not ready yet.';
}

_UiHarness _buildUiContainer({
  required AuthSessionSummary auth,
  required EntitlementState entitlement,
  required PersonalCloudAccessState cloudAccess,
  required SubscriptionAccountState account,
  required int pendingCount,
  PurchaseRepository? purchaseRepository,
  CloudSyncRuntimeState runtime = const CloudSyncRuntimeState.idle(),
  ProofMediaFairUseState fairUseState = const ProofMediaFairUseState(
    activeCloudBytes: 0,
    storageLimitBytes: ProofMediaFairUsePolicy.storageLimitBytes,
    uploadsThisPeriod: 0,
    monthlyUploadLimit: ProofMediaFairUsePolicy.monthlyUploadLimit,
  ),
}) {
  final database = LocalDb.forTesting(NativeDatabase.memory());
  return _UiHarness(
    database: database,
    container: ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(database),
        authSessionProvider.overrideWithValue(auth),
        entitlementStateProvider.overrideWithValue(entitlement),
        personalCloudAccessProvider.overrideWithValue(cloudAccess),
        cloudBackupConsentStateProvider.overrideWithValue(
          const CloudBackupConsentState(
            isLoading: false,
            record: null,
            lastError: null,
            isRemoteConfirmed: false,
          ),
        ),
        subscriptionAccountControllerProvider.overrideWith(
          (ref) => _TestSubscriptionAccountController(database, account),
        ),
        syncOutboxCountProvider.overrideWith(
          (ref) => Stream.value(pendingCount),
        ),
        cloudSyncRuntimeStateProvider.overrideWith((ref) => runtime),
        proofMediaFairUseStateProvider.overrideWith(
          (ref) async => fairUseState,
        ),
        purchaseRepositoryProvider.overrideWith(
          (ref) => purchaseRepository ?? _AccountTestPurchaseRepository(),
        ),
      ],
    ),
  );
}

Routine _buildRoutine({String? ownerUserId}) {
  return Routine(
    id: 1,
    title: 'Close down',
    stepsJson: jsonEncode(const []),
    createdAt: DateTime(2026, 1, 1),
    emoji: null,
    colorHex: null,
    isPinned: false,
    pinnedAt: null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: DateTime(2026, 1, 1),
    cloudId: null,
    ownerUserId: ownerUserId,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

Future<void> _primeUiState(ProviderContainer container) async {
  await container.read(syncOutboxCountProvider.future);
  await container.read(proofMediaFairUseStateProvider.future);
}

List<String> _chipValues(AccountStatusPresentation presentation) {
  return presentation.limitChips.map((chip) => chip.value).toList();
}

void main() {
  group('Account & Backup derived state', () {
    test('free signed out stays quiet and local-only', () async {
      final harness = _buildUiContainer(
        auth: const AuthSessionSummary(
          isSignedIn: false,
          userId: null,
          email: null,
          provider: null,
        ),
        entitlement: const EntitlementState(
          personalTier: UserTier.personalFree,
          source: EntitlementSource.localCache,
          lastCheckedAt: null,
          isRefreshing: false,
          lastError: null,
        ),
        cloudAccess: const PersonalCloudAccessState(
          status: PersonalCloudAccessStatus.offFree,
          label: 'Cloud backup is off',
          detail: 'Local only.',
        ),
        account: const SubscriptionAccountState.initial(),
        pendingCount: 0,
      );
      addTearDown(() async {
        harness.container.dispose();
        await harness.database.close();
      });
      await _primeUiState(harness.container);

      final ring = harness.container.read(accountBackupRingStateProvider);
      final banner = harness.container.read(homeBackupBannerStateProvider);
      final ui = harness.container.read(accountBackupUiStateProvider);

      expect(ring.showRing, isFalse);
      expect(banner.show, isFalse);
      expect(
        ui.backupSummary,
        'Pebble works without an account. Your routines are stored on this device.',
      );
      expect(ui.accountActionLabel, 'Restore Premium');
      expect(ui.planActionLabel, 'Upgrade');
    });

    test('account card shows free plan facts without sign-in CTA', () async {
      final harness = _buildUiContainer(
        auth: const AuthSessionSummary(
          isSignedIn: false,
          userId: null,
          email: null,
          provider: null,
        ),
        entitlement: const EntitlementState(
          personalTier: UserTier.personalFree,
          source: EntitlementSource.localCache,
          lastCheckedAt: null,
          isRefreshing: false,
          lastError: null,
        ),
        cloudAccess: const PersonalCloudAccessState(
          status: PersonalCloudAccessStatus.offFree,
          label: 'Cloud backup is off',
          detail: 'Local only.',
        ),
        account: const SubscriptionAccountState.initial(),
        pendingCount: 0,
      );
      addTearDown(() async {
        harness.container.dispose();
        await harness.database.close();
      });
      await _primeUiState(harness.container);

      final presentation = harness.container.read(
        accountStatusPresentationProvider,
      );

      expect(presentation.planLabel, 'Free plan');
      expect(_chipValues(presentation), ['48h', '2', '10']);
      expect(presentation.primaryAction, AccountStatusAction.startPremium);
      expect(presentation.secondaryAction, AccountStatusAction.restorePurchase);
    });

    test(
      'signed-out store unavailable state explains missing Premium',
      () async {
        final harness = _buildUiContainer(
          auth: const AuthSessionSummary(
            isSignedIn: false,
            userId: null,
            email: null,
            provider: null,
          ),
          entitlement: const EntitlementState(
            personalTier: UserTier.personalFree,
            source: EntitlementSource.localCache,
            lastCheckedAt: null,
            isRefreshing: false,
            lastError: null,
          ),
          cloudAccess: const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.offFree,
            label: 'Cloud backup is off',
            detail: 'Local only.',
          ),
          account: const SubscriptionAccountState.initial(),
          pendingCount: 0,
          purchaseRepository: _UnavailableAccountTestPurchaseRepository(),
        );
        addTearDown(() async {
          harness.container.dispose();
          await harness.database.close();
        });
        await _primeUiState(harness.container);

        final presentation = harness.container.read(
          accountStatusPresentationProvider,
        );

        expect(presentation.title, 'Premium isn\'t available yet');
        expect(presentation.body, 'Store is not ready yet.');
        expect(presentation.primaryAction, AccountStatusAction.none);
        expect(presentation.secondaryAction, AccountStatusAction.none);
      },
    );

    test('account card shows paid signed-out plan facts', () async {
      final harness = _buildUiContainer(
        auth: const AuthSessionSummary(
          isSignedIn: false,
          userId: null,
          email: null,
          provider: null,
        ),
        entitlement: const EntitlementState(
          personalTier: UserTier.personalPremium,
          source: EntitlementSource.revenueCat,
          lastCheckedAt: null,
          isRefreshing: false,
          lastError: null,
          status: EntitlementStatus.personalPremium,
        ),
        cloudAccess: const PersonalCloudAccessState(
          status: PersonalCloudAccessStatus.pausedSignedOut,
          label: 'Backup is paused',
          detail: 'Sign in again.',
        ),
        account: const SubscriptionAccountState(
          entitlementTier: UserTier.personalPremium,
          entitlementStatus: EntitlementStatus.personalPremium,
          entitlementSource: EntitlementSource.revenueCat,
          pendingTier: null,
          bootstrapStatus: BootstrapStatus.ready,
          userId: 'user-1',
          email: 'jamie@example.com',
          authProvider: 'google',
          lastBootstrapAt: null,
          lastSyncAt: null,
          lastSyncError: null,
        ),
        pendingCount: 0,
      );
      addTearDown(() async {
        harness.container.dispose();
        await harness.database.close();
      });
      await _primeUiState(harness.container);

      final presentation = harness.container.read(
        accountStatusPresentationProvider,
      );

      expect(presentation.planLabel, 'Premium active');
      expect(presentation.title, 'Premium is on this device');
      expect(_chipValues(presentation), ['21 days', 'Unlimited', 'Unlimited']);
      expect(presentation.primaryAction, AccountStatusAction.signIn);
    });

    test('paid signed in healthy stays quiet with active backup', () async {
      final harness = _buildUiContainer(
        auth: const AuthSessionSummary(
          isSignedIn: true,
          userId: 'user-1',
          email: 'jamie@example.com',
          provider: 'google',
        ),
        entitlement: const EntitlementState(
          personalTier: UserTier.personalPremium,
          source: EntitlementSource.googlePlay,
          lastCheckedAt: null,
          isRefreshing: false,
          lastError: null,
        ),
        cloudAccess: const PersonalCloudAccessState(
          status: PersonalCloudAccessStatus.available,
          label: 'Backup is up to date',
          detail: 'Ready.',
        ),
        account: const SubscriptionAccountState(
          entitlementTier: UserTier.personalPremium,
          entitlementSource: EntitlementSource.googlePlay,
          pendingTier: null,
          bootstrapStatus: BootstrapStatus.ready,
          userId: 'user-1',
          email: 'jamie@example.com',
          authProvider: 'google',
          lastBootstrapAt: null,
          lastSyncAt: null,
          lastSyncError: null,
        ),
        pendingCount: 0,
      );
      addTearDown(() async {
        harness.container.dispose();
        await harness.database.close();
      });
      await _primeUiState(harness.container);

      final ring = harness.container.read(accountBackupRingStateProvider);
      final banner = harness.container.read(homeBackupBannerStateProvider);
      final ui = harness.container.read(accountBackupUiStateProvider);

      expect(ring.variant, AccountBackupRingVariant.available);
      expect(ring.showRing, isFalse);
      expect(banner.show, isFalse);
      expect(ui.backupSummary, 'Backup is active for supported routine data.');
      expect(ui.backupDetail, 'All caught up');
      expect(ui.backupPrimaryActionLabel, 'Refresh status');
    });

    test('account card shows fully active Premium plan facts', () async {
      final harness = _buildUiContainer(
        auth: const AuthSessionSummary(
          isSignedIn: true,
          userId: 'user-1',
          email: 'jamie@example.com',
          provider: 'google',
        ),
        entitlement: const EntitlementState(
          personalTier: UserTier.personalPremium,
          source: EntitlementSource.serverVerified,
          lastCheckedAt: null,
          isRefreshing: false,
          lastError: null,
          status: EntitlementStatus.personalPremium,
        ),
        cloudAccess: const PersonalCloudAccessState(
          status: PersonalCloudAccessStatus.available,
          label: 'Backup is up to date',
          detail: 'Ready.',
        ),
        account: const SubscriptionAccountState(
          entitlementTier: UserTier.personalPremium,
          entitlementStatus: EntitlementStatus.personalPremium,
          entitlementSource: EntitlementSource.serverVerified,
          pendingTier: null,
          bootstrapStatus: BootstrapStatus.ready,
          userId: 'user-1',
          email: 'jamie@example.com',
          authProvider: 'google',
          lastBootstrapAt: null,
          lastSyncAt: null,
          lastSyncError: null,
        ),
        pendingCount: 0,
      );
      addTearDown(() async {
        harness.container.dispose();
        await harness.database.close();
      });
      await _primeUiState(harness.container);

      final presentation = harness.container.read(
        accountStatusPresentationProvider,
      );

      expect(presentation.planLabel, 'Premium active');
      expect(presentation.title, 'Backup is on');
      expect(_chipValues(presentation), ['21 days', 'Unlimited', 'Unlimited']);
      expect(presentation.secondaryAction, AccountStatusAction.managePlan);
    });

    test('paid signed in requires consent before cloud upload', () async {
      final harness = _buildUiContainer(
        auth: const AuthSessionSummary(
          isSignedIn: true,
          userId: 'user-1',
          email: 'jamie@example.com',
          provider: 'google',
        ),
        entitlement: const EntitlementState(
          personalTier: UserTier.personalPremium,
          source: EntitlementSource.googlePlay,
          lastCheckedAt: null,
          isRefreshing: false,
          lastError: null,
        ),
        cloudAccess: const PersonalCloudAccessState(
          status: PersonalCloudAccessStatus.consentRequired,
          label: 'Review cloud backup',
          detail: 'Consent needed.',
        ),
        account: const SubscriptionAccountState(
          entitlementTier: UserTier.personalPremium,
          entitlementSource: EntitlementSource.googlePlay,
          pendingTier: null,
          bootstrapStatus: BootstrapStatus.idle,
          userId: 'user-1',
          email: 'jamie@example.com',
          authProvider: 'google',
          lastBootstrapAt: null,
          lastSyncAt: null,
          lastSyncError: null,
        ),
        pendingCount: 0,
      );
      addTearDown(() async {
        harness.container.dispose();
        await harness.database.close();
      });
      await _primeUiState(harness.container);

      final ring = harness.container.read(accountBackupRingStateProvider);
      final banner = harness.container.read(homeBackupBannerStateProvider);
      final ui = harness.container.read(accountBackupUiStateProvider);

      expect(ring.variant, AccountBackupRingVariant.consentRequired);
      expect(
        banner.message,
        'Review cloud backup before Pebble uploads routine data.',
      );
      expect(ui.backupSummary, 'Review cloud backup before upload starts.');
      expect(ui.backupPrimaryActionLabel, 'Review and enable');
    });

    test('paid signed out shows paused state without implying loss', () async {
      final harness = _buildUiContainer(
        auth: const AuthSessionSummary(
          isSignedIn: false,
          userId: null,
          email: null,
          provider: null,
        ),
        entitlement: const EntitlementState(
          personalTier: UserTier.personalPremium,
          source: EntitlementSource.googlePlay,
          lastCheckedAt: null,
          isRefreshing: false,
          lastError: null,
        ),
        cloudAccess: const PersonalCloudAccessState(
          status: PersonalCloudAccessStatus.pausedSignedOut,
          label: 'Backup is paused',
          detail: 'Sign in again.',
        ),
        account: const SubscriptionAccountState(
          entitlementTier: UserTier.personalPremium,
          entitlementSource: EntitlementSource.googlePlay,
          pendingTier: null,
          bootstrapStatus: BootstrapStatus.ready,
          userId: 'user-1',
          email: 'jamie@example.com',
          authProvider: 'google',
          lastBootstrapAt: null,
          lastSyncAt: null,
          lastSyncError: null,
        ),
        pendingCount: 0,
      );
      addTearDown(() async {
        harness.container.dispose();
        await harness.database.close();
      });
      await _primeUiState(harness.container);

      final ring = harness.container.read(accountBackupRingStateProvider);
      final banner = harness.container.read(homeBackupBannerStateProvider);
      final ui = harness.container.read(accountBackupUiStateProvider);

      expect(ring.variant, AccountBackupRingVariant.paused);
      expect(banner.message, 'Backup is paused. Sign in to resume.');
      expect(ui.backupSummary, 'Backup is paused. Sign in to resume.');
      expect(ui.backupDetail, 'Sign in to resume backup.');
    });

    test(
      'offline pending explains that backup exists but sync is waiting',
      () async {
        final harness = _buildUiContainer(
          auth: const AuthSessionSummary(
            isSignedIn: true,
            userId: 'user-1',
            email: 'jamie@example.com',
            provider: 'google',
          ),
          entitlement: const EntitlementState(
            personalTier: UserTier.personalPremium,
            source: EntitlementSource.googlePlay,
            lastCheckedAt: null,
            isRefreshing: false,
            lastError: null,
          ),
          cloudAccess: const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.available,
            label: 'Backup is up to date',
            detail: 'Ready.',
          ),
          account: const SubscriptionAccountState(
            entitlementTier: UserTier.personalPremium,
            entitlementSource: EntitlementSource.googlePlay,
            pendingTier: null,
            bootstrapStatus: BootstrapStatus.error,
            userId: 'user-1',
            email: 'jamie@example.com',
            authProvider: 'google',
            lastBootstrapAt: null,
            lastSyncAt: null,
            lastSyncError: 'offline',
          ),
          pendingCount: 3,
        );
        addTearDown(() async {
          harness.container.dispose();
          await harness.database.close();
        });
        await _primeUiState(harness.container);

        final ring = harness.container.read(accountBackupRingStateProvider);
        final banner = harness.container.read(homeBackupBannerStateProvider);
        final ui = harness.container.read(accountBackupUiStateProvider);

        expect(ring.variant, AccountBackupRingVariant.offlinePending);
        expect(banner.message, 'You\'re offline. Changes will sync later.');
        expect(ui.backupSummary, 'Waiting for connection');
        expect(ui.backupPrimaryActionLabel, 'Refresh status');
      },
    );

    test(
      'active syncing shows syncing ring and banner instead of retry CTA',
      () async {
        final harness = _buildUiContainer(
          auth: const AuthSessionSummary(
            isSignedIn: true,
            userId: 'user-1',
            email: 'jamie@example.com',
            provider: 'google',
          ),
          entitlement: const EntitlementState(
            personalTier: UserTier.personalPremium,
            source: EntitlementSource.googlePlay,
            lastCheckedAt: null,
            isRefreshing: false,
            lastError: null,
          ),
          cloudAccess: const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.available,
            label: 'Backup is up to date',
            detail: 'Ready.',
          ),
          account: const SubscriptionAccountState(
            entitlementTier: UserTier.personalPremium,
            entitlementSource: EntitlementSource.googlePlay,
            pendingTier: null,
            bootstrapStatus: BootstrapStatus.ready,
            userId: 'user-1',
            email: 'jamie@example.com',
            authProvider: 'google',
            lastBootstrapAt: null,
            lastSyncAt: null,
            lastSyncError: null,
          ),
          pendingCount: 4,
          runtime: const CloudSyncRuntimeState(
            isRunning: true,
            pendingCount: 4,
            nextRetryAt: null,
          ),
        );
        addTearDown(() async {
          harness.container.dispose();
          await harness.database.close();
        });
        await _primeUiState(harness.container);

        final ring = harness.container.read(accountBackupRingStateProvider);
        final banner = harness.container.read(homeBackupBannerStateProvider);
        final ui = harness.container.read(accountBackupUiStateProvider);

        expect(ring.variant, AccountBackupRingVariant.syncing);
        expect(banner.message, 'Syncing your latest changes...');
        expect(banner.action, HomeBackupBannerAction.none);
        expect(ui.backupSummary, 'Syncing latest changes');
        expect(ui.backupDetail, '4 changes still need to sync');
      },
    );

    test(
      'retry-scheduled error offers sync now without implying cancellation',
      () async {
        final harness = _buildUiContainer(
          auth: const AuthSessionSummary(
            isSignedIn: true,
            userId: 'user-1',
            email: 'jamie@example.com',
            provider: 'google',
          ),
          entitlement: const EntitlementState(
            personalTier: UserTier.personalPremium,
            source: EntitlementSource.googlePlay,
            lastCheckedAt: null,
            isRefreshing: false,
            lastError: null,
          ),
          cloudAccess: const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.error,
            label: 'Needs attention',
            detail: 'Sync problem.',
          ),
          account: const SubscriptionAccountState(
            entitlementTier: UserTier.personalPremium,
            entitlementSource: EntitlementSource.googlePlay,
            pendingTier: null,
            bootstrapStatus: BootstrapStatus.error,
            userId: 'user-1',
            email: 'jamie@example.com',
            authProvider: 'google',
            lastBootstrapAt: null,
            lastSyncAt: null,
            lastSyncError: 'server error',
          ),
          pendingCount: 2,
          runtime: CloudSyncRuntimeState(
            isRunning: false,
            pendingCount: 2,
            nextRetryAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        );
        addTearDown(() async {
          harness.container.dispose();
          await harness.database.close();
        });
        await _primeUiState(harness.container);

        final banner = harness.container.read(homeBackupBannerStateProvider);
        final ui = harness.container.read(accountBackupUiStateProvider);

        expect(banner.message, 'Pebble will try syncing again soon.');
        expect(banner.actionLabel, 'Sync now');
        expect(
          ui.backupSummary,
          'Backup is active, but Pebble couldn\'t finish syncing everything.',
        );
        expect(
          ui.backupDetail,
          anyOf(
            '2 changes still need to sync',
            'Pebble will try again soon. You can also sync now.',
          ),
        );
      },
    );

    test(
      'full proof photo storage shows account attention without blocking routine sync',
      () async {
        final harness = _buildUiContainer(
          auth: const AuthSessionSummary(
            isSignedIn: true,
            userId: 'user-1',
            email: 'jamie@example.com',
            provider: 'google',
          ),
          entitlement: const EntitlementState(
            personalTier: UserTier.personalPremium,
            source: EntitlementSource.googlePlay,
            lastCheckedAt: null,
            isRefreshing: false,
            lastError: null,
          ),
          cloudAccess: const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.available,
            label: 'Backup is up to date',
            detail: 'Ready.',
          ),
          account: const SubscriptionAccountState(
            entitlementTier: UserTier.personalPremium,
            entitlementSource: EntitlementSource.googlePlay,
            pendingTier: null,
            bootstrapStatus: BootstrapStatus.ready,
            userId: 'user-1',
            email: 'jamie@example.com',
            authProvider: 'google',
            lastBootstrapAt: null,
            lastSyncAt: null,
            lastSyncError: null,
          ),
          pendingCount: 0,
          fairUseState: const ProofMediaFairUseState(
            activeCloudBytes: ProofMediaFairUsePolicy.storageLimitBytes,
            storageLimitBytes: ProofMediaFairUsePolicy.storageLimitBytes,
            uploadsThisPeriod: 50,
            monthlyUploadLimit: ProofMediaFairUsePolicy.monthlyUploadLimit,
          ),
        );
        addTearDown(() async {
          harness.container.dispose();
          await harness.database.close();
        });
        await _primeUiState(harness.container);

        final ring = harness.container.read(accountBackupRingStateProvider);
        final banner = harness.container.read(homeBackupBannerStateProvider);
        final ui = harness.container.read(accountBackupUiStateProvider);

        expect(ring.variant, AccountBackupRingVariant.storageWarning);
        expect(banner.message, 'Photo storage full. Routine sync still works.');
        expect(
          ui.backupDetail,
          'Photo storage full. Routine sync still works.',
        );
      },
    );
  });

  group('Manual sync results', () {
    late LocalDb database;
    late _FakeProofStorage proofStorage;
    late _CapturingRoutineDataSource routineDataSource;
    late _CapturingReminderDataSource reminderDataSource;
    late _CapturingRunDataSource runDataSource;

    setUp(() {
      database = LocalDb.forTesting(NativeDatabase.memory());
      proofStorage = _FakeProofStorage();
      routineDataSource = _CapturingRoutineDataSource();
      reminderDataSource = _CapturingReminderDataSource();
      runDataSource = _CapturingRunDataSource();
    });

    tearDown(() async {
      await database.close();
    });

    test('signed out manual sync explains the blocker', () async {
      final outbox = SyncOutboxRepositoryImpl(database);
      final container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          syncOutboxRepositoryProvider.overrideWithValue(outbox),
          routineSessionProofStorageProvider.overrideWithValue(proofStorage),
          authSessionProvider.overrideWithValue(
            const AuthSessionSummary(
              isSignedIn: false,
              userId: null,
              email: null,
              provider: null,
            ),
          ),
          entitlementStateProvider.overrideWithValue(
            const EntitlementState(
              personalTier: UserTier.personalPremium,
              source: EntitlementSource.googlePlay,
              lastCheckedAt: null,
              isRefreshing: false,
              lastError: null,
            ),
          ),
          cloudAccessPolicyProvider.overrideWithValue(
            const CloudAccessPolicy(
              cachedOwnerUserId: 'user-1',
              personalCloudEnabled: false,
              canQueuePersonalSync: true,
              workspaceCloudEnabled: false,
              isSignedIn: false,
              isAccountSwitchBlocked: false,
            ),
          ),
          subscriptionAccountControllerProvider.overrideWith(
            (ref) => _TestSubscriptionAccountController(
              database,
              const SubscriptionAccountState(
                entitlementTier: UserTier.personalPremium,
                entitlementSource: EntitlementSource.googlePlay,
                pendingTier: null,
                bootstrapStatus: BootstrapStatus.ready,
                userId: 'user-1',
                email: 'jamie@example.com',
                authProvider: 'google',
                lastBootstrapAt: null,
                lastSyncAt: null,
                lastSyncError: null,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cloudSyncCoordinatorProvider)
          .runManualSync();

      expect(result.type, ManualSyncResultType.blockedSignedOut);
      expect(result.message, 'Sign in to resume backup and sync.');
    });

    test('manual sync explains cloud backup consent blocker', () async {
      final outbox = SyncOutboxRepositoryImpl(database);
      final container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          syncOutboxRepositoryProvider.overrideWithValue(outbox),
          routineSessionProofStorageProvider.overrideWithValue(proofStorage),
          authSessionProvider.overrideWithValue(
            const AuthSessionSummary(
              isSignedIn: true,
              userId: 'user-1',
              email: 'jamie@example.com',
              provider: 'google',
            ),
          ),
          entitlementStateProvider.overrideWithValue(
            const EntitlementState(
              personalTier: UserTier.personalPremium,
              source: EntitlementSource.googlePlay,
              lastCheckedAt: null,
              isRefreshing: false,
              lastError: null,
            ),
          ),
          personalCloudAccessProvider.overrideWithValue(
            const PersonalCloudAccessState(
              status: PersonalCloudAccessStatus.consentRequired,
              label: 'Review cloud backup',
              detail: 'Consent needed.',
            ),
          ),
          cloudAccessPolicyProvider.overrideWithValue(
            const CloudAccessPolicy(
              cachedOwnerUserId: 'user-1',
              personalCloudEnabled: false,
              canQueuePersonalSync: false,
              workspaceCloudEnabled: false,
              isSignedIn: true,
              isAccountSwitchBlocked: false,
            ),
          ),
          subscriptionAccountControllerProvider.overrideWith(
            (ref) => _TestSubscriptionAccountController(
              database,
              const SubscriptionAccountState(
                entitlementTier: UserTier.personalPremium,
                entitlementSource: EntitlementSource.googlePlay,
                pendingTier: null,
                bootstrapStatus: BootstrapStatus.idle,
                userId: 'user-1',
                email: 'jamie@example.com',
                authProvider: 'google',
                lastBootstrapAt: null,
                lastSyncAt: null,
                lastSyncError: null,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cloudSyncCoordinatorProvider)
          .runManualSync();

      expect(result.type, ManualSyncResultType.blockedConsentRequired);
      expect(
        result.message,
        'Review and enable cloud backup before Pebble uploads data.',
      );
    });

    test(
      'up-to-date manual sync reports success without generic error',
      () async {
        final outbox = SyncOutboxRepositoryImpl(database);
        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            syncOutboxRepositoryProvider.overrideWithValue(outbox),
            routineSessionProofStorageProvider.overrideWithValue(proofStorage),
            authSessionProvider.overrideWithValue(
              const AuthSessionSummary(
                isSignedIn: true,
                userId: 'user-1',
                email: 'jamie@example.com',
                provider: 'google',
              ),
            ),
            entitlementStateProvider.overrideWithValue(
              const EntitlementState(
                personalTier: UserTier.personalPremium,
                source: EntitlementSource.googlePlay,
                lastCheckedAt: null,
                isRefreshing: false,
                lastError: null,
              ),
            ),
            cloudAccessPolicyProvider.overrideWithValue(
              const CloudAccessPolicy(
                cachedOwnerUserId: 'user-1',
                personalCloudEnabled: true,
                canQueuePersonalSync: true,
                workspaceCloudEnabled: false,
                isSignedIn: true,
                isAccountSwitchBlocked: false,
              ),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  entitlementSource: EntitlementSource.googlePlay,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: 'user-1',
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(cloudSyncCoordinatorProvider)
            .runManualSync();

        expect(result.type, ManualSyncResultType.noChanges);
        expect(result.message, 'Everything is up to date.');
      },
    );

    test(
      'manual sync catches up local routines that were never queued',
      () async {
        const ownerUserId = '11111111-1111-1111-1111-111111111111';
        final expectedRoutineCloudId = const Uuid().v5(
          Namespace.url.value,
          'vix.pebble/routine/1',
        );
        await database.routineDao.insertOrUpdateRoutine(
          _buildRoutine(ownerUserId: ownerUserId),
        );

        final outbox = SyncOutboxRepositoryImpl(database);
        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            syncOutboxRepositoryProvider.overrideWithValue(outbox),
            routineSessionProofStorageProvider.overrideWithValue(proofStorage),
            authSessionProvider.overrideWithValue(
              const AuthSessionSummary(
                isSignedIn: true,
                userId: ownerUserId,
                email: 'jamie@example.com',
                provider: 'google',
              ),
            ),
            entitlementStateProvider.overrideWithValue(
              const EntitlementState(
                personalTier: UserTier.personalPremium,
                source: EntitlementSource.googlePlay,
                lastCheckedAt: null,
                isRefreshing: false,
                lastError: null,
              ),
            ),
            cloudAccessPolicyProvider.overrideWithValue(
              const CloudAccessPolicy(
                cachedOwnerUserId: ownerUserId,
                personalCloudEnabled: true,
                canQueuePersonalSync: true,
                workspaceCloudEnabled: false,
                isSignedIn: true,
                isAccountSwitchBlocked: false,
              ),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  entitlementSource: EntitlementSource.googlePlay,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: ownerUserId,
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                ),
              ),
            ),
            remoteRoutineDataSourceProvider.overrideWithValue(
              routineDataSource,
            ),
            remoteRoutineReminderDataSourceProvider.overrideWithValue(
              reminderDataSource,
            ),
            remoteRoutineRunDataSourceProvider.overrideWithValue(runDataSource),
            remoteRoutineSessionDataSourceProvider.overrideWithValue(
              RemoteRoutineSessionDataSource(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(cloudSyncCoordinatorProvider)
            .runManualSync();

        final syncedRoutine = await database.routineDao.getRoutineById(1);
        expect(result.type, ManualSyncResultType.synced);
        expect(routineDataSource.upserts, hasLength(1));
        expect(routineDataSource.upserts.single['id'], expectedRoutineCloudId);
        expect(routineDataSource.upserts.single['owner_user_id'], ownerUserId);
        expect(syncedRoutine?.syncStatus, 'synced');
        expect(syncedRoutine?.cloudId, expectedRoutineCloudId);
        expect(await outbox.pendingItems(), isEmpty);
      },
    );

    test(
      'offline manual sync reports offline instead of a generic failure',
      () async {
        final outbox = SyncOutboxRepositoryImpl(database);
        await database.routineDao.insertOrUpdateRoutine(
          _buildRoutine(ownerUserId: 'user-1'),
        );
        await outbox.enqueue(
          entityType: SyncEntityType.routine,
          entityId: '1',
          operation: SyncOperation.upsert,
        );

        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            syncOutboxRepositoryProvider.overrideWithValue(outbox),
            routineSessionProofStorageProvider.overrideWithValue(proofStorage),
            authSessionProvider.overrideWithValue(
              const AuthSessionSummary(
                isSignedIn: true,
                userId: 'user-1',
                email: 'jamie@example.com',
                provider: 'google',
              ),
            ),
            entitlementStateProvider.overrideWithValue(
              const EntitlementState(
                personalTier: UserTier.personalPremium,
                source: EntitlementSource.googlePlay,
                lastCheckedAt: null,
                isRefreshing: false,
                lastError: null,
              ),
            ),
            cloudAccessPolicyProvider.overrideWithValue(
              const CloudAccessPolicy(
                cachedOwnerUserId: 'user-1',
                personalCloudEnabled: true,
                canQueuePersonalSync: true,
                workspaceCloudEnabled: false,
                isSignedIn: true,
                isAccountSwitchBlocked: false,
              ),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  entitlementSource: EntitlementSource.googlePlay,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: 'user-1',
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                ),
              ),
            ),
            remoteRoutineDataSourceProvider.overrideWithValue(
              _OfflineRoutineDataSource(),
            ),
            remoteRoutineReminderDataSourceProvider.overrideWithValue(
              RemoteRoutineReminderDataSource(null),
            ),
            remoteRoutineRunDataSourceProvider.overrideWithValue(
              RemoteRoutineRunDataSource(null),
            ),
            remoteRoutineSessionDataSourceProvider.overrideWithValue(
              RemoteRoutineSessionDataSource(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(cloudSyncCoordinatorProvider)
            .runManualSync();

        expect(result.type, ManualSyncResultType.blockedOffline);
        expect(result.message, 'You\'re offline. Changes will sync later.');
      },
    );

    test(
      'manual sync sanitizes legacy routine ids and signed color values before syncing reminders',
      () async {
        const legacyCloudId = '1761243449440';
        const legacyColor = 4292352864;
        const ownerUserId = '11111111-1111-1111-1111-111111111111';
        final expectedRoutineCloudId = const Uuid().v5(
          Namespace.url.value,
          'vix.pebble/$legacyCloudId',
        );

        await database.routineDao.insertOrUpdateRoutine(
          Routine(
            id: 1,
            title: 'Night reset',
            stepsJson: jsonEncode(const []),
            createdAt: DateTime(2026, 1, 1),
            emoji: null,
            colorHex: legacyColor,
            isPinned: false,
            pinnedAt: null,
            reminderDay: null,
            reminderTime: null,
            version: 1,
            updatedAt: DateTime(2026, 1, 1),
            cloudId: legacyCloudId,
            ownerUserId: ownerUserId,
            syncStatus: 'pendingUpload',
            lastSyncedAt: null,
          ),
        );
        final reminderId = await database.routineReminderDao.addReminder(
          RoutineRemindersCompanion.insert(
            routineId: 1,
            dayOfWeek: 1,
            time: '9:00 AM',
            ownerUserId: const drift.Value(ownerUserId),
          ),
        );
        await database.syncOutboxDao.enqueue(
          SyncOutboxRow(
            id: 'routine-sync',
            entityType: SyncEntityType.routine.name,
            entityId: '1',
            operation: SyncOperation.upsert.name,
            payloadJson: null,
            attemptCount: 0,
            lastErrorSummary: null,
            nextAttemptAt: null,
            createdAt: DateTime(2026, 1, 1, 10),
            updatedAt: DateTime(2026, 1, 1, 10),
          ),
        );
        await database.syncOutboxDao.enqueue(
          SyncOutboxRow(
            id: 'reminder-sync',
            entityType: SyncEntityType.reminder.name,
            entityId: reminderId.toString(),
            operation: SyncOperation.upsert.name,
            payloadJson: null,
            attemptCount: 0,
            lastErrorSummary: null,
            nextAttemptAt: null,
            createdAt: DateTime(2026, 1, 1, 10, 1),
            updatedAt: DateTime(2026, 1, 1, 10, 1),
          ),
        );

        final outbox = SyncOutboxRepositoryImpl(database);
        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            syncOutboxRepositoryProvider.overrideWithValue(outbox),
            routineSessionProofStorageProvider.overrideWithValue(proofStorage),
            authSessionProvider.overrideWithValue(
              const AuthSessionSummary(
                isSignedIn: true,
                userId: ownerUserId,
                email: 'jamie@example.com',
                provider: 'google',
              ),
            ),
            entitlementStateProvider.overrideWithValue(
              const EntitlementState(
                personalTier: UserTier.personalPremium,
                source: EntitlementSource.googlePlay,
                lastCheckedAt: null,
                isRefreshing: false,
                lastError: null,
              ),
            ),
            cloudAccessPolicyProvider.overrideWithValue(
              const CloudAccessPolicy(
                cachedOwnerUserId: ownerUserId,
                personalCloudEnabled: true,
                canQueuePersonalSync: true,
                workspaceCloudEnabled: false,
                isSignedIn: true,
                isAccountSwitchBlocked: false,
              ),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  entitlementSource: EntitlementSource.googlePlay,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: ownerUserId,
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                ),
              ),
            ),
            remoteRoutineDataSourceProvider.overrideWithValue(
              routineDataSource,
            ),
            remoteRoutineReminderDataSourceProvider.overrideWithValue(
              reminderDataSource,
            ),
            remoteRoutineRunDataSourceProvider.overrideWithValue(runDataSource),
            remoteRoutineSessionDataSourceProvider.overrideWithValue(
              RemoteRoutineSessionDataSource(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(cloudSyncCoordinatorProvider)
            .runManualSync();

        expect(result.type, ManualSyncResultType.synced);
        expect(routineDataSource.upserts, hasLength(1));
        expect(routineDataSource.upserts.single['id'], expectedRoutineCloudId);
        expect(
          routineDataSource.upserts.single['color_hex'],
          legacyColor.toUnsigned(32).toSigned(32),
        );
        expect(reminderDataSource.upserts, hasLength(1));
        expect(
          reminderDataSource.upserts.single['routine_id'],
          expectedRoutineCloudId,
        );
        expect(await outbox.pendingItems(), isEmpty);
      },
    );

    test(
      'manual sync resolves run routine ids stored as local string ids',
      () async {
        const ownerUserId = '11111111-1111-1111-1111-111111111111';
        const routineCloudId = '22222222-2222-4222-8222-222222222222';

        await database.routineDao.insertOrUpdateRoutine(
          Routine(
            id: 1,
            title: 'Morning startup',
            stepsJson: jsonEncode(const []),
            createdAt: DateTime(2026, 1, 1),
            emoji: null,
            colorHex: null,
            isPinned: false,
            pinnedAt: null,
            reminderDay: null,
            reminderTime: null,
            version: 1,
            updatedAt: DateTime(2026, 1, 1),
            cloudId: routineCloudId,
            ownerUserId: ownerUserId,
            syncStatus: 'synced',
            lastSyncedAt: DateTime(2026, 1, 1),
          ),
        );
        await database.routineRunDao.insertOrUpdateRun(
          RoutineRun(
            id: '33333333-3333-4333-8333-333333333333',
            routineId: '1',
            routineTitle: 'Morning startup',
            finishedAt: DateTime(2026, 1, 2),
            stepCompletionData: jsonEncode({'steps': const []}),
            ownerUserId: ownerUserId,
            syncStatus: 'pendingUpload',
            lastSyncedAt: null,
            syncMetadataJson: null,
            updatedAt: DateTime(2026, 1, 2),
          ),
        );
        await database.syncOutboxDao.enqueue(
          SyncOutboxRow(
            id: 'run-sync',
            entityType: SyncEntityType.run.name,
            entityId: '33333333-3333-4333-8333-333333333333',
            operation: SyncOperation.upsert.name,
            payloadJson: null,
            attemptCount: 0,
            lastErrorSummary: null,
            nextAttemptAt: null,
            createdAt: DateTime(2026, 1, 2),
            updatedAt: DateTime(2026, 1, 2),
          ),
        );

        final outbox = SyncOutboxRepositoryImpl(database);
        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            syncOutboxRepositoryProvider.overrideWithValue(outbox),
            routineSessionProofStorageProvider.overrideWithValue(proofStorage),
            authSessionProvider.overrideWithValue(
              const AuthSessionSummary(
                isSignedIn: true,
                userId: ownerUserId,
                email: 'jamie@example.com',
                provider: 'google',
              ),
            ),
            entitlementStateProvider.overrideWithValue(
              const EntitlementState(
                personalTier: UserTier.personalPremium,
                source: EntitlementSource.googlePlay,
                lastCheckedAt: null,
                isRefreshing: false,
                lastError: null,
              ),
            ),
            cloudAccessPolicyProvider.overrideWithValue(
              const CloudAccessPolicy(
                cachedOwnerUserId: ownerUserId,
                personalCloudEnabled: true,
                canQueuePersonalSync: true,
                workspaceCloudEnabled: false,
                isSignedIn: true,
                isAccountSwitchBlocked: false,
              ),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  entitlementSource: EntitlementSource.googlePlay,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: ownerUserId,
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                ),
              ),
            ),
            remoteRoutineDataSourceProvider.overrideWithValue(
              routineDataSource,
            ),
            remoteRoutineReminderDataSourceProvider.overrideWithValue(
              reminderDataSource,
            ),
            remoteRoutineRunDataSourceProvider.overrideWithValue(runDataSource),
            remoteRoutineSessionDataSourceProvider.overrideWithValue(
              RemoteRoutineSessionDataSource(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(cloudSyncCoordinatorProvider)
            .runManualSync();

        expect(result.type, ManualSyncResultType.synced);
        expect(runDataSource.upserts, hasLength(1));
        expect(runDataSource.upserts.single['routine_id'], routineCloudId);
        expect(await outbox.pendingItems(), isEmpty);
      },
    );

    test(
      'manual sync uploads runs even if the routine was deleted locally',
      () async {
        const ownerUserId = '11111111-1111-1111-1111-111111111111';
        final expectedRoutineCloudId = const Uuid().v5(
          Namespace.url.value,
          'vix.pebble/routine/1',
        );

        await database.routineRunDao.insertOrUpdateRun(
          RoutineRun(
            id: '33333333-3333-4333-8333-333333333333',
            routineId: '1',
            routineTitle: 'Morning startup',
            finishedAt: DateTime(2026, 1, 2),
            stepCompletionData: jsonEncode({'steps': const []}),
            ownerUserId: ownerUserId,
            syncStatus: 'pendingUpload',
            lastSyncedAt: null,
            syncMetadataJson: null,
            updatedAt: DateTime(2026, 1, 2),
          ),
        );
        await database.syncOutboxDao.enqueue(
          SyncOutboxRow(
            id: 'run-sync',
            entityType: SyncEntityType.run.name,
            entityId: '33333333-3333-4333-8333-333333333333',
            operation: SyncOperation.upsert.name,
            payloadJson: null,
            attemptCount: 0,
            lastErrorSummary: null,
            nextAttemptAt: null,
            createdAt: DateTime(2026, 1, 2),
            updatedAt: DateTime(2026, 1, 2),
          ),
        );

        final outbox = SyncOutboxRepositoryImpl(database);
        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            syncOutboxRepositoryProvider.overrideWithValue(outbox),
            routineSessionProofStorageProvider.overrideWithValue(proofStorage),
            authSessionProvider.overrideWithValue(
              const AuthSessionSummary(
                isSignedIn: true,
                userId: ownerUserId,
                email: 'jamie@example.com',
                provider: 'google',
              ),
            ),
            entitlementStateProvider.overrideWithValue(
              const EntitlementState(
                personalTier: UserTier.personalPremium,
                source: EntitlementSource.googlePlay,
                lastCheckedAt: null,
                isRefreshing: false,
                lastError: null,
              ),
            ),
            cloudAccessPolicyProvider.overrideWithValue(
              const CloudAccessPolicy(
                cachedOwnerUserId: ownerUserId,
                personalCloudEnabled: true,
                canQueuePersonalSync: true,
                workspaceCloudEnabled: false,
                isSignedIn: true,
                isAccountSwitchBlocked: false,
              ),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  entitlementSource: EntitlementSource.googlePlay,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: ownerUserId,
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                ),
              ),
            ),
            remoteRoutineDataSourceProvider.overrideWithValue(
              routineDataSource,
            ),
            remoteRoutineReminderDataSourceProvider.overrideWithValue(
              reminderDataSource,
            ),
            remoteRoutineRunDataSourceProvider.overrideWithValue(runDataSource),
            remoteRoutineSessionDataSourceProvider.overrideWithValue(
              RemoteRoutineSessionDataSource(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(cloudSyncCoordinatorProvider)
            .runManualSync();

        expect(result.type, ManualSyncResultType.synced);
        expect(runDataSource.upserts, hasLength(1));
        expect(
          runDataSource.upserts.single['routine_id'],
          expectedRoutineCloudId,
        );
        expect(await outbox.pendingItems(), isEmpty);
      },
    );
  });
}
