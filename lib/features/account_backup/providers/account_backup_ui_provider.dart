import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';

enum AccountBackupChipTone { positive, neutral, attention }

class AccountBackupChipState {
  const AccountBackupChipState({
    required this.show,
    required this.label,
    required this.tone,
    required this.semanticsHint,
  });

  const AccountBackupChipState.hidden()
    : show = false,
      label = '',
      tone = AccountBackupChipTone.neutral,
      semanticsHint = '';

  final bool show;
  final String label;
  final AccountBackupChipTone tone;
  final String semanticsHint;
}

enum AccountBackupStatusKind {
  localOnly,
  premiumSetupPending,
  waitingForSignIn,
  waitingForConsent,
  ready,
  syncing,
  paused,
  blocked,
  waitingForConnection,
  attention,
}

class AccountBackupStatusSummary {
  const AccountBackupStatusSummary({
    required this.kind,
    required this.label,
    required this.detail,
    required this.historyLabel,
    required this.showRunSyncState,
  });

  final AccountBackupStatusKind kind;
  final String label;
  final String detail;
  final String historyLabel;
  final bool showRunSyncState;
}

enum AccountSectionAction { signIn, signOut }

enum PlanSectionAction { upgrade, managePlan, restorePurchase, none }

enum BackupSectionAction {
  enableCloudBackup,
  retrySync,
  refreshStatus,
  restoreBackup,
  none,
}

class AccountBackupUiState {
  const AccountBackupUiState({
    required this.accountHeadline,
    required this.accountSupportingText,
    required this.accountAction,
    required this.accountActionLabel,
    required this.planName,
    required this.planSupportingText,
    required this.planAction,
    required this.planActionLabel,
    required this.backupSummary,
    required this.backupDetail,
    required this.backupPrimaryAction,
    required this.backupPrimaryActionLabel,
    required this.backupSecondaryAction,
    required this.backupSecondaryActionLabel,
    required this.lastSyncText,
    required this.lastBackupText,
    required this.pendingChangesText,
    required this.showDataActionsSection,
  });

  final String accountHeadline;
  final String? accountSupportingText;
  final AccountSectionAction accountAction;
  final String accountActionLabel;

  final String planName;
  final String? planSupportingText;
  final PlanSectionAction planAction;
  final String? planActionLabel;

  final String backupSummary;
  final String? backupDetail;
  final BackupSectionAction backupPrimaryAction;
  final String? backupPrimaryActionLabel;
  final BackupSectionAction backupSecondaryAction;
  final String? backupSecondaryActionLabel;

  final String? lastSyncText;
  final String? lastBackupText;
  final String? pendingChangesText;
  final bool showDataActionsSection;
}

final syncOutboxCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(localDbProvider);
  return db.syncOutboxDao.watchItems().map((rows) => rows.length);
});

final accountBackupStatusSummaryProvider = Provider<AccountBackupStatusSummary>((
  ref,
) {
  final baseAccess = ref.watch(personalCloudAccessProvider);
  final status = ref.watch(effectivePersonalCloudStatusProvider);
  final runtime = ref.watch(cloudSyncRuntimeStateProvider);
  final pendingCount = ref
      .watch(syncOutboxCountProvider)
      .maybeWhen(data: (value) => value, orElse: () => 0);
  final entitlement = ref.watch(entitlementStateProvider);
  final purchase = ref.watch(purchaseRepositoryProvider);
  final isPremium = entitlement.isPersonalPaid;
  final purchaseSetupPending = !isPremium && !purchase.isPurchaseAvailable;
  final pendingDetail = pendingCount > 0
      ? ' $pendingCount change${pendingCount == 1 ? '' : 's'} will sync when backup can run.'
      : '';

  if (runtime.isRunning) {
    return AccountBackupStatusSummary(
      kind: AccountBackupStatusKind.syncing,
      label: 'Cloud backup syncing',
      detail: pendingCount > 0
          ? '$pendingCount change${pendingCount == 1 ? '' : 's'} syncing now.'
          : 'Pebble is syncing supported routine data now.',
      historyLabel: 'Cloud backup syncing',
      showRunSyncState: true,
    );
  }

  switch (status) {
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      if (purchaseSetupPending) {
        return const AccountBackupStatusSummary(
          kind: AccountBackupStatusKind.premiumSetupPending,
          label: 'Premium setup pending',
          detail:
              'Pebble works locally. Personal Premium cannot be started until Google Play products are configured for this build.',
          historyLabel: 'Stored on this device',
          showRunSyncState: false,
        );
      }
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.localOnly,
        label: 'Stored on this device',
        detail:
            'Pebble is local-first. Free keeps recent history for 48 hours on this device. Sign in is only needed for cloud backup and account recovery.',
        historyLabel: 'Stored on this device',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.waitingForSignIn,
        label: 'Waiting for sign-in',
        detail:
            'Personal Premium is active. Sign in to resume cloud backup; local routines stay on this device.',
        historyLabel: 'Waiting for sign-in',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.consentRequired:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.waitingForConsent,
        label: 'Waiting for backup consent',
        detail:
            'Premium is active and sign-in is ready. Cloud backup starts only after you enable backup consent.',
        historyLabel: 'Waiting for backup consent',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.available:
      return AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.ready,
        label: 'Cloud backup ready',
        detail: 'Supported routine data can sync for restore.$pendingDetail',
        historyLabel: 'Cloud backup ready',
        showRunSyncState: true,
      );
    case PersonalCloudAccessStatus.syncing:
      if (baseAccess.label == 'Checking backup') {
        return const AccountBackupStatusSummary(
          kind: AccountBackupStatusKind.premiumSetupPending,
          label: 'Checking backup',
          detail:
              'Premium is active. Pebble is checking backup for this account.',
          historyLabel: 'Backup pending',
          showRunSyncState: false,
        );
      }
      return AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.premiumSetupPending,
        label: 'Preparing backup',
        detail: baseAccess.detail ?? 'Pebble is preparing backup.',
        historyLabel: 'Backup pending',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.verificationFailed:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.attention,
        label: 'Backup setup failed',
        detail:
            'Premium is active, but backup could not be verified for this account yet.',
        historyLabel: 'Backup pending',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.expiredGrace:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.paused,
        label: 'Cloud backup paused',
        detail:
            'Premium recently ended. New uploads are paused, and your 21-day history remains visible for 7 days.',
        historyLabel: 'Cloud backup paused',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.blocked,
        label: 'Backup blocked for account safety',
        detail:
            'Pebble is keeping local data local until you choose how to handle this signed-in account.',
        historyLabel: 'Backup blocked for account safety',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.offlinePending:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.waitingForConnection,
        label: 'Waiting for connection',
        detail:
            'Changes are saved locally and will sync when Pebble can connect.',
        historyLabel: 'Waiting for connection',
        showRunSyncState: true,
      );
    case PersonalCloudAccessStatus.error:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.attention,
        label: 'Backup needs attention',
        detail:
            'Pebble could not finish syncing everything. Local data remains on this device.',
        historyLabel: 'Backup needs attention',
        showRunSyncState: true,
      );
  }
});

final effectivePersonalCloudStatusProvider =
    Provider<PersonalCloudAccessStatus>((ref) {
      final base = ref.watch(personalCloudAccessProvider);
      final account = ref.watch(subscriptionAccountControllerProvider);
      final runtime = ref.watch(cloudSyncRuntimeStateProvider);
      final pendingCount = ref
          .watch(syncOutboxCountProvider)
          .maybeWhen(data: (value) => value, orElse: () => 0);
      final isPaid = ref.watch(entitlementStateProvider).isPersonalPaid;
      final isSignedIn = ref.watch(authSessionProvider).isSignedIn;

      if (base.status == PersonalCloudAccessStatus.expiredGrace ||
          base.status == PersonalCloudAccessStatus.accountSwitchBlocked) {
        return base.status;
      }
      if (!isPaid) {
        return isSignedIn
            ? PersonalCloudAccessStatus.offSignedInNoEntitlement
            : PersonalCloudAccessStatus.offFree;
      }
      if (!isSignedIn) {
        return PersonalCloudAccessStatus.pausedSignedOut;
      }
      if (base.status == PersonalCloudAccessStatus.verificationFailed) {
        return PersonalCloudAccessStatus.verificationFailed;
      }
      if (base.status == PersonalCloudAccessStatus.consentRequired) {
        return PersonalCloudAccessStatus.consentRequired;
      }
      if (runtime.isRunning) {
        return PersonalCloudAccessStatus.syncing;
      }
      if (pendingCount > 0 && _looksOffline(account.lastSyncError)) {
        return PersonalCloudAccessStatus.offlinePending;
      }
      if (pendingCount > 0 &&
          (base.status == PersonalCloudAccessStatus.available ||
              base.status == PersonalCloudAccessStatus.syncing)) {
        return PersonalCloudAccessStatus.available;
      }
      if (base.status == PersonalCloudAccessStatus.error && pendingCount > 0) {
        return _looksOffline(account.lastSyncError)
            ? PersonalCloudAccessStatus.offlinePending
            : PersonalCloudAccessStatus.error;
      }
      return base.status;
    });

final accountBackupChipStateProvider = Provider<AccountBackupChipState>((ref) {
  final status = ref.watch(effectivePersonalCloudStatusProvider);
  final baseAccess = ref.watch(personalCloudAccessProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  final runtime = ref.watch(cloudSyncRuntimeStateProvider);
  final pendingCount = ref
      .watch(syncOutboxCountProvider)
      .maybeWhen(data: (value) => value, orElse: () => 0);
  final fairUse = ref
      .watch(proofMediaFairUseStateProvider)
      .maybeWhen(data: (value) => value, orElse: () => null);

  switch (status) {
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return const AccountBackupChipState.hidden();
    case PersonalCloudAccessStatus.consentRequired:
      return const AccountBackupChipState(
        show: true,
        label: 'Set up backup',
        tone: AccountBackupChipTone.attention,
        semanticsHint: 'Cloud backup needs your review before upload starts.',
      );
    case PersonalCloudAccessStatus.syncing:
      if (!runtime.isRunning) {
        final checking = baseAccess.label == 'Checking backup';
        return AccountBackupChipState(
          show: true,
          label: checking ? 'Checking backup' : 'Preparing backup',
          tone: AccountBackupChipTone.neutral,
          semanticsHint: checking
              ? 'Pebble is checking backup for this account.'
              : 'Pebble is preparing backup.',
        );
      }
      return const AccountBackupChipState(
        show: true,
        label: 'Backing up...',
        tone: AccountBackupChipTone.positive,
        semanticsHint: 'Pebble is saving your latest changes.',
      );
    case PersonalCloudAccessStatus.available:
      if (fairUse?.status == ProofMediaFairUseStatus.full) {
        return const AccountBackupChipState(
          show: true,
          label: 'Photo storage full',
          tone: AccountBackupChipTone.attention,
          semanticsHint: 'Photo storage full. Routine backup still works.',
        );
      }
      final lastSyncAt = account.lastSyncAt;
      return AccountBackupChipState(
        show: true,
        label: lastSyncAt == null
            ? 'Backup on'
            : 'Backed up · ${_shortRelativeTimestamp(lastSyncAt)}',
        tone: AccountBackupChipTone.positive,
        semanticsHint: 'Backup is on. Tap to see what is backed up.',
      );
    case PersonalCloudAccessStatus.offlinePending:
      return AccountBackupChipState(
        show: true,
        label: pendingCount > 0 ? '$pendingCount waiting' : 'Offline',
        tone: AccountBackupChipTone.neutral,
        semanticsHint: 'Changes will back up when connection returns.',
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
    case PersonalCloudAccessStatus.expiredGrace:
      return const AccountBackupChipState(
        show: true,
        label: 'Backup paused',
        tone: AccountBackupChipTone.neutral,
        semanticsHint: 'Backup is paused. Tap for details.',
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return const AccountBackupChipState(
        show: true,
        label: 'Needs review',
        tone: AccountBackupChipTone.attention,
        semanticsHint: 'Backup is paused until this device is reviewed.',
      );
    case PersonalCloudAccessStatus.verificationFailed:
    case PersonalCloudAccessStatus.error:
      return const AccountBackupChipState(
        show: true,
        label: 'Needs attention',
        tone: AccountBackupChipTone.attention,
        semanticsHint: 'Backup could not finish. Tap to fix it.',
      );
  }
});

String _shortRelativeTimestamp(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) {
    return 'now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h';
  }
  return '${diff.inDays}d';
}

final accountBackupUiStateProvider = Provider<AccountBackupUiState>((ref) {
  final account = ref.watch(subscriptionAccountControllerProvider);
  final auth = ref.watch(authSessionProvider);
  final entitlement = ref.watch(entitlementStateProvider);
  final status = ref.watch(effectivePersonalCloudStatusProvider);
  final runtime = ref.watch(cloudSyncRuntimeStateProvider);
  final fairUse = ref
      .watch(proofMediaFairUseStateProvider)
      .maybeWhen(data: (value) => value, orElse: () => null);
  final pendingCount = ref
      .watch(syncOutboxCountProvider)
      .maybeWhen(data: (value) => value, orElse: () => 0);

  final accountHeadline = auth.isSignedIn
      ? 'Signed in as ${auth.email ?? 'your account'}'
      : 'Pebble works without an account';
  final accountSupportingText = auth.isSignedIn
      ? _providerLabel(auth.provider)
      : 'Your routines are stored on this device.';

  final planName = _planLabel(entitlement.personalTier);
  final planSupportingText = _planSupportingText(
    tier: entitlement.personalTier,
    isSignedIn: auth.isSignedIn,
  );

  final lastSyncText = account.lastSyncAt == null
      ? null
      : 'Last sync ${_relativeTimestamp(account.lastSyncAt!)}';
  final pendingChangesText = pendingCount > 0
      ? '$pendingCount change${pendingCount == 1 ? '' : 's'} still need to sync'
      : null;

  return AccountBackupUiState(
    accountHeadline: accountHeadline,
    accountSupportingText: accountSupportingText,
    accountAction: auth.isSignedIn
        ? AccountSectionAction.signOut
        : AccountSectionAction.signIn,
    accountActionLabel: auth.isSignedIn ? 'Sign out' : 'Restore Premium',
    planName: planName,
    planSupportingText: planSupportingText,
    planAction: _planActionForTier(entitlement.personalTier),
    planActionLabel: _planActionLabelForTier(entitlement.personalTier),
    backupSummary: _backupSummaryForState(status, auth.isSignedIn),
    backupDetail: _backupDetailForState(
      status: status,
      pendingChangesText: pendingChangesText,
      lastError: account.lastSyncError,
      nextRetryAt: runtime.nextRetryAt,
      fairUseState: entitlement.isPersonalPaid ? fairUse : null,
    ),
    backupPrimaryAction: _primaryBackupActionForState(status),
    backupPrimaryActionLabel: _primaryBackupActionLabelForState(status),
    backupSecondaryAction: _secondaryBackupActionForState(status),
    backupSecondaryActionLabel: _secondaryBackupActionLabelForState(status),
    lastSyncText: lastSyncText,
    lastBackupText: null,
    pendingChangesText: pendingChangesText,
    showDataActionsSection: true,
  );
});

String _planLabel(UserTier tier) {
  switch (tier) {
    case UserTier.personalFree:
      return 'Pebble Personal';
    case UserTier.personalPremium:
      return 'Personal Premium';
    case UserTier.pebbleHousehold:
      return 'Household';
    case UserTier.workspace:
      return 'Workspace';
    case UserTier.growth:
      return 'Growth';
    case UserTier.enterprise:
      return 'Enterprise';
  }
}

String? _providerLabel(String? provider) {
  switch (provider) {
    case 'google':
      return 'Using Google';
    case 'emailOtp':
      return 'Using email';
    case 'apple':
      return 'Using Apple';
    case null:
    case '':
      return null;
    default:
      return null;
  }
}

String _planSupportingText({required UserTier tier, required bool isSignedIn}) {
  if (tier == UserTier.personalFree && isSignedIn) {
    return 'Backup is available with Personal Premium.';
  }
  if (tier == UserTier.personalFree) {
    return 'Pebble works without an account. Your routines are stored on this device.';
  }
  if (!isSignedIn &&
      (tier == UserTier.personalPremium || tier == UserTier.pebbleHousehold)) {
    return 'Your plan is active. Sign in to resume backup.';
  }
  if (tier == UserTier.personalPremium || tier == UserTier.pebbleHousehold) {
    return 'Backup is active for supported routine data.';
  }
  return 'Workspace access is managed separately.';
}

PlanSectionAction _planActionForTier(UserTier tier) {
  if (tier == UserTier.personalFree) {
    return PlanSectionAction.upgrade;
  }
  return PlanSectionAction.managePlan;
}

String? _planActionLabelForTier(UserTier tier) {
  if (tier == UserTier.personalFree) {
    return 'Upgrade';
  }
  return 'Manage plan';
}

String _backupSummaryForState(
  PersonalCloudAccessStatus status,
  bool isSignedIn,
) {
  switch (status) {
    case PersonalCloudAccessStatus.offFree:
      return isSignedIn
          ? 'Backup is available with Personal Premium.'
          : 'Pebble works without an account. Your routines are stored on this device.';
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return 'Backup is available with Personal Premium.';
    case PersonalCloudAccessStatus.consentRequired:
      return 'Review cloud backup before upload starts.';
    case PersonalCloudAccessStatus.available:
      return 'Backup is active for supported routine data.';
    case PersonalCloudAccessStatus.syncing:
      return 'Syncing latest changes';
    case PersonalCloudAccessStatus.verificationFailed:
      return 'Premium is active, but backup could not be set up yet.';
    case PersonalCloudAccessStatus.pausedSignedOut:
      return 'Backup is paused. Sign in to resume.';
    case PersonalCloudAccessStatus.expiredGrace:
      return 'Premium recently ended. Uploads are paused.';
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return 'Backup is paused until local data is reviewed.';
    case PersonalCloudAccessStatus.offlinePending:
      return 'Waiting for connection';
    case PersonalCloudAccessStatus.error:
      return 'Backup is active, but Pebble couldn\'t finish syncing everything.';
  }
}

String? _backupDetailForState({
  required PersonalCloudAccessStatus status,
  required String? pendingChangesText,
  required String? lastError,
  required DateTime? nextRetryAt,
  required ProofMediaFairUseState? fairUseState,
}) {
  if (fairUseState?.status == ProofMediaFairUseStatus.full) {
    return 'Photo storage full. Routine sync still works.';
  }
  if (fairUseState?.status == ProofMediaFairUseStatus.warning) {
    return 'Proof photo storage is nearly full. Routine sync still works.';
  }
  switch (status) {
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return 'Upgrade when you want routine backup and restore.';
    case PersonalCloudAccessStatus.consentRequired:
      return 'Pebble needs your explicit consent before uploading routines, proof photos, history, or metadata that may reveal sensitive content.';
    case PersonalCloudAccessStatus.available:
      return pendingChangesText ?? 'All caught up';
    case PersonalCloudAccessStatus.syncing:
      return pendingChangesText ?? 'Syncing latest changes';
    case PersonalCloudAccessStatus.verificationFailed:
      return 'Try again to re-check Premium for this account.';
    case PersonalCloudAccessStatus.pausedSignedOut:
      return 'Sign in to resume backup.';
    case PersonalCloudAccessStatus.expiredGrace:
      return 'Your 21-day history stays visible for 7 days. New cloud uploads are paused.';
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return lastError ??
          'Pebble will keep existing local data local until you choose how to handle this account.';
    case PersonalCloudAccessStatus.offlinePending:
      return pendingChangesText ?? 'Waiting for connection.';
    case PersonalCloudAccessStatus.error:
      if (nextRetryAt != null) {
        return pendingChangesText ??
            'Pebble will try again soon. You can also sync now.';
      }
      return pendingChangesText ?? lastError ?? 'Try again to finish syncing.';
  }
}

BackupSectionAction _primaryBackupActionForState(
  PersonalCloudAccessStatus status,
) {
  switch (status) {
    case PersonalCloudAccessStatus.consentRequired:
      return BackupSectionAction.enableCloudBackup;
    case PersonalCloudAccessStatus.available:
      return BackupSectionAction.refreshStatus;
    case PersonalCloudAccessStatus.syncing:
    case PersonalCloudAccessStatus.offlinePending:
    case PersonalCloudAccessStatus.error:
      return BackupSectionAction.retrySync;
    case PersonalCloudAccessStatus.verificationFailed:
      return BackupSectionAction.refreshStatus;
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
    case PersonalCloudAccessStatus.pausedSignedOut:
    case PersonalCloudAccessStatus.expiredGrace:
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return BackupSectionAction.none;
  }
}

String? _primaryBackupActionLabelForState(PersonalCloudAccessStatus status) {
  switch (status) {
    case PersonalCloudAccessStatus.consentRequired:
      return 'Review and enable';
    case PersonalCloudAccessStatus.available:
      return 'Refresh status';
    case PersonalCloudAccessStatus.syncing:
    case PersonalCloudAccessStatus.error:
      return 'Sync now';
    case PersonalCloudAccessStatus.verificationFailed:
      return 'Try again';
    case PersonalCloudAccessStatus.offlinePending:
      return 'Refresh status';
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
    case PersonalCloudAccessStatus.pausedSignedOut:
    case PersonalCloudAccessStatus.expiredGrace:
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return null;
  }
}

BackupSectionAction _secondaryBackupActionForState(
  PersonalCloudAccessStatus status,
) {
  switch (status) {
    case PersonalCloudAccessStatus.syncing:
    case PersonalCloudAccessStatus.available:
      return BackupSectionAction.refreshStatus;
    case PersonalCloudAccessStatus.verificationFailed:
      return BackupSectionAction.none;
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
    case PersonalCloudAccessStatus.consentRequired:
    case PersonalCloudAccessStatus.pausedSignedOut:
    case PersonalCloudAccessStatus.expiredGrace:
    case PersonalCloudAccessStatus.accountSwitchBlocked:
    case PersonalCloudAccessStatus.offlinePending:
    case PersonalCloudAccessStatus.error:
      return BackupSectionAction.none;
  }
}

String? _secondaryBackupActionLabelForState(PersonalCloudAccessStatus status) {
  switch (status) {
    case PersonalCloudAccessStatus.syncing:
      return 'Refresh status';
    case PersonalCloudAccessStatus.available:
      return 'Restore backup';
    case PersonalCloudAccessStatus.verificationFailed:
      return null;
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
    case PersonalCloudAccessStatus.consentRequired:
    case PersonalCloudAccessStatus.pausedSignedOut:
    case PersonalCloudAccessStatus.expiredGrace:
    case PersonalCloudAccessStatus.accountSwitchBlocked:
    case PersonalCloudAccessStatus.offlinePending:
    case PersonalCloudAccessStatus.error:
      return null;
  }
}

bool _looksOffline(String? error) {
  if (error == null || error.isEmpty) {
    return false;
  }
  final normalized = error.toLowerCase();
  return normalized.contains('offline') ||
      normalized.contains('socketexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('network is unreachable') ||
      normalized.contains('connection closed') ||
      normalized.contains('timed out') ||
      normalized.contains('timeout') ||
      normalized.contains('network request failed');
}

String _relativeTimestamp(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) {
    return 'just now';
  }
  if (diff.inHours < 1) {
    final minutes = diff.inMinutes;
    return '$minutes minute${minutes == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 1) {
    final hours = diff.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }
  final days = diff.inDays;
  return '$days day${days == 1 ? '' : 's'} ago';
}
