import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

/// The one answer to "is my stuff backed up?".
///
/// Every screen that mentions backup (Home chip, Account row, the Backup
/// screen, the completion receipt) reads this and nothing else, so they can
/// never disagree. Wording lives here too: [headline] and [line].
enum BackupPhase {
  /// Free plan: backup is part of Personal Premium.
  notIncluded,

  /// Premium, but not signed in on this phone.
  signedOut,

  /// Premium and signed in, but backup hasn't been turned on yet.
  off,

  /// Checking Premium and the account with the server.
  checking,

  /// Uploading right now.
  backingUp,

  /// Nothing waiting; everything on this phone is in the backup.
  upToDate,

  /// Changes are waiting and Pebble will retry by itself (offline, or a
  /// temporary server problem). No action needed.
  waiting,

  /// Something needs the person: a change keeps failing, Premium couldn't be
  /// confirmed, or this phone holds another account's data.
  needsAttention,

  /// Premium ended; backup is kept but paused.
  paused,
}

@immutable
class BackupStatus {
  const BackupStatus({
    required this.phase,
    this.pendingCount = 0,
    this.lastBackedUpAt,
    this.offline = false,
    this.problem,
    this.failingCount = 0,
    this.nextRetryAt,
  });

  final BackupPhase phase;

  /// Changes on this phone not yet in the backup.
  final int pendingCount;

  /// When a backup pass last finished with nothing left failing.
  ///
  /// Set only when a pass ends with nothing failed and nothing left waiting;
  /// never by a restore or by a pass that left work behind.
  final DateTime? lastBackedUpAt;

  /// The waiting is because the phone is offline.
  final bool offline;

  /// A short, plain sentence for [BackupPhase.needsAttention].
  final String? problem;

  /// Waiting changes whose last upload attempt failed (see
  /// [backupFailuresProvider] for the details).
  final int failingCount;

  /// When Pebble will next try the waiting changes by itself, if known.
  final DateTime? nextRetryAt;

  /// Backup is switched on for this account (whatever it's doing now).
  bool get isOn => switch (phase) {
    BackupPhase.checking ||
    BackupPhase.backingUp ||
    BackupPhase.upToDate ||
    BackupPhase.waiting ||
    BackupPhase.needsAttention => true,
    _ => false,
  };

  /// Two or three words: "Backed up", "Backing up", "Backup off".
  String get headline => switch (phase) {
    BackupPhase.notIncluded => 'Backup off',
    BackupPhase.signedOut => 'Sign in to back up',
    BackupPhase.off => 'Backup off',
    BackupPhase.checking => 'Checking backup',
    BackupPhase.backingUp => 'Backing up',
    BackupPhase.upToDate => 'Backed up',
    BackupPhase.waiting =>
      offline ? 'Waiting for internet' : 'Waiting to back up',
    BackupPhase.needsAttention => "Couldn't back up",
    BackupPhase.paused => 'Backup paused',
  };

  /// One line for a status row: "Backed up · 2 min ago".
  String line(DateTime now) {
    switch (phase) {
      case BackupPhase.upToDate:
        final at = lastBackedUpAt;
        return at == null ? 'Backed up' : 'Backed up · ${relativeAgo(at, now)}';
      case BackupPhase.backingUp:
        return pendingCount > 0
            ? 'Backing up $pendingCount ${_changes(pendingCount)}…'
            : 'Backing up…';
      case BackupPhase.waiting:
        if (pendingCount == 0) {
          return offline
              ? 'Waiting for internet to confirm backup'
              : 'Waiting to confirm backup';
        }
        final what = '$pendingCount ${_changes(pendingCount)} waiting';
        return offline
            ? '$what · back online to finish'
            : '$what · retrying soon';
      case BackupPhase.needsAttention:
        return problem ?? "Couldn't back up · tap to see why";
      case BackupPhase.notIncluded:
        return 'Comes with Personal Premium';
      case BackupPhase.signedOut:
        return 'Sign in to keep your routines backed up';
      case BackupPhase.off:
        return 'Your routines are only on this phone';
      case BackupPhase.checking:
        return 'Checking your account…';
      case BackupPhase.paused:
        return 'Paused because Premium ended';
    }
  }

  static String _changes(int n) => n == 1 ? 'change' : 'changes';

  @override
  bool operator ==(Object other) =>
      other is BackupStatus &&
      other.phase == phase &&
      other.pendingCount == pendingCount &&
      other.lastBackedUpAt == lastBackedUpAt &&
      other.offline == offline &&
      other.problem == problem &&
      other.failingCount == failingCount &&
      other.nextRetryAt == nextRetryAt;

  @override
  int get hashCode => Object.hash(
    phase,
    pendingCount,
    lastBackedUpAt,
    offline,
    problem,
    failingCount,
    nextRetryAt,
  );
}

/// "just now", "4 min ago", "3 h ago", "yesterday", "6 Oct".
String relativeAgo(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = at.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}

/// Maps the detailed access/runtime state onto [BackupStatus]. Pure, so the
/// rules are easy to test.
///
/// [stuckCount] is the number of waiting changes that have failed
/// [SyncOutboxRepositoryImpl.stuckAttemptThreshold] times in a row (Pebble
/// keeps retrying them, but the person should know). [failingCount] counts
/// waiting changes whose last attempt failed at all.
BackupStatus resolveBackupStatus({
  required PersonalCloudAccessStatus access,
  required bool isRunning,
  required int pendingCount,
  required int stuckCount,
  required DateTime? lastBackedUpAt,
  required String? lastError,
  int failingCount = 0,
  DateTime? nextRetryAt,
}) {
  final offline =
      looksOfflineError(lastError) ||
      access == PersonalCloudAccessStatus.offlinePending;
  switch (access) {
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return const BackupStatus(phase: BackupPhase.notIncluded);
    case PersonalCloudAccessStatus.pausedSignedOut:
      return BackupStatus(
        phase: BackupPhase.signedOut,
        pendingCount: pendingCount,
      );
    case PersonalCloudAccessStatus.consentRequired:
      return const BackupStatus(phase: BackupPhase.off);
    case PersonalCloudAccessStatus.expiredGrace:
      return BackupStatus(
        phase: BackupPhase.paused,
        pendingCount: pendingCount,
        lastBackedUpAt: lastBackedUpAt,
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return BackupStatus(
        phase: BackupPhase.needsAttention,
        pendingCount: pendingCount,
        lastBackedUpAt: lastBackedUpAt,
        problem: 'This phone has routines from another account',
      );
    case PersonalCloudAccessStatus.verificationFailed:
      return BackupStatus(
        phase: BackupPhase.needsAttention,
        pendingCount: pendingCount,
        lastBackedUpAt: lastBackedUpAt,
        problem: "Couldn't confirm Premium · tap to retry",
      );
    case PersonalCloudAccessStatus.syncing:
    case PersonalCloudAccessStatus.available:
    case PersonalCloudAccessStatus.offlinePending:
    case PersonalCloudAccessStatus.error:
      break;
  }
  if (isRunning) {
    return BackupStatus(
      phase: BackupPhase.backingUp,
      pendingCount: pendingCount,
      lastBackedUpAt: lastBackedUpAt,
      failingCount: failingCount,
    );
  }
  // Repeated failures while offline are just the phone being offline: they
  // clear by themselves once it reconnects, so they don't need the person.
  if (stuckCount > 0 && !offline) {
    return BackupStatus(
      phase: BackupPhase.needsAttention,
      pendingCount: pendingCount,
      lastBackedUpAt: lastBackedUpAt,
      failingCount: failingCount,
      nextRetryAt: nextRetryAt,
      problem:
          "$stuckCount ${stuckCount == 1 ? 'change' : 'changes'} couldn't back up · tap to retry",
    );
  }
  if (pendingCount > 0) {
    return BackupStatus(
      phase: BackupPhase.waiting,
      pendingCount: pendingCount,
      lastBackedUpAt: lastBackedUpAt,
      offline: offline,
      failingCount: failingCount,
      nextRetryAt: nextRetryAt,
    );
  }
  if (access == PersonalCloudAccessStatus.error ||
      access == PersonalCloudAccessStatus.offlinePending) {
    return BackupStatus(
      phase: offline ? BackupPhase.waiting : BackupPhase.needsAttention,
      lastBackedUpAt: lastBackedUpAt,
      offline: offline,
      problem: offline ? null : "Couldn't reach backup · tap to retry",
    );
  }
  if (access == PersonalCloudAccessStatus.syncing) {
    // Premium and the account are still being confirmed with the server.
    return BackupStatus(
      phase: BackupPhase.checking,
      lastBackedUpAt: lastBackedUpAt,
    );
  }
  return BackupStatus(
    phase: BackupPhase.upToDate,
    lastBackedUpAt: lastBackedUpAt,
  );
}

/// Whether a stored sync error reads as "no connection".
bool looksOfflineError(String? error) {
  if (error == null) return false;
  final lower = error.toLowerCase();
  return lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('offline') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('host lookup');
}

/// One waiting change whose upload has failed, for a "Details" view.
@immutable
class BackupFailure {
  const BackupFailure({
    required this.entityType,
    required this.entityId,
    required this.attempts,
    required this.errorSummary,
    required this.nextAttemptAt,
  });

  final SyncEntityType entityType;
  final String entityId;

  /// Failed attempts in a row.
  final int attempts;

  /// The stored error (type and message). Technical: for a details sheet or
  /// a support email, not for headline copy.
  final String? errorSummary;

  /// When Pebble will try this change again by itself.
  final DateTime? nextAttemptAt;

  /// Reached the "needs attention" threshold.
  bool get isStuck =>
      attempts >= SyncOutboxRepositoryImpl.stuckAttemptThreshold;

  /// What kind of change this is, in plain words.
  String get label => switch (entityType) {
    SyncEntityType.routine => 'Routine',
    SyncEntityType.reminder => 'Reminder',
    SyncEntityType.run => 'Completed run',
    SyncEntityType.session => 'Routine in progress',
    SyncEntityType.proofAsset => 'Proof photo',
    SyncEntityType.guidanceAudio => 'Voice prompt',
  };

  @override
  bool operator ==(Object other) =>
      other is BackupFailure &&
      other.entityType == entityType &&
      other.entityId == entityId &&
      other.attempts == attempts &&
      other.errorSummary == errorSummary &&
      other.nextAttemptAt == nextAttemptAt;

  @override
  int get hashCode =>
      Object.hash(entityType, entityId, attempts, errorSummary, nextAttemptAt);
}

SyncEntityType _entityTypeFromName(String name) =>
    SyncEntityType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => SyncEntityType.routine,
    );

/// Waiting changes whose last upload attempt failed, most failures first.
final backupFailuresProvider = StreamProvider<List<BackupFailure>>((ref) {
  final db = ref.watch(localDbProvider);
  return db.syncOutboxDao.watchItems().map((rows) {
    final failures = [
      for (final row in rows)
        if (row.attemptCount > 0)
          BackupFailure(
            entityType: _entityTypeFromName(row.entityType),
            entityId: row.entityId,
            attempts: row.attemptCount,
            errorSummary: row.lastErrorSummary,
            nextAttemptAt: row.nextAttemptAt,
          ),
    ]..sort((a, b) => b.attempts.compareTo(a.attempts));
    return failures;
  });
});

/// `"<entityType>:<entityId>"` for every change still waiting to back up,
/// so a list can tell a row that is marked synced but edited since apart
/// from one that is really in the backup.
final pendingBackupKeysProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(localDbProvider);
  return db.syncOutboxDao.watchItems().map(
    (rows) => {
      for (final row in rows)
        if (row.operation != SyncOperation.delete.name)
          '${row.entityType}:${row.entityId}',
    },
  );
});

/// The single backup status every screen reads. To back up now, call
/// `ref.read(cloudSyncCoordinatorProvider).backUpNow()`.
final backupStatusProvider = Provider<BackupStatus>((ref) {
  final access = ref.watch(effectivePersonalCloudStatusProvider);
  final runtime = ref.watch(cloudSyncRuntimeStateProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  final pending = ref
      .watch(syncOutboxCountProvider)
      .maybeWhen(data: (value) => value, orElse: () => 0);
  final stuck = ref
      .watch(stuckSyncCountProvider)
      .maybeWhen(data: (value) => value, orElse: () => 0);
  final failing = ref
      .watch(backupFailuresProvider)
      .maybeWhen(data: (value) => value.length, orElse: () => 0);
  return resolveBackupStatus(
    access: access,
    isRunning: runtime.isRunning,
    pendingCount: pending,
    stuckCount: stuck,
    lastBackedUpAt: account.lastSyncAt,
    lastError: account.lastSyncError,
    failingCount: failing,
    nextRetryAt: runtime.nextRetryAt,
  );
});
