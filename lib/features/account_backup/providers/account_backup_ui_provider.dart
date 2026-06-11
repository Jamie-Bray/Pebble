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
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

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

/// Items whose automatic retries have given up (parked ~a year out). They
/// only sync again via a user-initiated "Back up now".
final stuckSyncCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(localDbProvider);
  return db.syncOutboxDao.watchItems().map(
    (rows) => rows
        .where(
          (row) =>
              row.attemptCount >=
              SyncOutboxRepositoryImpl.stuckAttemptThreshold,
        )
        .length,
  );
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
      ? ' $pendingCount change${pendingCount == 1 ? '' : 's'} waiting to back up.'
      : '';

  if (runtime.isRunning) {
    return AccountBackupStatusSummary(
      kind: AccountBackupStatusKind.syncing,
      label: 'Backing up now',
      detail: pendingCount > 0
          ? '$pendingCount change${pendingCount == 1 ? '' : 's'} backing up now.'
          : 'Pebble is saving your latest changes.',
      historyLabel: 'Backing up now',
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
          historyLabel: 'Saved on this phone',
          showRunSyncState: false,
        );
      }
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.localOnly,
        label: 'Saved on this phone',
        detail:
            'Everything works on this phone without an account. Free keeps the last 48 hours of history.',
        historyLabel: 'Saved on this phone',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.waitingForSignIn,
        label: 'Sign in to back up',
        detail:
            'You have Premium. Sign in again and backup will carry on. Your routines stay on this phone.',
        historyLabel: 'Sign in to back up',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.consentRequired:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.waitingForConsent,
        label: 'Ready to turn on',
        detail:
            'Premium and sign-in are ready. Backup starts only when you turn it on.',
        historyLabel: 'Ready to turn on',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.available:
      return AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.ready,
        label: 'Backup is on',
        detail: 'Your routines are kept safe for restore.$pendingDetail',
        historyLabel: 'Backup is on',
        showRunSyncState: true,
      );
    case PersonalCloudAccessStatus.syncing:
      if (baseAccess.label == 'Checking backup') {
        return const AccountBackupStatusSummary(
          kind: AccountBackupStatusKind.premiumSetupPending,
          label: 'Checking backup',
          detail: 'Premium is active. Pebble is getting backup ready.',
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
        label: 'Backup needs another try',
        detail:
            'Premium is active, but backup setup didn\'t finish. Try again.',
        historyLabel: 'Backup pending',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.expiredGrace:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.paused,
        label: 'Backup is off',
        detail:
            'Backup stopped when Premium ended. Your 21-day history stays visible for 7 days.',
        historyLabel: 'Backup is off',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.blocked,
        label: 'Choose an account',
        detail:
            'This phone has routines from a different account. They stay here until you choose what to do.',
        historyLabel: 'Choose an account',
        showRunSyncState: false,
      );
    case PersonalCloudAccessStatus.offlinePending:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.waitingForConnection,
        label: 'Waiting for internet',
        detail:
            'Changes are saved on this phone and will back up when Pebble is online.',
        historyLabel: 'Waiting for internet',
        showRunSyncState: true,
      );
    case PersonalCloudAccessStatus.error:
      return const AccountBackupStatusSummary(
        kind: AccountBackupStatusKind.attention,
        label: 'Backup needs attention',
        detail:
            'The last backup didn\'t finish. Your changes are still saved on this phone.',
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
      // Free users still get a door to backup from Home; hiding it was why
      // backup felt buried inside account settings.
      return const AccountBackupChipState(
        show: true,
        label: 'Backup off',
        tone: AccountBackupChipTone.neutral,
        semanticsHint:
            'Backup is off. Tap to keep a safe copy of your routines.',
      );
    case PersonalCloudAccessStatus.consentRequired:
      return const AccountBackupChipState(
        show: true,
        label: 'Set up backup',
        tone: AccountBackupChipTone.attention,
        semanticsHint: 'Backup is ready to turn on.',
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
      return const AccountBackupChipState(
        show: true,
        label: 'Sign in to back up',
        tone: AccountBackupChipTone.neutral,
        semanticsHint: 'Sign in again and backup will carry on.',
      );
    case PersonalCloudAccessStatus.expiredGrace:
      return const AccountBackupChipState(
        show: true,
        label: 'Backup off',
        tone: AccountBackupChipTone.neutral,
        semanticsHint: 'Backup ended with Premium. Tap for details.',
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return const AccountBackupChipState(
        show: true,
        label: 'Choose account',
        tone: AccountBackupChipTone.attention,
        semanticsHint: 'Choose which account this phone backs up to.',
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
      : 'Your routines are saved on this phone.';

  final planName = _planLabel(entitlement.personalTier);
  final planSupportingText = _planSupportingText(
    tier: entitlement.personalTier,
    isSignedIn: auth.isSignedIn,
  );

  final lastSyncText = account.lastSyncAt == null
      ? null
      : 'Last backed up ${_relativeTimestamp(account.lastSyncAt!)}';
  final pendingChangesText = pendingCount > 0
      ? '$pendingCount change${pendingCount == 1 ? '' : 's'} waiting to back up'
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
    return 'Backup comes with Premium.';
  }
  if (tier == UserTier.personalFree) {
    return 'Pebble works without an account. Your routines are saved on this phone.';
  }
  if (!isSignedIn &&
      (tier == UserTier.personalPremium || tier == UserTier.pebbleHousehold)) {
    return 'Your plan is active. Sign in and backup will carry on.';
  }
  if (tier == UserTier.personalPremium || tier == UserTier.pebbleHousehold) {
    return 'Your routines are backed up.';
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
          ? 'Backup comes with Premium.'
          : 'Pebble works without an account. Your routines are saved on this phone.';
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return 'Backup comes with Premium.';
    case PersonalCloudAccessStatus.consentRequired:
      return 'Backup is ready to turn on.';
    case PersonalCloudAccessStatus.available:
      return 'Your routines are backed up.';
    case PersonalCloudAccessStatus.syncing:
      return 'Saving your latest changes';
    case PersonalCloudAccessStatus.verificationFailed:
      return 'Premium is active, but backup setup didn\'t finish.';
    case PersonalCloudAccessStatus.pausedSignedOut:
      return 'Sign in again and backup will carry on.';
    case PersonalCloudAccessStatus.expiredGrace:
      return 'Backup stopped when Premium ended.';
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return 'Choose which account this phone backs up to.';
    case PersonalCloudAccessStatus.offlinePending:
      return 'Waiting for internet';
    case PersonalCloudAccessStatus.error:
      return 'The last backup didn\'t finish.';
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
    return 'Photo storage full. Routine backup still works.';
  }
  if (fairUseState?.status == ProofMediaFairUseStatus.warning) {
    return 'Proof photo storage is nearly full. Routine backup still works.';
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
      return pendingChangesText ?? 'Saving your latest changes';
    case PersonalCloudAccessStatus.verificationFailed:
      return 'Try again to re-check Premium for this account.';
    case PersonalCloudAccessStatus.pausedSignedOut:
      return 'Sign in again and backup will carry on.';
    case PersonalCloudAccessStatus.expiredGrace:
      return 'Your 21-day history stays visible for 7 days. Backup stopped when Premium ended.';
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return lastError ??
          'Pebble will keep existing local data local until you choose how to handle this account.';
    case PersonalCloudAccessStatus.offlinePending:
      return pendingChangesText ?? 'Waiting for internet.';
    case PersonalCloudAccessStatus.error:
      if (nextRetryAt != null) {
        return pendingChangesText ??
            'Pebble will try again soon. You can also try now.';
      }
      return pendingChangesText ?? lastError ?? 'Try again to finish backup.';
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
      return 'Back up now';
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
