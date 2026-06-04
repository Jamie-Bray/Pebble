import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_reminder_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(
    super.db,
    SubscriptionAccountState initialState,
  ) : super(loadOnInit: false) {
    state = initialState;
  }
}

class _TestCloudBackupConsentController extends CloudBackupConsentController {
  _TestCloudBackupConsentController(
    CloudBackupConsentState initialState, {
    required super.prefs,
    required super.auth,
  }) : super(client: null) {
    state = initialState;
  }

  @override
  Future<void> load() async {}
  @override
  Future<void> accept() async {}
  @override
  Future<void> withdraw() async {}
}

class _FakeRoutineDataSource extends RemoteRoutineDataSource {
  _FakeRoutineDataSource(this.records) : super(null);

  final List<RemoteRoutineRecord> records;

  @override
  Future<List<RemoteRoutineRecord>> fetchAll(String ownerUserId) async =>
      records;
}

class _FakeReminderDataSource extends RemoteRoutineReminderDataSource {
  _FakeReminderDataSource(this.records) : super(null);

  final List<RemoteRoutineReminderRecord> records;

  @override
  Future<List<RemoteRoutineReminderRecord>> fetchAll(
    String ownerUserId,
  ) async => records;
}

class _FakeRunDataSource extends RemoteRoutineRunDataSource {
  _FakeRunDataSource(this.records) : super(null);

  final List<RemoteRoutineRunRecord> records;

  @override
  Future<List<RemoteRoutineRunRecord>> fetchAll(String ownerUserId) async =>
      records;
}

class _FakeSessionDataSource extends RemoteRoutineSessionDataSource {
  _FakeSessionDataSource() : super(null);

  @override
  Future<List<RemoteRoutineSessionRecord>> fetchAll(String ownerUserId) async =>
      const [];
}

void main() {
  group('Cloud access policy', () {
    test(
      'does not queue personal sync while signed out even with cached identity',
      () async {
        final database = LocalDb.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            authSessionProvider.overrideWithValue(
              const AuthSessionSummary(
                isSignedIn: false,
                userId: null,
                email: null,
                provider: null,
              ),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: '11111111-1111-1111-1111-111111111111',
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

        final policy = container.read(cloudAccessPolicyProvider);

        expect(policy.cachedOwnerUserId, isNotNull);
        expect(policy.personalCloudEnabled, isFalse);
        expect(policy.canQueuePersonalSync, isFalse);
        expect(policy.canUploadCloudChanges, isFalse);
      },
    );

    test(
      'does not queue personal sync with only locally cached consent',
      () async {
        final database = LocalDb.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        const auth = AuthSessionSummary(
          isSignedIn: true,
          userId: '11111111-1111-1111-1111-111111111111',
          email: 'jamie@example.com',
          provider: 'google',
        );

        final localConsent = CloudBackupConsentRecord(
          userId: '11111111-1111-1111-1111-111111111111',
          feature: cloudBackupConsentFeature,
          featureEnabled: true,
          appVersion: cloudBackupConsentAppVersion,
          privacyVersion: cloudBackupConsentPrivacyVersion,
          termsVersion: cloudBackupConsentTermsVersion,
          consentTextHash: cloudBackupConsentTextHash,
          consentedAt: DateTime.utc(2026, 5, 1),
          withdrawnAt: null,
        );
        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            authSessionProvider.overrideWithValue(auth),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: '11111111-1111-1111-1111-111111111111',
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                  entitlementStatus: EntitlementStatus.personalPremium,
                  entitlementSource: EntitlementSource.serverVerified,
                ),
              ),
            ),
            cloudBackupConsentControllerProvider.overrideWith(
              (ref) => _TestCloudBackupConsentController(
                CloudBackupConsentState(
                  isLoading: false,
                  record: localConsent,
                  lastError: 'Could not confirm remotely',
                  isRemoteConfirmed: false,
                ),
                prefs: prefs,
                auth: auth,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final policy = container.read(cloudAccessPolicyProvider);

        expect(policy.canQueuePersonalSync, isFalse);
        expect(policy.canUploadCloudChanges, isFalse);
      },
    );

    test(
      'waits for Supabase mirror before enabling cloud after RevenueCat unlock',
      () async {
        final database = LocalDb.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        const auth = AuthSessionSummary(
          isSignedIn: true,
          userId: '11111111-1111-1111-1111-111111111111',
          email: 'jamie@example.com',
          provider: 'apple',
        );

        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            authSessionProvider.overrideWithValue(auth),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: '11111111-1111-1111-1111-111111111111',
                  email: 'jamie@example.com',
                  authProvider: 'apple',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                  entitlementStatus: EntitlementStatus.personalPremium,
                  entitlementSource: EntitlementSource.revenueCat,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final access = container.read(personalCloudAccessProvider);
        final policy = container.read(cloudAccessPolicyProvider);

        expect(access.status, PersonalCloudAccessStatus.syncing);
        expect(access.label, 'Checking backup');
        expect(policy.personalCloudEnabled, isFalse);
        expect(policy.canQueuePersonalSync, isFalse);
      },
    );

    test('signed-out local Premium pauses backup without verification', () {
      final database = LocalDb.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          authSessionProvider.overrideWithValue(
            const AuthSessionSummary(
              isSignedIn: false,
              userId: null,
              email: null,
              provider: null,
            ),
          ),
          subscriptionAccountControllerProvider.overrideWith(
            (ref) => _TestSubscriptionAccountController(
              database,
              const SubscriptionAccountState(
                entitlementTier: UserTier.personalPremium,
                pendingTier: null,
                bootstrapStatus: BootstrapStatus.ready,
                userId: '11111111-1111-1111-1111-111111111111',
                email: 'jamie@example.com',
                authProvider: 'google',
                lastBootstrapAt: null,
                lastSyncAt: null,
                lastSyncError: null,
                entitlementStatus: EntitlementStatus.personalPremium,
                entitlementSource: EntitlementSource.revenueCat,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final access = container.read(personalCloudAccessProvider);
      final policy = container.read(cloudAccessPolicyProvider);

      expect(access.status, PersonalCloudAccessStatus.pausedSignedOut);
      expect(access.label, 'Backup is paused');
      expect(policy.personalCloudEnabled, isFalse);
      expect(policy.canQueuePersonalSync, isFalse);
    });

    test(
      'mirror verification failure blocks backup without downgrading Premium',
      () {
        final database = LocalDb.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        const auth = AuthSessionSummary(
          isSignedIn: true,
          userId: '11111111-1111-1111-1111-111111111111',
          email: 'jamie@example.com',
          provider: 'google',
        );

        final container = ProviderContainer(
          overrides: [
            localDbProvider.overrideWithValue(database),
            authSessionProvider.overrideWithValue(auth),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.ready,
                  userId: '11111111-1111-1111-1111-111111111111',
                  email: 'jamie@example.com',
                  authProvider: 'google',
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                  entitlementStatus: EntitlementStatus.personalPremium,
                  entitlementSource: EntitlementSource.revenueCat,
                  entitlementError:
                      'Premium is active, but backup could not be set up yet. Try again.',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final access = container.read(personalCloudAccessProvider);
        final policy = container.read(cloudAccessPolicyProvider);
        final entitlement = container.read(entitlementStateProvider);

        expect(access.status, PersonalCloudAccessStatus.verificationFailed);
        expect(entitlement.isPersonalPaid, isTrue);
        expect(policy.personalCloudEnabled, isFalse);
        expect(policy.canQueuePersonalSync, isFalse);
      },
    );
  });

  group('Cloud restore coordinator', () {
    late LocalDb database;
    late SyncOutboxRepository outbox;

    setUp(() {
      database = LocalDb.forTesting(NativeDatabase.memory());
      outbox = SyncOutboxRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'matches legacy local routine cloud ids and restores reminders as synced',
      () async {
        const ownerUserId = '11111111-1111-1111-1111-111111111111';
        const legacyCloudId = '1761243449440';
        final canonicalRoutineId = const Uuid().v5(
          Namespace.url.value,
          'vix.pebble/$legacyCloudId',
        );
        final remoteUpdatedAt = DateTime(2026, 2, 1, 10);

        await database.routineDao.insertOrUpdateRoutine(
          Routine(
            id: 1,
            title: 'Night reset',
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
            cloudId: legacyCloudId,
            ownerUserId: ownerUserId,
            syncStatus: 'synced',
            lastSyncedAt: DateTime(2026, 1, 1),
          ),
        );

        final coordinator = CloudRestoreCoordinator(
          database: database,
          remoteRoutineDataSource: _FakeRoutineDataSource([
            RemoteRoutineRecord(
              id: canonicalRoutineId,
              ownerUserId: ownerUserId,
              title: 'Night reset (remote)',
              stepsJson: '[]',
              iconKey: null,
              colorHex: null,
              isPinned: false,
              pinnedAt: null,
              version: 2,
              createdAt: DateTime(2026, 1, 1),
              updatedAt: remoteUpdatedAt,
            ),
          ]),
          remoteReminderDataSource: _FakeReminderDataSource([
            RemoteRoutineReminderRecord(
              id: '22222222-2222-4222-8222-222222222222',
              ownerUserId: ownerUserId,
              routineCloudId: canonicalRoutineId,
              dayOfWeek: 2,
              time: '8:30 AM',
              isEnabled: true,
              createdAt: remoteUpdatedAt,
              updatedAt: remoteUpdatedAt,
            ),
          ]),
          remoteRunDataSource: _FakeRunDataSource(const []),
          remoteSessionDataSource: _FakeSessionDataSource(),
          outbox: outbox,
        );

        await coordinator.bootstrapAndMerge(ownerUserId);

        final routines = await database.routineDao.getAllRoutines();
        final reminders = await database.routineReminderDao.getAllReminders();

        expect(routines, hasLength(1));
        expect(routines.single.id, 1);
        expect(routines.single.title, 'Night reset (remote)');
        expect(routines.single.cloudId, canonicalRoutineId);
        expect(reminders, hasLength(1));
        expect(reminders.single.routineId, 1);
        expect(reminders.single.syncStatus, 'synced');
        expect(reminders.single.updatedAt, remoteUpdatedAt);
        expect(reminders.single.ownerUserId, ownerUserId);
      },
    );

    test(
      'maps restored run routine references back to local routine ids',
      () async {
        const ownerUserId = '11111111-1111-1111-1111-111111111111';
        const routineCloudId = '33333333-3333-4333-8333-333333333333';

        await database.routineDao.insertOrUpdateRoutine(
          Routine(
            id: 7,
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

        final coordinator = CloudRestoreCoordinator(
          database: database,
          remoteRoutineDataSource: _FakeRoutineDataSource(const []),
          remoteReminderDataSource: _FakeReminderDataSource(const []),
          remoteRunDataSource: _FakeRunDataSource([
            RemoteRoutineRunRecord(
              id: '44444444-4444-4444-8444-444444444444',
              ownerUserId: ownerUserId,
              routineId: routineCloudId,
              routineTitle: 'Morning startup',
              finishedAt: DateTime(2026, 2, 2),
              stepCompletionData: jsonEncode({'steps': const []}),
              updatedAt: DateTime(2026, 2, 2),
            ),
          ]),
          remoteSessionDataSource: _FakeSessionDataSource(),
          outbox: outbox,
        );

        await coordinator.bootstrapAndMerge(ownerUserId);

        final runs = await database.routineRunDao.getAllRuns();
        expect(runs, hasLength(1));
        expect(runs.single.routineId, '7');
        expect(runs.single.syncStatus, 'synced');
      },
    );
  });
}
