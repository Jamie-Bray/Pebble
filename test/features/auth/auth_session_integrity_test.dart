// What sign-in, sign-out and app start leave behind for backup.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/data/auth_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';

const _accountA = AuthIdentity(
  userId: 'account-a',
  email: 'a@example.com',
  provider: 'google',
);

void main() {
  test('starting offline keeps a stored session signed in', () async {
    final container = await _container(
      _FakeAuthRepository(
        stored: _accountA,
        profileError: const SocketException('offline'),
      ),
    );

    container.read(authControllerProvider);
    await pumpEventQueue();

    final auth = container.read(authSessionProvider);
    expect(auth.isSignedIn, isTrue);
    expect(auth.userId, 'account-a');
    expect(
      container.read(subscriptionAccountControllerProvider).userId,
      'account-a',
    );
  });

  test('sign-out does not hand backup times to the next account', () async {
    final container = await _container(
      _FakeAuthRepository(stored: _accountA),
      account: _premiumAccount(
        userId: 'account-a',
        status: BootstrapStatus.ready,
        syncedAt: DateTime.utc(2026, 7, 15, 11),
      ),
    );
    final controller = container.read(authControllerProvider.notifier);
    await pumpEventQueue();

    await controller.signOut();
    final signedOut = container.read(subscriptionAccountControllerProvider);
    expect(signedOut.userId, isNull);
    expect(signedOut.bootstrapStatus, BootstrapStatus.idle);
    expect(signedOut.lastSyncError, isNull);
    // Premium is a store purchase on this device, so it stays.
    expect(signedOut.entitlementTier, UserTier.personalPremium);

    await container
        .read(subscriptionAccountControllerProvider.notifier)
        .cacheAuthenticatedIdentity(
          userId: 'account-b',
          email: 'b@example.com',
          authProvider: 'google',
        );

    final next = container.read(subscriptionAccountControllerProvider);
    expect(next.userId, 'account-b');
    expect(next.lastSyncAt, isNull);
    expect(next.lastBootstrapAt, isNull);
    expect(next.bootstrapStatus, BootstrapStatus.idle);
  });

  test('a failed restore leaves a retryable error, not "preparing"', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final consent = CloudBackupConsentRecord(
      userId: 'account-a',
      feature: cloudBackupConsentFeature,
      featureEnabled: true,
      appVersion: cloudBackupConsentUnknownAppVersion,
      privacyVersion: cloudBackupConsentPrivacyVersion,
      termsVersion: cloudBackupConsentTermsVersion,
      consentTextHash: cloudBackupConsentTextHash,
      consentedAt: DateTime.utc(2026, 7, 1),
      withdrawnAt: null,
    );
    final container = await _container(
      _FakeAuthRepository(stored: _accountA),
      // Free at launch, so start-up does not attempt the restore itself.
      account: const SubscriptionAccountState.initial(),
      extraOverrides: [
        cloudRestoreCoordinatorProvider.overrideWithValue(
          _ThrowingRestoreCoordinator(),
        ),
        cloudBackupConsentControllerProvider.overrideWith(
          (ref) => _AcceptedConsentController(
            CloudBackupConsentState(
              isLoading: false,
              record: consent,
              lastError: null,
              isRemoteConfirmed: true,
            ),
            prefs: prefs,
            auth: const AuthSessionSummary(
              isSignedIn: true,
              userId: 'account-a',
              email: 'a@example.com',
              provider: 'google',
            ),
          ),
        ),
      ],
    );
    final controller = container.read(authControllerProvider.notifier);
    await pumpEventQueue();
    final account =
        container.read(subscriptionAccountControllerProvider.notifier)
            as _TestSubscriptionAccountController;
    account.become(
      _premiumAccount(userId: 'account-a', status: BootstrapStatus.idle),
    );

    await expectLater(
      controller.refreshCloudAccessAfterEntitlementChange(
        refreshEntitlement: false,
      ),
      throwsException,
    );

    final after = container.read(subscriptionAccountControllerProvider);
    expect(after.bootstrapStatus, BootstrapStatus.error);
    expect(after.lastSyncError, contains('Backup setup is not ready yet'));
    // The sign-in itself is untouched.
    expect(container.read(authSessionProvider).isSignedIn, isTrue);
  });
}

SubscriptionAccountState _premiumAccount({
  required String userId,
  required BootstrapStatus status,
  DateTime? syncedAt,
}) {
  return SubscriptionAccountState(
    entitlementTier: UserTier.personalPremium,
    pendingTier: null,
    bootstrapStatus: status,
    userId: userId,
    email: '$userId@example.com',
    authProvider: 'google',
    lastBootstrapAt: syncedAt,
    lastSyncAt: syncedAt,
    lastSyncError: null,
    entitlementStatus: EntitlementStatus.personalPremium,
    entitlementSource: EntitlementSource.serverVerified,
  );
}

Future<ProviderContainer> _container(
  AuthRepository repository, {
  SubscriptionAccountState account = const SubscriptionAccountState.initial(),
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final database = LocalDb.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      localDbProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseRuntimeConfigProvider.overrideWithValue(
        const SupabaseRuntimeConfig.disabled(),
      ),
      supabaseClientProvider.overrideWithValue(null),
      authRepositoryProvider.overrideWithValue(repository),
      purchaseRepositoryProvider.overrideWith(
        (ref) => _FakePurchaseRepository(),
      ),
      subscriptionAccountControllerProvider.overrideWith(
        (ref) => _TestSubscriptionAccountController(database, account),
      ),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  addTearDown(database.close);
  return container;
}

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(super.db, SubscriptionAccountState initial)
    : super(loadOnInit: false) {
    state = initial;
  }

  void become(SubscriptionAccountState next) => state = next;
}

class _AcceptedConsentController extends CloudBackupConsentController {
  _AcceptedConsentController(
    CloudBackupConsentState initial, {
    required super.prefs,
    required super.auth,
  }) : super(client: null) {
    state = initial;
  }

  @override
  Future<void> load() async {}
}

class _ThrowingRestoreCoordinator implements CloudRestoreCoordinator {
  @override
  Future<void> bootstrapAndMerge(String ownerUserId) async {
    throw Exception('remote merge failed');
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.stored, this.profileError});

  final AuthIdentity? stored;
  final Object? profileError;

  @override
  bool get isConfigured => true;

  @override
  Future<AuthIdentity?> currentIdentity() async => stored;

  @override
  Future<void> upsertProfile({required AuthIdentity identity}) async {
    final error = profileError;
    if (error != null) throw error;
  }

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  @override
  Future<void> logOut() async {}

  @override
  Future<void> syncPurchasesSilently({
    bool waitForServerMirror = false,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
