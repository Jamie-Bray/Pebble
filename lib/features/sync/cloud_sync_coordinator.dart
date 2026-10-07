import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_reminder_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/data/entitlement_flow_messages.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/guidance_audio_cloud_backup.dart';
import 'package:pebble_routines/features/sync/local_data_ownership_guard.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

enum ManualSyncResultType {
  blockedSignedOut,
  blockedNoEntitlement,
  blockedConsentRequired,
  blockedAccountSwitch,
  blockedOffline,
  noChanges,
  synced,
  partialRetryScheduled,
  failed,
}

class ManualSyncResult {
  const ManualSyncResult({required this.type, required this.message});

  final ManualSyncResultType type;
  final String message;
}

class CloudSyncRuntimeState {
  const CloudSyncRuntimeState({
    required this.isRunning,
    required this.pendingCount,
    required this.nextRetryAt,
  });

  const CloudSyncRuntimeState.idle()
    : isRunning = false,
      pendingCount = 0,
      nextRetryAt = null;

  final bool isRunning;
  final int pendingCount;
  final DateTime? nextRetryAt;
}

class CloudSyncCoordinator {
  CloudSyncCoordinator({
    required Ref ref,
    required LocalDb database,
    required SyncOutboxRepository outbox,
    required RemoteRoutineDataSource remoteRoutineDataSource,
    required RemoteRoutineReminderDataSource remoteReminderDataSource,
    required RemoteRoutineRunDataSource remoteRunDataSource,
    required RemoteRoutineSessionDataSource remoteSessionDataSource,
    required RoutineSessionProofStorage proofStorage,
    required GuidanceAudioCloudBackup guidanceAudioBackup,
  }) : _ref = ref,
       _database = database,
       _outbox = outbox,
       _remoteRoutineDataSource = remoteRoutineDataSource,
       _remoteReminderDataSource = remoteReminderDataSource,
       _remoteRunDataSource = remoteRunDataSource,
       _remoteSessionDataSource = remoteSessionDataSource,
       _proofStorage = proofStorage,
       _guidanceAudioBackup = guidanceAudioBackup;

  final Ref _ref;
  final LocalDb _database;
  final SyncOutboxRepository _outbox;
  final RemoteRoutineDataSource _remoteRoutineDataSource;
  final RemoteRoutineReminderDataSource _remoteReminderDataSource;
  final RemoteRoutineRunDataSource _remoteRunDataSource;
  final RemoteRoutineSessionDataSource _remoteSessionDataSource;
  final RoutineSessionProofStorage _proofStorage;
  final GuidanceAudioCloudBackup _guidanceAudioBackup;

  bool _isRunning = false;

  /// The pass in progress, if any. Only one pass runs at a time.
  Future<ManualSyncResult>? _activePass;

  /// Set when work is requested while a pass runs; the pass (or a follow-up
  /// pass) picks it up instead of dropping it.
  bool _rerunRequested = false;
  bool _inForeground = false;
  bool _disposed = false;
  Timer? _retryTimer;
  Timer? _foregroundTimer;
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  Future<void> kick() async {
    // Read the plan only after it has loaded: the Free default would delete a
    // Premium user's older photos and history at start-up.
    await _ref.read(subscriptionAccountControllerProvider.notifier).whenLoaded;
    final hasPremiumHistory = _ref.read(
      accountHasPremiumHistoryRetentionProvider,
    );
    final historyRetention = _ref.read(accountHistoryRetentionProvider);
    await _syncInternal(userInitiated: false);
    await _proofStorage.enforceRetentionPolicy(isPremium: hasPremiumHistory);

    // Prune finished sessions older than 24 hours (never an active one).
    final sessionCutoff = DateTime.now().subtract(const Duration(hours: 24));
    await _database.routineSessionDao.deleteSessionsOlderThan(sessionCutoff);

    // Bring back voice prompts that a restore left without a local file.
    // This runs right after every bootstrap merge, so the restore itself
    // never waits on audio.
    await _restoreMissingGuidanceAudio();

    // Run garbage collection for orphaned voice clips
    await _runGuidanceAudioGarbageCollection();

    if (!hasPremiumHistory) {
      final cutoff = DateTime.now().subtract(historyRetention);
      await _database.routineRunDao.deleteRunsOlderThan(cutoff);
    }
  }

  Future<void> _runGuidanceAudioGarbageCollection() async {
    final activePaths = await _activeGuidanceAudioPaths();
    await _ref
        .read(guidanceAudioStorageProvider)
        .cleanupOrphanedAudio(activePaths);
  }

  /// Voice clip paths referenced by published routines or open drafts.
  Future<Set<String>> _activeGuidanceAudioPaths() async {
    final activePaths = <String>{};

    // Extract from published routines
    final routines = await _database.routineDao.getAllRoutines();
    for (final routine in routines) {
      activePaths.addAll(
        GuidanceAudioCloudBackup.localPathsIn(routine.stepsJson),
      );
    }

    // Extract from active drafts, including edit drafts
    final allDraftRows = await _database
        .select(_database.routineComposerDrafts)
        .get();
    for (final draft in allDraftRows) {
      activePaths.addAll(
        GuidanceAudioCloudBackup.localPathsIn(draft.stepsJson),
      );
    }
    return activePaths;
  }

  Future<void> _restoreMissingGuidanceAudio() async {
    final auth = _ref.read(authSessionProvider);
    final userId = auth.userId;
    if (!auth.isSignedIn || userId == null || userId.isEmpty) return;
    try {
      final routines = await _database.routineDao.getAllRoutines();
      await _guidanceAudioBackup.restoreMissing(
        stepsJsons: routines.map((routine) => routine.stepsJson),
        ownerUserId: userId,
      );
    } catch (error) {
      developer.log(
        'Voice prompt restore pass failed: $error',
        name: 'CloudSyncCoordinator',
      );
    }
  }

  /// "Back up now". If a pass is already running this waits for it and then
  /// runs a fresh one, so a change saved a moment ago is never skipped.
  Future<ManualSyncResult> runManualSync() {
    return _syncInternal(userInitiated: true);
  }

  /// The entry point screens call for "Back up now".
  Future<ManualSyncResult> backUpNow() => runManualSync();

  /// Called by the app as it moves between foreground and background. While
  /// in the foreground, a periodic check retries anything still waiting.
  void setAppInForeground(bool inForeground) {
    _inForeground = inForeground;
    if (!inForeground) {
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
      return;
    }
    _foregroundTimer ??= Timer.periodic(foregroundRetryInterval, (_) {
      unawaited(_foregroundTick());
    });
  }

  /// How often the foreground check looks for changes still waiting.
  static const foregroundRetryInterval = Duration(minutes: 3);

  Future<void> _foregroundTick() async {
    if (!_inForeground || _disposed || _activePass != null) return;
    try {
      if ((await _outbox.pendingItems()).isEmpty) return;
      await _syncInternal(userInitiated: false);
    } catch (error) {
      developer.log(
        'Foreground backup check failed: $error',
        name: 'CloudSyncCoordinator',
      );
    }
  }

  Future<ManualSyncResult> _syncInternal({required bool userInitiated}) async {
    if (_activePass != null) {
      if (!userInitiated) {
        // The running pass picks this work up before it finishes.
        _rerunRequested = true;
        return const ManualSyncResult(
          type: ManualSyncResultType.synced,
          message: 'Pebble is already backing up your routines.',
        );
      }
      // "Back up now" during an automatic pass: let it finish, then run a
      // pass of our own so nothing saved in between is missed.
      while (_activePass != null) {
        try {
          await _activePass;
        } catch (_) {}
      }
    }

    final completer = Completer<ManualSyncResult>();
    _activePass = completer.future;
    _rerunRequested = false;
    ManualSyncResult result;
    try {
      result = await _runPass(userInitiated: userInitiated);
      completer.complete(result);
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      // Nobody else awaits this future unless a manual pass is waiting.
      unawaited(completer.future.catchError((_) => _failedResult));
      rethrow;
    } finally {
      _activePass = null;
    }
    if (_rerunRequested && !_disposed) {
      _rerunRequested = false;
      // Work arrived after the pass last looked: run again rather than
      // waiting for a timer.
      unawaited(
        _syncInternal(userInitiated: false).then<void>(
          (_) {},
          onError: (Object error) => developer.log(
            'Follow-up backup pass failed: $error',
            name: 'CloudSyncCoordinator',
          ),
        ),
      );
    }
    return result;
  }

  static const _failedResult = ManualSyncResult(
    type: ManualSyncResultType.failed,
    message: 'The last backup didn\'t finish. Try again.',
  );

  /// Most rounds one pass makes over newly due work (edits saved during the
  /// pass, items another item queued) before leaving the rest to a timer.
  static const _maxRoundsPerPass = 5;

  Future<ManualSyncResult> _runPass({required bool userInitiated}) async {
    final auth = _ref.read(authSessionProvider);
    final policy = _ref.read(cloudAccessPolicyProvider);
    final userId = policy.cachedOwnerUserId;

    if (!auth.isSignedIn) {
      await _refreshRuntimeState(scheduleRetry: false);
      return const ManualSyncResult(
        type: ManualSyncResultType.blockedSignedOut,
        message: 'Sign in again and backup will carry on.',
      );
    }

    if (!policy.canUploadCloudChanges || userId == null || userId.isEmpty) {
      await _refreshRuntimeState(scheduleRetry: false);
      final access = _ref.read(personalCloudAccessProvider);
      if (access.status == PersonalCloudAccessStatus.consentRequired) {
        return const ManualSyncResult(
          type: ManualSyncResultType.blockedConsentRequired,
          message: 'Turn on backup before Pebble saves anything online.',
        );
      }
      if (access.status == PersonalCloudAccessStatus.accountSwitchBlocked) {
        return ManualSyncResult(
          type: ManualSyncResultType.blockedAccountSwitch,
          message:
              access.detail ??
              'Pebble will keep existing local data local until you choose how to handle this account.',
        );
      }
      if (access.status == PersonalCloudAccessStatus.expiredGrace) {
        return const ManualSyncResult(
          type: ManualSyncResultType.blockedNoEntitlement,
          message: 'Backup stopped when Premium ended.',
        );
      }
      if (access.status == PersonalCloudAccessStatus.verificationFailed) {
        return const ManualSyncResult(
          type: ManualSyncResultType.failed,
          message: EntitlementFlowMessages.backupSetupFailedFromAccount,
        );
      }
      if (access.status == PersonalCloudAccessStatus.offFree ||
          access.status == PersonalCloudAccessStatus.offSignedInNoEntitlement) {
        return const ManualSyncResult(
          type: ManualSyncResultType.blockedNoEntitlement,
          message: 'Backup comes with Premium.',
        );
      }
      return _failedResult;
    }

    var ownership = await LocalDataOwnershipGuard.inspect(
      database: _database,
      signedInUserId: userId,
    );
    if (ownership.state == LocalDataOwnershipState.unownedOnly) {
      // Reaching this point requires sign-in, verified Premium, and current
      // consent (policy.canUploadCloudChanges), so never-owned rows can link
      // to the signed-in account without another prompt. Different-owner data
      // still blocks below.
      ownership = await LocalDataOwnershipGuard.linkUnownedLocalData(
        database: _database,
        signedInUserId: userId,
      );
    }
    if (ownership.blocksCloudSync) {
      await _refreshRuntimeState(scheduleRetry: false);
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(ownership.userFacingMessage);
      return ManualSyncResult(
        type: ManualSyncResultType.blockedAccountSwitch,
        message: ownership.userFacingMessage,
      );
    }

    if (userInitiated) {
      // "Back up now" makes everything due straight away. Failure counts
      // stay, so a change that still fails stays flagged.
      await _outbox.resetRetrySchedule();
    }
    // Anything saved while queueing was closed (for example before consent
    // was confirmed this session) is picked up here. It never resets rows
    // that are already waiting.
    await _queueUnsyncedLocalBaseline();

    var syncedCount = 0;
    var failedCount = 0;
    var sawOfflineError = false;
    String? lastFailureMessage;
    final failedIds = <String>{};

    _isRunning = true;
    try {
      for (var round = 0; round < _maxRoundsPerPass; round++) {
        _rerunRequested = false;
        final dueItems = (await _outbox.dueItems())
            .where((item) => !failedIds.contains(item.id))
            .toList();
        if (dueItems.isEmpty) break;
        final prioritizedItems = dueItems..sort(_compareSyncPriority);
        _setRuntimeState(
          CloudSyncRuntimeState(
            isRunning: true,
            pendingCount: (await _outbox.pendingItems()).length,
            nextRetryAt: null,
          ),
        );
        for (final item in prioritizedItems) {
          try {
            await _processItem(item, userId);
            // A newer edit saved during the upload keeps the row queued (it
            // is due again straight away).
            await _outbox.completeIfUnchanged(item);
            syncedCount += 1;
          } on _DeferredSyncItem catch (deferred) {
            await _outbox.defer(item.id, deferred.reason);
            failedIds.add(item.id);
          } catch (error, stackTrace) {
            developer.log(
              'Backup failed for ${item.entityType.name}:${item.entityId} '
              '(attempt ${item.attemptCount + 1}, ${error.runtimeType}): '
              '$error',
              name: 'CloudSyncCoordinator',
              error: error,
              stackTrace: stackTrace,
            );
            failedCount += 1;
            failedIds.add(item.id);
            sawOfflineError = sawOfflineError || _looksOffline(error);
            lastFailureMessage = _failureMessageForError(error);
            await _outbox.markRetry(item.id, error, item.attemptCount + 1);
          }
        }
      }
    } finally {
      _isRunning = false;
    }

    final remaining = await _outbox.pendingItems();
    final accountController = _ref.read(
      subscriptionAccountControllerProvider.notifier,
    );
    if (failedCount == 0 && remaining.isEmpty) {
      await accountController.noteBackupPassClean(
        reachedServer: syncedCount > 0,
      );
    } else if (failedCount > 0) {
      await accountController.noteBackupPassFailed(
        lastFailureMessage ?? _failedResult.message,
      );
    }
    await _refreshRuntimeState(pendingItems: remaining);

    if (failedCount == 0) {
      if (remaining.isNotEmpty) {
        return const ManualSyncResult(
          type: ManualSyncResultType.partialRetryScheduled,
          message: 'Some changes are still waiting. Pebble will keep trying.',
        );
      }
      return ManualSyncResult(
        type: syncedCount > 0
            ? ManualSyncResultType.synced
            : ManualSyncResultType.noChanges,
        message: syncedCount > 0
            ? 'Everything is up to date.'
            : userInitiated
            ? 'No new changes to back up.'
            : 'Everything is up to date.',
      );
    }

    if (syncedCount > 0) {
      return const ManualSyncResult(
        type: ManualSyncResultType.partialRetryScheduled,
        message: 'Some changes are still waiting. Pebble will keep trying.',
      );
    }

    if (sawOfflineError) {
      return const ManualSyncResult(
        type: ManualSyncResultType.blockedOffline,
        message: 'You\'re offline. Changes will back up later.',
      );
    }

    return ManualSyncResult(
      type: ManualSyncResultType.failed,
      message: lastFailureMessage ?? _failedResult.message,
    );
  }

  String _toSupabaseUuid(String localId) {
    if (_looksLikeUuid(localId)) return localId.toLowerCase();
    return _uuid.v5(Namespace.url.value, 'vix.pebble/$localId');
  }

  int _compareSyncPriority(SyncOutboxItem a, SyncOutboxItem b) {
    final entityOrder = <SyncEntityType, int>{
      SyncEntityType.routine: 0,
      SyncEntityType.reminder: 1,
      SyncEntityType.run: 2,
      SyncEntityType.session: 3,
      SyncEntityType.proofAsset: 4,
      SyncEntityType.guidanceAudio: 5,
    };
    final operationOrder = <SyncOperation, int>{
      SyncOperation.upsert: 0,
      SyncOperation.upload: 1,
      SyncOperation.delete: 2,
    };
    final entityCompare = (entityOrder[a.entityType] ?? 99).compareTo(
      entityOrder[b.entityType] ?? 99,
    );
    if (entityCompare != 0) {
      return entityCompare;
    }
    final operationCompare = (operationOrder[a.operation] ?? 99).compareTo(
      operationOrder[b.operation] ?? 99,
    );
    if (operationCompare != 0) {
      return operationCompare;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value.trim());

  /// Queues every local row that is not in the backup yet. Runs at the start
  /// of every pass: it only adds missing rows (see
  /// [SyncOutboxRepository.ensureQueued]), so rows already waiting keep their
  /// backoff and failure count.
  Future<void> _queueUnsyncedLocalBaseline() async {
    final routines = await _database.routineDao.getAllRoutines();
    for (final routine in routines) {
      if (!_isRoutineBackedUp(routine)) {
        await _outbox.ensureQueued(
          entityType: SyncEntityType.routine,
          entityId: routine.id.toString(),
          operation: SyncOperation.upsert,
        );
      } else if (await _guidanceAudioBackup.needsUpload(
        stepsJson: routine.stepsJson,
        ownerUserId: routine.ownerUserId!,
      )) {
        // Routines backed up before voice prompts were: only the audio
        // needs to go up.
        await _outbox.ensureQueued(
          entityType: SyncEntityType.guidanceAudio,
          entityId: routine.id.toString(),
          operation: SyncOperation.upload,
        );
      }
    }

    final reminders = await _database.routineReminderDao.getAllReminders();
    for (final reminder in reminders) {
      if (reminder.syncStatus != 'synced' ||
          reminder.cloudId == null ||
          reminder.cloudId!.isEmpty ||
          reminder.ownerUserId == null ||
          reminder.ownerUserId!.isEmpty) {
        await _outbox.ensureQueued(
          entityType: SyncEntityType.reminder,
          entityId: reminder.id.toString(),
          operation: SyncOperation.upsert,
        );
      }
    }

    final runs = await _database.routineRunDao.getAllRuns();
    for (final run in runs) {
      if (run.syncStatus != 'synced' ||
          run.ownerUserId == null ||
          run.ownerUserId!.isEmpty) {
        await _outbox.ensureQueued(
          entityType: SyncEntityType.run,
          entityId: run.id,
          operation: SyncOperation.upsert,
        );
      }
    }

    final sessions = await _database.routineSessionDao.getAllSessions();
    for (final session in sessions) {
      if (_sessionNeedsSync(session)) {
        await _outbox.ensureQueued(
          entityType: SyncEntityType.session,
          entityId: session.sessionId,
          operation: SyncOperation.upsert,
        );
      }
    }
  }

  /// Whether the routine row as it is now is in the backup.
  bool _isRoutineBackedUp(Routine routine) {
    return routine.syncStatus == 'synced' &&
        routine.cloudId != null &&
        routine.cloudId!.isNotEmpty &&
        routine.ownerUserId != null &&
        routine.ownerUserId!.isNotEmpty;
  }

  bool _sessionNeedsSync(RoutineSessionRow session) {
    if (session.ownerUserId == null || session.ownerUserId!.isEmpty) {
      return true;
    }
    final metadataJson = session.syncMetadataJson;
    if (metadataJson == null || metadataJson.isEmpty) {
      return false;
    }
    try {
      final decoded = jsonDecode(metadataJson);
      return decoded is Map && decoded['needsSync'] == true;
    } catch (_) {
      return true;
    }
  }

  int? _toSignedInt32(int? value) {
    if (value == null) {
      return null;
    }
    return value.toUnsigned(32).toSigned(32);
  }

  /// The routine's cloud id. A routine without one gets a random id that is
  /// saved on the device before anything is uploaded, so a retry reuses it.
  /// It must not be derived from the local row number: those start at 1 on
  /// every device, so two devices would claim the same cloud row.
  Future<String> _routineCloudId(Routine routine) async {
    final existing = routine.cloudId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return _toSupabaseUuid(existing);
    }
    final fresh = _uuid.v4();
    final saved = await _database.routineDao.assignCloudIdIfMissing(
      routine.id,
      fresh,
    );
    return _toSupabaseUuid(saved == null || saved.isEmpty ? fresh : saved);
  }

  Future<String> _reminderCloudId(RoutineReminder reminder) async {
    final existing = reminder.cloudId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return _toSupabaseUuid(existing);
    }
    final fresh = _uuid.v4();
    final saved = await _database.routineReminderDao.assignCloudIdIfMissing(
      reminder.id,
      fresh,
    );
    return _toSupabaseUuid(saved == null || saved.isEmpty ? fresh : saved);
  }

  Future<Routine?> _resolveRoutineForRun(String routineReference) async {
    final localRoutineId = int.tryParse(routineReference);
    if (localRoutineId != null) {
      return _database.routineDao.getRoutineById(localRoutineId);
    }
    if (_looksLikeUuid(routineReference)) {
      return _database.routineDao.getRoutineByCloudId(routineReference);
    }
    return null;
  }

  Future<void> _processItem(SyncOutboxItem item, String ownerUserId) async {
    switch (item.entityType) {
      case SyncEntityType.routine:
        await _syncRoutineItem(item, ownerUserId);
        return;
      case SyncEntityType.reminder:
        await _syncReminderItem(item, ownerUserId);
        return;
      case SyncEntityType.run:
        await _syncRunItem(item, ownerUserId);
        return;
      case SyncEntityType.session:
        await _syncSessionItem(item, ownerUserId);
        return;
      case SyncEntityType.proofAsset:
        await _syncRunProofItem(item, ownerUserId);
        return;
      case SyncEntityType.guidanceAudio:
        await _syncGuidanceAudioItem(item, ownerUserId);
        return;
    }
  }

  Future<void> _syncRoutineItem(SyncOutboxItem item, String ownerUserId) async {
    if (item.operation == SyncOperation.delete) {
      final cloudId = item.payload?['cloudId']?.toString();
      if (cloudId != null && cloudId.isNotEmpty) {
        await _remoteRoutineDataSource.delete(_toSupabaseUuid(cloudId));
      }
      return;
    }

    final routineId = int.tryParse(item.entityId);
    if (routineId == null) return;
    final routine = await _database.routineDao.getRoutineById(routineId);
    if (routine == null) return;
    await _uploadRoutine(routine, ownerUserId);
  }

  Future<void> _uploadRoutine(Routine routine, String ownerUserId) async {
    // Voice prompts go up first so the routine row carries their remote keys.
    // A clip that fails must not hold back the routine itself: it moves to
    // its own outbox item, which retries with the usual backoff.
    final audio = await _uploadRoutineGuidanceAudio(routine, ownerUserId);
    await _upsertRoutine(audio.routine, ownerUserId);
    if (audio.failure != null) {
      await _outbox.ensureQueued(
        entityType: SyncEntityType.guidanceAudio,
        entityId: routine.id.toString(),
        operation: SyncOperation.upload,
      );
    }
  }

  /// Makes sure [routine] is on the server, uploading it now if it never
  /// went up. Returns the routine as stored after that, or null when the
  /// upload failed (the routine stays queued and retries by itself).
  Future<Routine?> _ensureRoutineBackedUp(
    Routine routine,
    String ownerUserId,
  ) async {
    if (_isRoutineBackedUp(routine)) return routine;
    await _outbox.ensureQueued(
      entityType: SyncEntityType.routine,
      entityId: routine.id.toString(),
      operation: SyncOperation.upsert,
    );
    try {
      await _uploadRoutine(routine, ownerUserId);
    } catch (error) {
      developer.log(
        'Routine ${routine.id} could not back up ahead of its reminder '
        '(${error.runtimeType}): $error',
        name: 'CloudSyncCoordinator',
      );
      return null;
    }
    return await _database.routineDao.getRoutineById(routine.id) ?? routine;
  }

  Future<void> _upsertRoutine(Routine routine, String ownerUserId) async {
    final cloudId = await _routineCloudId(routine);
    final payload = {
      'id': cloudId,
      'owner_user_id': ownerUserId,
      'title': routine.title,
      'steps_json': routine.stepsJson,
      'icon_key': routine.emoji,
      'color_hex': _toSignedInt32(routine.colorHex),
      'is_pinned': routine.isPinned,
      'pinned_at': routine.pinnedAt?.toIso8601String(),
      'version': routine.version,
      'created_at': routine.createdAt.toIso8601String(),
      'updated_at': routine.updatedAt.toIso8601String(),
    };
    await _remoteRoutineDataSource.upsert(payload);
    await _database.routineDao.markRoutineSynced(
      id: routine.id,
      cloudId: cloudId,
      ownerUserId: ownerUserId,
      syncedAt: DateTime.now(),
    );
  }

  Future<void> _syncGuidanceAudioItem(
    SyncOutboxItem item,
    String ownerUserId,
  ) async {
    if (item.operation == SyncOperation.delete) {
      final objectKey = item.payload?['objectKey']?.toString() ?? item.entityId;
      if (!GuidanceAudioCloudBackup.isOwnedBy(objectKey, ownerUserId)) return;
      // A duplicated routine or an open draft can still use the same clip.
      final fileName = p.basename(objectKey);
      final activePaths = await _activeGuidanceAudioPaths();
      if (activePaths.any((path) => p.basename(path) == fileName)) return;
      await _guidanceAudioBackup.deleteRemote(objectKey);
      return;
    }

    final routineId = int.tryParse(item.entityId);
    if (routineId == null) return;
    final routine = await _database.routineDao.getRoutineById(routineId);
    if (routine == null) return;
    final audio = await _uploadRoutineGuidanceAudio(routine, ownerUserId);
    if (!identical(audio.routine, routine)) {
      await _upsertRoutine(audio.routine, ownerUserId);
    }
    final failure = audio.failure;
    if (failure != null) {
      throw failure;
    }
  }

  /// Uploads the routine's voice prompts that have no backup yet and records
  /// their remote keys in the local routine.
  Future<({Routine routine, Object? failure})> _uploadRoutineGuidanceAudio(
    Routine routine,
    String ownerUserId,
  ) async {
    final result = await _guidanceAudioBackup.uploadPending(
      stepsJson: routine.stepsJson,
      ownerUserId: ownerUserId,
      entityId: await _routineCloudId(routine),
    );
    if (result.uploadedKeys.isEmpty) {
      return (routine: routine, failure: result.failure);
    }
    // Re-read so an edit saved while the clips were uploading is kept.
    final latest =
        await _database.routineDao.getRoutineById(routine.id) ?? routine;
    final updated = latest.copyWith(
      stepsJson: GuidanceAudioCloudBackup.applyRemoteKeys(
        latest.stepsJson,
        result.uploadedKeys,
      ),
      // Newer, so other devices take the keyed copy when they merge.
      updatedAt: DateTime.now(),
    );
    await _database.routineDao.insertOrUpdateRoutine(updated);
    return (routine: updated, failure: result.failure);
  }

  Future<void> _syncReminderItem(
    SyncOutboxItem item,
    String ownerUserId,
  ) async {
    if (item.operation == SyncOperation.delete) {
      final cloudId = item.payload?['cloudId']?.toString();
      if (cloudId != null && cloudId.isNotEmpty) {
        await _remoteReminderDataSource.delete(_toSupabaseUuid(cloudId));
      }
      return;
    }

    final reminderId = int.tryParse(item.entityId);
    if (reminderId == null) return;
    final reminder = await _database.routineReminderDao.getReminderById(
      reminderId,
    );
    if (reminder == null) return;
    final routine = await _database.routineDao.getRoutineById(
      reminder.routineId,
    );
    if (routine == null) {
      // Routine no longer exists locally. The reminder can't be uploaded (FK),
      // and keeping it around will keep the outbox stuck.
      await _database.routineReminderDao.deleteReminder(reminder.id);
      return;
    }
    // The server only accepts a reminder whose routine is already backed up
    // (routine_reminders.routine_id references routines.id). A routine that
    // never went up would make this fail forever, so send the routine first.
    final latestRoutine = await _ensureRoutineBackedUp(routine, ownerUserId);
    if (latestRoutine == null) {
      throw _DeferredSyncItem(
        'Waiting for routine ${routine.id} to back up first',
      );
    }
    final routineCloudId = await _routineCloudId(latestRoutine);
    final cloudId = await _reminderCloudId(reminder);
    await _remoteReminderDataSource.upsert({
      'id': cloudId,
      'owner_user_id': ownerUserId,
      'routine_id': routineCloudId,
      'day_of_week': reminder.dayOfWeek,
      'time': reminder.time,
      'is_enabled': reminder.isEnabled,
      'created_at': reminder.createdAt.toIso8601String(),
      'updated_at': reminder.updatedAt.toIso8601String(),
    });
    await _database.routineReminderDao.markReminderSynced(
      reminderId: reminder.id,
      cloudId: cloudId,
      ownerUserId: ownerUserId,
      syncedAt: DateTime.now(),
    );
  }

  Future<void> _syncRunItem(SyncOutboxItem item, String ownerUserId) async {
    if (item.operation == SyncOperation.delete) {
      await _remoteRunDataSource.delete(_toSupabaseUuid(item.entityId));
      return;
    }

    final run = await _database.routineRunDao.getRunById(item.entityId);
    if (run == null) return;

    final proofs = await _uploadRunProofs(run, ownerUserId);
    await _upsertRun(proofs.run, ownerUserId);
    if (proofs.waitingPhotos > 0) {
      // A photo held back (for example by the upload allowance) goes up on
      // a later pass without holding back the run itself.
      await _outbox.ensureQueued(
        entityType: SyncEntityType.proofAsset,
        entityId: run.id,
        operation: SyncOperation.upload,
      );
    }
  }

  /// Retries the photos of a run that went up without some of them.
  Future<void> _syncRunProofItem(
    SyncOutboxItem item,
    String ownerUserId,
  ) async {
    final run = await _database.routineRunDao.getRunById(item.entityId);
    if (run == null) return;
    final proofs = await _uploadRunProofs(run, ownerUserId);
    if (!identical(proofs.run, run)) {
      await _upsertRun(proofs.run, ownerUserId);
    }
    if (proofs.waitingPhotos > 0) {
      throw StateError(
        '${proofs.waitingPhotos} proof photo(s) still waiting to upload',
      );
    }
  }

  Future<void> _upsertRun(RoutineRun syncedRun, String ownerUserId) async {
    final routine = await _resolveRoutineForRun(syncedRun.routineId);
    final routineCloudId = await _routineCloudIdForRun(
      syncedRun.routineId,
      routine,
    );
    final payload = {
      'id': _toSupabaseUuid(syncedRun.id),
      'owner_user_id': ownerUserId,
      'routine_id': routineCloudId == null || routineCloudId.isEmpty
          ? null
          : routineCloudId,
      'routine_title': syncedRun.routineTitle,
      'finished_at': syncedRun.finishedAt.toIso8601String(),
      'step_completion_data': syncedRun.stepCompletionData,
      'updated_at': syncedRun.updatedAt.toIso8601String(),
    };
    await _remoteRunDataSource.upsert(payload);
    await _database.routineRunDao.markRunSynced(
      id: syncedRun.id,
      ownerUserId: ownerUserId,
      syncedAt: DateTime.now(),
      syncMetadataJson: syncedRun.syncMetadataJson,
    );
  }

  Future<String?> _routineCloudIdForRun(
    String routineReference,
    Routine? routine,
  ) async {
    if (routine != null) {
      return _routineCloudId(routine);
    }
    final trimmed = routineReference.trim();
    // The routine is gone from this device. A cloud id is still a valid
    // reference; a local row number is not, so the run keeps only its title.
    return _looksLikeUuid(trimmed) ? _toSupabaseUuid(trimmed) : null;
  }

  Future<void> _syncSessionItem(SyncOutboxItem item, String ownerUserId) async {
    if (item.operation == SyncOperation.delete) {
      await _remoteSessionDataSource.delete(_toSupabaseUuid(item.entityId));
      return;
    }

    final row = await _database.routineSessionDao.getSessionById(item.entityId);
    if (row == null) return;
    final session = _sessionFromRow(row);
    final syncedSession = await _uploadSessionProofs(session, ownerUserId);
    // A session taken over from another account carries its own cloud id
    // (see LocalDataOwnershipGuard); every other session uses its local id.
    final remoteSessionId = _toSupabaseUuid(
      session.syncMetadata?.remoteSessionId ?? session.sessionId,
    );
    final remotePayload = {
      'id': remoteSessionId,
      'owner_user_id': ownerUserId,
      'payload_json': syncedSession.toJson(),
      'updated_at': syncedSession.updatedAt.toIso8601String(),
    };
    await _remoteSessionDataSource.upsert(remotePayload);
    final syncedMetadata =
        (syncedSession.syncMetadata ??
                const RoutineSessionSyncMetadata(needsSync: false))
            .copyWith(
              needsSync: false,
              remoteSessionId: remoteSessionId,
              lastSyncedAt: DateTime.now(),
              lastSyncAttemptAt: DateTime.now(),
            );
    await _database.routineSessionDao.insertOrUpdateSession(
      RoutineSessionRow(
        sessionId: row.sessionId,
        routineId: row.routineId,
        routineTitleSnapshot: row.routineTitleSnapshot,
        workspaceId: row.workspaceId,
        ownerUserId: ownerUserId,
        storageScope: row.storageScope,
        startedAt: row.startedAt,
        updatedAt: DateTime.now(),
        status: row.status,
        currentStepIndex: row.currentStepIndex,
        totalStepCount: row.totalStepCount,
        baseRoutineVersion: row.baseRoutineVersion,
        stepStatesJson: jsonEncode(
          syncedSession.stepStates.map((state) => state.toJson()).toList(),
        ),
        routineSnapshotJson: row.routineSnapshotJson,
        syncMetadataJson: jsonEncode(syncedMetadata.toJson()),
        completedAt: row.completedAt,
        discardedAt: row.discardedAt,
      ),
    );
  }

  /// Uploads the run's photos that have no backup yet. [waitingPhotos]
  /// counts photos still held back for now (they can succeed on a later
  /// pass); a photo whose file is gone is not counted.
  Future<({RoutineRun run, int waitingPhotos})> _uploadRunProofs(
    RoutineRun run,
    String ownerUserId,
  ) async {
    final raw = run.stepCompletionData;
    if (raw == null || raw.isEmpty) {
      return (run: run, waitingPhotos: 0);
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return (run: run, waitingPhotos: 0);
    }
    final steps = (decoded['steps'] as List<dynamic>? ?? const []);
    var changed = false;
    var waitingPhotos = 0;
    final updatedSteps = <Map<String, dynamic>>[];
    for (var index = 0; index < steps.length; index++) {
      final step = Map<String, dynamic>.from(steps[index] as Map);
      final proofAssets = (step['proofAssets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => RoutineSessionProofAsset.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      if (proofAssets.isEmpty) {
        updatedSteps.add(step);
        continue;
      }

      final updatedAssets = <RoutineSessionProofAsset>[];
      for (final asset in proofAssets) {
        if (_hasOwnBackup(asset, ownerUserId)) {
          updatedAssets.add(asset);
          continue;
        }
        final uploaded = await _proofStorage.uploadProofAsset(
          asset: asset,
          ownerUserId: ownerUserId,
          entityType: 'runs',
          entityId: run.id,
        );
        if (uploaded.uploadStatus == ProofUploadStatus.pendingUpload) {
          waitingPhotos += 1;
        }
        updatedAssets.add(uploaded);
        if (uploaded.uploadStatus != asset.uploadStatus ||
            uploaded.remoteObjectKey != asset.remoteObjectKey) {
          changed = true;
        }
      }
      step['proofAssets'] = updatedAssets
          .map((asset) => asset.toJson())
          .toList();
      step['photos'] = updatedAssets
          .map((asset) => asset.localRelativePath)
          .toList();
      updatedSteps.add(step);
    }

    if (!changed) {
      return (run: run, waitingPhotos: waitingPhotos);
    }
    decoded['steps'] = updatedSteps;
    final updatedRun = RoutineRun(
      id: run.id,
      routineId: run.routineId,
      routineTitle: run.routineTitle,
      finishedAt: run.finishedAt,
      stepCompletionData: jsonEncode(decoded),
      ownerUserId: ownerUserId,
      syncStatus: 'pendingUpload',
      lastSyncedAt: run.lastSyncedAt,
      syncMetadataJson: run.syncMetadataJson,
      updatedAt: DateTime.now(),
    );
    await _database.routineRunDao.insertOrUpdateRun(updatedRun);
    return (run: updatedRun, waitingPhotos: waitingPhotos);
  }

  Future<RoutineSession> _uploadSessionProofs(
    RoutineSession session,
    String ownerUserId,
  ) async {
    var changed = false;
    final updatedStates = <RoutineSessionStepState>[];
    for (final stepState in session.stepStates) {
      final updatedAssets = <RoutineSessionProofAsset>[];
      for (final asset in stepState.proofAssets) {
        if (_hasOwnBackup(asset, ownerUserId)) {
          updatedAssets.add(asset);
          continue;
        }
        final uploaded = await _proofStorage.uploadProofAsset(
          asset: asset,
          ownerUserId: ownerUserId,
          entityType: 'sessions',
          entityId: session.sessionId,
        );
        updatedAssets.add(uploaded);
        changed = true;
      }
      updatedStates.add(stepState.copyWith(proofAssets: updatedAssets));
    }
    if (!changed) {
      return session;
    }
    return session.copyWith(
      ownerUserId: ownerUserId,
      stepStates: updatedStates,
      updatedAt: DateTime.now(),
      syncMetadata:
          (session.syncMetadata ??
                  const RoutineSessionSyncMetadata(needsSync: true))
              .copyWith(needsSync: true),
    );
  }

  /// A key under another account's folder is not a backup this account can
  /// read, so that photo still needs uploading.
  bool _hasOwnBackup(RoutineSessionProofAsset asset, String ownerUserId) {
    final key = asset.remoteObjectKey;
    return key != null && GuidanceAudioCloudBackup.isOwnedBy(key, ownerUserId);
  }

  RoutineSession _sessionFromRow(RoutineSessionRow row) {
    return RoutineSession.fromJson({
      'sessionId': row.sessionId,
      'routineId': row.routineId,
      'routineTitleSnapshot': row.routineTitleSnapshot,
      'workspaceId': row.workspaceId,
      'ownerUserId': row.ownerUserId,
      'storageScope': row.storageScope,
      'startedAt': row.startedAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'status': row.status,
      'currentStepIndex': row.currentStepIndex,
      'totalStepCount': row.totalStepCount,
      'baseRoutineVersion': row.baseRoutineVersion,
      'routineSnapshotSteps': jsonDecode(row.routineSnapshotJson),
      'stepStates': jsonDecode(row.stepStatesJson),
      'syncMetadata': row.syncMetadataJson == null
          ? null
          : jsonDecode(row.syncMetadataJson!),
      'completedAt': row.completedAt?.toIso8601String(),
      'discardedAt': row.discardedAt?.toIso8601String(),
    });
  }

  bool _looksOffline(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('offline') ||
        normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection closed') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout') ||
        normalized.contains('network request failed');
  }

  String _failureMessageForError(Object error) {
    if (_looksOffline(error)) {
      return 'You\'re offline. Changes will back up later.';
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('row-level security') ||
        normalized.contains('violates row-level security') ||
        normalized.contains('permission denied')) {
      return "Backup couldn't save your changes. Check backup is turned on for this account, then try again.";
    }
    if (normalized.contains('proof media storage quota exceeded')) {
      return 'Photo backup storage is full. Routine backup can continue once photo backup clears space.';
    }
    if (normalized.contains('proof media rolling upload quota exceeded')) {
      return 'Photo backup has reached the monthly upload limit. Routine backup will keep trying.';
    }
    return 'The last backup didn\'t finish. Try again.';
  }

  /// Publishes the outbox state and arms the retry timer. Pass
  /// [scheduleRetry] false when the pass was blocked (signed out, backup
  /// off): retrying then would only spin.
  Future<void> _refreshRuntimeState({
    List<SyncOutboxItem>? pendingItems,
    bool scheduleRetry = true,
  }) async {
    final items = pendingItems ?? await _outbox.pendingItems();
    final now = DateTime.now();
    // A row with no retry time is due now (added or edited during a pass).
    final nextRetryAt = items
        .map((item) => item.nextAttemptAt ?? now)
        .fold<DateTime?>(
          null,
          (earliest, next) =>
              earliest == null || next.isBefore(earliest) ? next : earliest,
        );
    _setRuntimeState(
      CloudSyncRuntimeState(
        isRunning: _isRunning,
        pendingCount: items.length,
        nextRetryAt: nextRetryAt,
      ),
    );
    _scheduleNextRetry(scheduleRetry ? nextRetryAt : null);
  }

  void _setRuntimeState(CloudSyncRuntimeState state) {
    if (_disposed) return;
    _ref.read(cloudSyncRuntimeStateProvider.notifier).state = state;
  }

  /// The shortest wait before an automatic retry, so a row that is due again
  /// straight away cannot make passes spin.
  static const _minRetryDelay = Duration(seconds: 5);

  void _scheduleNextRetry(DateTime? nextRetryAt) {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_disposed || nextRetryAt == null) {
      return;
    }
    var delay = nextRetryAt.difference(DateTime.now());
    if (delay < _minRetryDelay) delay = _minRetryDelay;
    _retryTimer = Timer(delay, () => unawaited(_automaticPass()));
  }

  Future<void> _automaticPass() async {
    if (_disposed) return;
    try {
      await _syncInternal(userInitiated: false);
    } catch (error) {
      developer.log(
        'Automatic backup retry failed: $error',
        name: 'CloudSyncCoordinator',
      );
    }
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _foregroundTimer?.cancel();
  }
}

/// Thrown by an item that cannot go up until another one has (a reminder
/// whose routine is not backed up yet). The item waits briefly without
/// counting as a failure.
class _DeferredSyncItem implements Exception {
  const _DeferredSyncItem(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

final cloudSyncRuntimeStateProvider = StateProvider<CloudSyncRuntimeState>(
  (ref) => const CloudSyncRuntimeState.idle(),
);

final cloudSyncCoordinatorProvider = Provider<CloudSyncCoordinator>((ref) {
  final db = ref.read(localDbProvider);
  final coordinator = CloudSyncCoordinator(
    ref: ref,
    database: db,
    outbox: ref.read(syncOutboxRepositoryProvider),
    remoteRoutineDataSource: ref.read(remoteRoutineDataSourceProvider),
    remoteReminderDataSource: ref.read(remoteRoutineReminderDataSourceProvider),
    remoteRunDataSource: ref.read(remoteRoutineRunDataSourceProvider),
    remoteSessionDataSource: ref.read(remoteRoutineSessionDataSourceProvider),
    proofStorage: ref.read(routineSessionProofStorageProvider),
    guidanceAudioBackup: ref.read(guidanceAudioCloudBackupProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
