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
  getPremium,
  turnOnBackup,
  pauseBackup,
  backUpNow,
  tryAgain,
  useCurrentAccount,
  keepBackupOff,
}

enum BackupDataItemState { saved, attention, off }

enum BackupSetupStepState { done, current, locked, attention }

class BackupSetupStep {
  const BackupSetupStep({
    required this.icon,
    required this.label,
    required this.detail,
    required this.state,
  });

  final IconData icon;
  final String label;
  final String detail;
  final BackupSetupStepState state;
}

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
    required this.setupSteps,
    required this.lastBackupText,
    required this.dataItems,
    required this.dataItemsLive,
    required this.dataFooter,
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
  final List<BackupSetupStep> setupSteps;
  final String lastBackupText;
  final List<BackupDataItem> dataItems;
  final bool dataItemsLive;
  final String dataFooter;
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

  bool get setupComplete =>
      setupSteps.every((step) => step.state == BackupSetupStepState.done);
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
  final stuckCount = ref
      .watch(stuckSyncCountProvider)
      .maybeWhen(data: (value) => value, orElse: () => 0);
  final pendingBannerText = stuckCount > 0 && dataItemsLive
      ? '$stuckCount change${stuckCount == 1 ? '' : 's'} couldn\'t back up '
            'after repeated tries. Use Back up now to retry.'
      : pendingCount > 0 && dataItemsLive && !runtime.isRunning
      ? '$pendingCount change${pendingCount == 1 ? '' : 's'} waiting to back up'
      : null;

  final base = _baseForStatus(
    status: status,
    summary: summary,
    lastSyncError: account.lastSyncError,
    entitlementError: account.entitlementError,
    runtime: runtime,
  );

  return BackupDashboardPresentation(
    statusLabel: base.statusLabel,
    detail: base.detail,
    setupSteps: _setupStepsFor(status: status, auth: auth),
    lastBackupText: lastBackupText,
    dataItems: dataItems,
    dataItemsLive: dataItemsLive,
    dataFooter: dataItemsLive
        ? 'Pebble backs up new changes by itself. Nothing to press.'
        : 'Once backup is on, Pebble saves changes by itself.',
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
        ? 'Which account should this phone use?'
        : null,
    ownershipDetail: status == PersonalCloudAccessStatus.accountSwitchBlocked
        ? account.lastSyncError ??
              'Pebble found routines on this phone that are not part of the signed-in account.'
        : null,
  );
});

List<BackupSetupStep> _setupStepsFor({
  required PersonalCloudAccessStatus status,
  required AuthSessionSummary auth,
}) {
  final signedIn = auth.isSignedIn;
  final hasPremium = switch (status) {
    PersonalCloudAccessStatus.pausedSignedOut ||
    PersonalCloudAccessStatus.consentRequired ||
    PersonalCloudAccessStatus.syncing ||
    PersonalCloudAccessStatus.verificationFailed ||
    PersonalCloudAccessStatus.available ||
    PersonalCloudAccessStatus.offlinePending ||
    PersonalCloudAccessStatus.error ||
    PersonalCloudAccessStatus.accountSwitchBlocked => true,
    PersonalCloudAccessStatus.offFree ||
    PersonalCloudAccessStatus.offSignedInNoEntitlement ||
    PersonalCloudAccessStatus.expiredGrace => false,
  };
  final backupOn = _backupSwitchValue(status);

  // Premium can be bought without an account, so it is always step one.
  final premiumStep = BackupSetupStep(
    icon: LucideIcons.sparkles,
    label: 'Get Premium',
    detail: hasPremium
        ? 'Premium is active.'
        : status == PersonalCloudAccessStatus.expiredGrace
        ? 'Renew Premium to back up again.'
        : 'Backup comes with Premium.',
    state: hasPremium
        ? BackupSetupStepState.done
        : BackupSetupStepState.current,
  );

  final signInStep = BackupSetupStep(
    icon: LucideIcons.logIn,
    label: 'Sign in',
    detail: signedIn
        ? 'Signed in as ${auth.email ?? 'your account'}.'
        : hasPremium
        ? 'Use your email so Pebble can restore later.'
        : 'Get Premium first.',
    state: signedIn
        ? BackupSetupStepState.done
        : hasPremium
        ? BackupSetupStepState.current
        : BackupSetupStepState.locked,
  );

  final backupStepState = switch (status) {
    PersonalCloudAccessStatus.available => BackupSetupStepState.done,
    PersonalCloudAccessStatus.syncing ||
    PersonalCloudAccessStatus.consentRequired => BackupSetupStepState.current,
    PersonalCloudAccessStatus.verificationFailed ||
    PersonalCloudAccessStatus.accountSwitchBlocked ||
    PersonalCloudAccessStatus.offlinePending ||
    PersonalCloudAccessStatus.error => BackupSetupStepState.attention,
    PersonalCloudAccessStatus.pausedSignedOut ||
    PersonalCloudAccessStatus.offFree ||
    PersonalCloudAccessStatus.offSignedInNoEntitlement ||
    PersonalCloudAccessStatus.expiredGrace => BackupSetupStepState.locked,
  };
  final backupDetail = switch (status) {
    PersonalCloudAccessStatus.available => 'Your routines are backed up.',
    PersonalCloudAccessStatus.syncing => 'Pebble is getting backup ready.',
    PersonalCloudAccessStatus.consentRequired =>
      'Turn on backup when you are ready.',
    PersonalCloudAccessStatus.verificationFailed => 'Pebble needs another try.',
    PersonalCloudAccessStatus.accountSwitchBlocked =>
      'Choose which account this phone should use.',
    PersonalCloudAccessStatus.offlinePending =>
      'Waiting for internet to come back.',
    PersonalCloudAccessStatus.error => 'The last backup did not finish.',
    PersonalCloudAccessStatus.pausedSignedOut => 'Sign in first.',
    PersonalCloudAccessStatus.expiredGrace => 'Renew Premium first.',
    PersonalCloudAccessStatus.offFree ||
    PersonalCloudAccessStatus.offSignedInNoEntitlement =>
      'Finish the steps above first.',
  };
  final backupStep = BackupSetupStep(
    icon: backupOn ? LucideIcons.cloudCheck : LucideIcons.fileCheck,
    label: 'Turn on backup',
    detail: backupDetail,
    state: backupStepState,
  );

  return [premiumStep, signInStep, backupStep];
}

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
      // Premium needs no account, so it is always the first door in.
      return const _BackupDashboardBase(
        statusLabel: 'Backup is off',
        detail:
            'Your routines are saved on this phone only. Backup comes with '
            'Premium and keeps 21 days of history.',
        icon: LucideIcons.cloud,
        tone: BackupDashboardTone.neutral,
        needsAttention: false,
        primaryAction: BackupDashboardAction.getPremium,
        primaryActionLabel: 'Get Premium',
        secondaryAction: BackupDashboardAction.none,
        secondaryActionLabel: null,
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
      return const _BackupDashboardBase(
        statusLabel: 'Sign in to back up',
        detail: 'You have Premium. Sign in again and backup will carry on.',
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
            'One tap and Pebble starts keeping a safe copy of your routines.',
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
        statusLabel: 'Backup is off',
        detail:
            'Backup stopped when Premium ended. Everything is still saved on this phone.',
        icon: LucideIcons.cloud,
        tone: BackupDashboardTone.neutral,
        needsAttention: false,
        primaryAction: BackupDashboardAction.getPremium,
        primaryActionLabel: 'Renew Premium',
        secondaryAction: BackupDashboardAction.none,
        secondaryActionLabel: null,
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return const _BackupDashboardBase(
        statusLabel: 'Choose an account',
        detail:
            'This phone has routines from a different account. Choose what to do and backup can carry on.',
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
        statusLabel: 'Waiting for internet',
        detail:
            'Changes are saved on this phone and will back up when you\'re online.',
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
            'The last backup didn\'t finish. Your changes are still saved on this phone.',
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

  // While backup is off the counts only raise questions ("why is it counting
  // my routines?"), so keep it to a plain description of what backup covers.
  final routineTotal = routines?.length;
  final routineSynced = routines
      ?.where(
        (routine) =>
            routine.syncStatus == 'synced' || routine.lastSyncedAt != null,
      )
      .length;
  final String routineDetail;
  if (!live) {
    routineDetail = 'Every routine and its steps';
  } else if (routineTotal == null || routineSynced == null) {
    routineDetail = 'Checking routines';
  } else if (routineTotal == 0) {
    routineDetail = 'No routines yet';
  } else {
    routineDetail = '$routineSynced of $routineTotal backed up';
  }

  final runTotal = runs?.length;
  final runSynced = runs
      ?.where((run) => run.syncStatus == 'synced' || run.lastSyncedAt != null)
      .length;
  final String runDetail;
  if (!live) {
    runDetail = 'The runs you\'ve completed';
  } else if (runTotal == null || runSynced == null) {
    runDetail = 'Checking history';
  } else if (runTotal == 0) {
    runDetail = 'No completed runs yet';
  } else {
    runDetail = runSynced == 0
        ? 'Waiting for first backup'
        : '$runSynced completed run${runSynced == 1 ? '' : 's'} backed up';
  }

  final String photoDetail;
  var photoState = offState;
  if (!live) {
    photoDetail = 'Photos you add along the way';
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
