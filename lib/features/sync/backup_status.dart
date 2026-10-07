import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';

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
  });

  final BackupPhase phase;

  /// Changes on this phone not yet in the backup.
  final int pendingCount;

  /// When a backup pass last finished with nothing left failing.
  final DateTime? lastBackedUpAt;

  /// The waiting is because the phone is offline.
  final bool offline;

  /// A short, plain sentence for [BackupPhase.needsAttention].
  final String? problem;

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
        final what = '$pendingCount ${_changes(pendingCount)} waiting';
        return offline
            ? '$what · back online to finish'
            : '$what · retrying soon';
      case BackupPhase.needsAttention:
        return problem ?? "Couldn't back up · tap to see why";
      default:
        return headline;
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
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(phase, pendingCount, lastBackedUpAt, offline, problem);
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
BackupStatus resolveBackupStatus({
  required PersonalCloudAccessStatus access,
  required bool isRunning,
  required int pendingCount,
  required int stuckCount,
  required DateTime? lastBackedUpAt,
  required String? lastError,
}) {
  final offline = looksOfflineError(lastError);
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
    );
  }
  if (stuckCount > 0) {
    return BackupStatus(
      phase: BackupPhase.needsAttention,
      pendingCount: pendingCount,
      lastBackedUpAt: lastBackedUpAt,
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
    );
  }
  if (access == PersonalCloudAccessStatus.error) {
    return BackupStatus(
      phase: offline ? BackupPhase.waiting : BackupPhase.needsAttention,
      lastBackedUpAt: lastBackedUpAt,
      offline: offline,
      problem: offline ? null : "Couldn't reach backup · tap to retry",
    );
  }
  if (lastBackedUpAt == null) {
    return const BackupStatus(phase: BackupPhase.checking);
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

/// The single backup status every screen reads.
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
  return resolveBackupStatus(
    access: access,
    isRunning: runtime.isRunning,
    pendingCount: pending,
    stuckCount: stuck,
    lastBackedUpAt: account.lastSyncAt,
    lastError: account.lastSyncError,
  );
});
