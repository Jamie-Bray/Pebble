import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';

enum BackupDashboardTone { neutral, active, syncing, paused, attention }

enum BackupDashboardAction {
  none,
  signIn,
  turnOnBackup,
  pauseBackup,
  backUpNow,
  tryAgain,
  useCurrentAccount,
  keepBackupOff,
}

enum BackupDataItemState { saved, attention, off }

class BackupDataItem {
  const BackupDataItem({
    required this.icon,
    required this.label,
    required this.detail,
    required this.state,
  });

  final IconData icon;
  final String label;
  final String detail;
  final BackupDataItemState state;
}

class BackupDashboardPresentation {
  const BackupDashboardPresentation({
    required this.statusLabel,
    required this.detail,
    required this.lastBackupText,
    required this.dataItems,
    required this.dataItemsLive,
    required this.pendingBannerText,
    required this.icon,
    required this.tone,
    required this.needsAttention,
    required this.backupSwitchValue,
    required this.backupSwitchEnabled,
    required this.primaryAction,
    required this.primaryActionLabel,
    required this.secondaryAction,
    required this.secondaryActionLabel,
    required this.showManualSync,
    required this.manualSyncEnabled,
    required this.showOwnershipMismatch,
    required this.ownershipTitle,
    required this.ownershipDetail,
  });

  final String statusLabel;
  final String detail;
  final String lastBackupText;
  final List<BackupDataItem> dataItems;
  final bool dataItemsLive;
  final String? pendingBannerText;
  final IconData icon;
  final BackupDashboardTone tone;
  final bool needsAttention;
  final bool backupSwitchValue;
  final bool backupSwitchEnabled;
  final BackupDashboardAction primaryAction;
  final String? primaryActionLabel;
  final BackupDashboardAction secondaryAction;
  final String? secondaryActionLabel;
  final bool showManualSync;
  final bool manualSyncEnabled;
  final bool showOwnershipMismatch;
  final String? ownershipTitle;
  final String? ownershipDetail;
}

final backupDashboardRunsProvider = StreamProvider<List<RoutineRun>>((ref) {
  final db = ref.watch(localDbProvider);
  return db.routineRunDao.watchAllRuns();
});

final backupDashboardPresentationProvider = Provider<BackupDashboardPresentation>((
  ref,
) {
  final auth = ref.watch(authSessionProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  final status = ref.watch(effectivePersonalCloudStatusProvider);
  final summary = ref.watch(accountBackupStatusSummaryProvider);
  final runtime = ref.watch(cloudSyncRuntimeStateProvider);
  final pendingCount = ref
      .watch(syncOutboxCountProvider)
      .maybeWhen(data: (value) => value, orElse: () => 0);
  final routines = ref
      .watch(routineListProvider)
      .maybeWhen(data: (value) => value, orElse: () => null);
  final runs = ref
      .watch(backupDashboardRunsProvider)
      .maybeWhen(data: (value) => value, orElse: () => null);
  final fairUse = ref
      .watch(proofMediaFairUseStateProvider)
      .maybeWhen(data: (value) => value, orElse: () => null);

  final lastBackupText = account.lastSyncAt == null
      ? 'No backup yet'
      : 'Last backed up ${_relativeTimestamp(account.lastSyncAt!)}';
  final dataItemsLive = _backupSwitchValue(status);
  final dataItems = _dataItemsFor(
    live: dataItemsLive,
    routines: routines,
    runs: runs,
    fairUse: fairUse,
  );
  final pendingBannerText =
      pendingCount > 0 && dataItemsLive && !runtime.isRunning
      ? '$pendingCount change${pendingCount == 1 ? '' : 's'} waiting to back up'
      : null;

  final base = _baseForStatus(
    status: status,
    summary: summary,
    auth: auth,
    lastSyncError: account.lastSyncError,
    entitlementError: account.entitlementError,
    runtime: runtime,
  );

  return BackupDashboardPresentation(
    statusLabel: base.statusLabel,
    detail: base.detail,
    lastBackupText: lastBackupText,
    dataItems: dataItems,
    dataItemsLive: dataItemsLive,
    pendingBannerText: pendingBannerText,
    icon: base.icon,
    tone: base.tone,
    needsAttention: base.needsAttention,
    backupSwitchValue: _backupSwitchValue(status),
    backupSwitchEnabled: _backupSwitchEnabled(status, auth.isSignedIn),
    primaryAction: base.primaryAction,
    primaryActionLabel: base.primaryActionLabel,
    secondaryAction: base.secondaryAction,
    secondaryActionLabel: base.secondaryActionLabel,
    showManualSync: _showManualSync(status),
    manualSyncEnabled: _manualSyncEnabled(status, runtime),
    showOwnershipMismatch:
        status == PersonalCloudAccessStatus.accountSwitchBlocked,
    ownershipTitle: status == PersonalCloudAccessStatus.accountSwitchBlocked
        ? 'Choose how this device backs up'
        : null,
    ownershipDetail: status == PersonalCloudAccessStatus.accountSwitchBlocked
        ? account.lastSyncError ??
              'Pebble found data on this device that is not linked to the signed-in account.'
        : null,
  );
});

class _BackupDashboardBase {
  const _BackupDashboardBase({
    required this.statusLabel,
    required this.detail,
    required this.icon,
    required this.tone,
    required this.needsAttention,
    required this.primaryAction,
    required this.primaryActionLabel,
    required this.secondaryAction,
    required this.secondaryActionLabel,
  });

  final String statusLabel;
  final String detail;
  final IconData icon;
  final BackupDashboardTone tone;
  final bool needsAttention;
  final BackupDashboardAction primaryAction;
  final String? primaryActionLabel;
  final BackupDashboardAction secondaryAction;
  final String? secondaryActionLabel;
}

_BackupDashboardBase _baseForStatus({
  required PersonalCloudAccessStatus status,
  required AccountBackupStatusSummary summary,
  required AuthSessionSummary auth,
  required String? lastSyncError,
  required String? entitlementError,
  required CloudSyncRuntimeState runtime,
}) {
  if (runtime.isRunning) {
    return const _BackupDashboardBase(
      statusLabel: 'Backing up now',
      detail: 'Pebble is saving your latest changes.',
      icon: LucideIcons.refreshCw,
      tone: BackupDashboardTone.syncing,
      needsAttention: false,
      primaryAction: BackupDashboardAction.none,
      primaryActionLabel: null,
      secondaryAction: BackupDashboardAction.pauseBackup,
      secondaryActionLabel: 'Pause backup',
    );
  }

  switch (status) {
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return _BackupDashboardBase(
        statusLabel: 'Backup is off',
        detail: auth.isSignedIn
            ? 'Cloud backup is available with Personal Premium.'
            : 'Sign in and use Personal Premium when you want backup.',
        icon: LucideIcons.cloud,
        tone: BackupDashboardTone.neutral,
        needsAttention: false,
        primaryAction: auth.isSignedIn
            ? BackupDashboardAction.none
            : BackupDashboardAction.signIn,
        primaryActionLabel: auth.isSignedIn ? null : 'Sign in',
        secondaryAction: BackupDashboardAction.none,
        secondaryActionLabel: null,
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
      return const _BackupDashboardBase(
        statusLabel: 'Backup is paused',
        detail: 'Sign in to connect Premium backup to this account.',
        icon: LucideIcons.cloudOff,
        tone: BackupDashboardTone.paused,
        needsAttention: true,
        primaryAction: BackupDashboardAction.signIn,
        primaryActionLabel: 'Sign in',
        secondaryAction: BackupDashboardAction.none,
        secondaryActionLabel: null,
      );
    case PersonalCloudAccessStatus.consentRequired:
      return const _BackupDashboardBase(
        statusLabel: 'Ready to turn on',
        detail:
            'Pebble will not upload supported routine data until you choose.',
        icon: LucideIcons.fileCheck,
        tone: BackupDashboardTone.attention,
        needsAttention: true,
        primaryAction: BackupDashboardAction.turnOnBackup,
        primaryActionLabel: 'Turn on backup',
        secondaryAction: BackupDashboardAction.none,
        secondaryActionLabel: null,
      );
    case PersonalCloudAccessStatus.available:
      return _BackupDashboardBase(
        statusLabel: 'Backup is on',
        detail: summary.detail,
        icon: LucideIcons.cloudCheck,
        tone: BackupDashboardTone.active,
        needsAttention: false,
        primaryAction: BackupDashboardAction.backUpNow,
        primaryActionLabel: 'Back up now',
        secondaryAction: BackupDashboardAction.pauseBackup,
        secondaryActionLabel: 'Pause backup',
      );
    case PersonalCloudAccessStatus.syncing:
      return _BackupDashboardBase(
        statusLabel: summary.label == 'Checking backup'
            ? 'Checking backup'
            : 'Preparing backup',
        detail: summary.detail,
        icon: LucideIcons.refreshCw,
        tone: BackupDashboardTone.neutral,
        needsAttention: false,
        primaryAction: BackupDashboardAction.none,
        primaryActionLabel: null,
        secondaryAction: BackupDashboardAction.pauseBackup,
        secondaryActionLabel: 'Pause backup',
      );
    case PersonalCloudAccessStatus.verificationFailed:
      return _BackupDashboardBase(
        statusLabel: 'Couldn\'t finish backup setup',
        detail:
            entitlementError ??
            'Premium is active, but backup could not be verified for this account yet.',
        icon: LucideIcons.cloudAlert,
        tone: BackupDashboardTone.attention,
        needsAttention: true,
        primaryAction: BackupDashboardAction.tryAgain,
        primaryActionLabel: 'Try again',
        secondaryAction: BackupDashboardAction.none,
        secondaryActionLabel: null,
      );
    case PersonalCloudAccessStatus.expiredGrace:
      return const _BackupDashboardBase(
        statusLabel: 'Backup is paused',
        detail: 'Premium recently ended, so new cloud uploads are paused.',
        icon: LucideIcons.clock3,
        tone: BackupDashboardTone.paused,
        needsAttention: false,
        primaryAction: BackupDashboardAction.none,
        primaryActionLabel: null,
        secondaryAction: BackupDashboardAction.none,
        secondaryActionLabel: null,
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return const _BackupDashboardBase(
        statusLabel: 'Backup is paused',
        detail:
            'Choose whether this device should use your signed-in account for backup.',
        icon: LucideIcons.shieldAlert,
        tone: BackupDashboardTone.attention,
        needsAttention: true,
        primaryAction: BackupDashboardAction.useCurrentAccount,
        primaryActionLabel: 'Use this account',
        secondaryAction: BackupDashboardAction.keepBackupOff,
        secondaryActionLabel: 'Keep backup off',
      );
    case PersonalCloudAccessStatus.offlinePending:
      return const _BackupDashboardBase(
        statusLabel: 'Waiting for connection',
        detail: 'Changes are saved locally and will sync when Pebble connects.',
        icon: LucideIcons.wifiOff,
        tone: BackupDashboardTone.paused,
        needsAttention: true,
        primaryAction: BackupDashboardAction.backUpNow,
        primaryActionLabel: 'Try now',
        secondaryAction: BackupDashboardAction.pauseBackup,
        secondaryActionLabel: 'Pause backup',
      );
    case PersonalCloudAccessStatus.error:
      return _BackupDashboardBase(
        statusLabel: 'Backup needs attention',
        detail:
            lastSyncError ??
            'Pebble could not finish syncing everything. Local data stays here.',
        icon: LucideIcons.cloudAlert,
        tone: BackupDashboardTone.attention,
        needsAttention: true,
        primaryAction: BackupDashboardAction.backUpNow,
        primaryActionLabel: 'Try again',
        secondaryAction: BackupDashboardAction.pauseBackup,
        secondaryActionLabel: 'Pause backup',
      );
  }
}

bool _backupSwitchValue(PersonalCloudAccessStatus status) {
  return status == PersonalCloudAccessStatus.available ||
      status == PersonalCloudAccessStatus.syncing ||
      status == PersonalCloudAccessStatus.offlinePending ||
      status == PersonalCloudAccessStatus.error;
}

bool _backupSwitchEnabled(PersonalCloudAccessStatus status, bool isSignedIn) {
  if (!isSignedIn) {
    return false;
  }
  return status == PersonalCloudAccessStatus.consentRequired ||
      status == PersonalCloudAccessStatus.available ||
      status == PersonalCloudAccessStatus.syncing ||
      status == PersonalCloudAccessStatus.offlinePending ||
      status == PersonalCloudAccessStatus.error;
}

bool _showManualSync(PersonalCloudAccessStatus status) {
  return status == PersonalCloudAccessStatus.available ||
      status == PersonalCloudAccessStatus.syncing ||
      status == PersonalCloudAccessStatus.offlinePending ||
      status == PersonalCloudAccessStatus.error;
}

bool _manualSyncEnabled(
  PersonalCloudAccessStatus status,
  CloudSyncRuntimeState runtime,
) {
  return !runtime.isRunning &&
      (status == PersonalCloudAccessStatus.available ||
          status == PersonalCloudAccessStatus.offlinePending ||
          status == PersonalCloudAccessStatus.error);
}

List<BackupDataItem> _dataItemsFor({
  required bool live,
  required List<Routine>? routines,
  required List<RoutineRun>? runs,
  required ProofMediaFairUseState? fairUse,
}) {
  final offState = live ? BackupDataItemState.saved : BackupDataItemState.off;

  final routineTotal = routines?.length;
  final routineSynced = routines
      ?.where(
        (routine) =>
            routine.syncStatus == 'synced' || routine.lastSyncedAt != null,
      )
      .length;
  final String routineDetail;
  if (routineTotal == null || routineSynced == null) {
    routineDetail = 'Checking routines';
  } else if (routineTotal == 0) {
    routineDetail = 'No routines yet';
  } else if (live) {
    routineDetail = '$routineSynced of $routineTotal backed up';
  } else {
    routineDetail =
        '$routineTotal routine${routineTotal == 1 ? '' : 's'} on this device';
  }

  final runTotal = runs?.length;
  final runSynced = runs
      ?.where((run) => run.syncStatus == 'synced' || run.lastSyncedAt != null)
      .length;
  final String runDetail;
  if (runTotal == null || runSynced == null) {
    runDetail = 'Checking history';
  } else if (runTotal == 0) {
    runDetail = 'No completed runs yet';
  } else if (live) {
    runDetail = runSynced == 0
        ? 'Waiting for first backup'
        : '$runSynced completed run${runSynced == 1 ? '' : 's'} backed up';
  } else {
    runDetail =
        '$runTotal completed run${runTotal == 1 ? '' : 's'} on this device';
  }

  final String photoDetail;
  var photoState = offState;
  if (!live) {
    photoDetail = 'Included when backup is on';
  } else if (fairUse == null) {
    photoDetail = 'Checking photo storage';
  } else if (fairUse.status == ProofMediaFairUseStatus.full) {
    photoDetail = 'Storage full. Routine backup still works.';
    photoState = BackupDataItemState.attention;
  } else if (fairUse.status == ProofMediaFairUseStatus.warning) {
    photoDetail = 'Storage nearly full. ${fairUse.storageLabel}.';
    photoState = BackupDataItemState.attention;
  } else {
    photoDetail = fairUse.storageLabel;
  }

  return [
    BackupDataItem(
      icon: LucideIcons.listChecks,
      label: 'Routines',
      detail: routineDetail,
      state: offState,
    ),
    BackupDataItem(
      icon: LucideIcons.history,
      label: 'History',
      detail: runDetail,
      state: offState,
    ),
    BackupDataItem(
      icon: LucideIcons.image,
      label: 'Proof photos',
      detail: photoDetail,
      state: photoState,
    ),
  ];
}

String _relativeTimestamp(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) {
    return 'just now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h ago';
  }
  return '${diff.inDays}d ago';
}
