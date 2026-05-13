import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';

enum AccountStatusAction {
  none,
  startPremium,
  renewPremium,
  restorePurchase,
  signIn,
  reviewBackup,
  syncNow,
  managePlan,
  reviewLocalData,
  keepLocal,
  pauseBackup,
}

enum AccountStatusTone { neutral, ready, active, paused, attention }

class AccountStatusPresentation {
  const AccountStatusPresentation({
    required this.title,
    required this.body,
    required this.statusLabel,
    required this.historyLabel,
    required this.primaryAction,
    required this.primaryActionLabel,
    required this.secondaryAction,
    required this.secondaryActionLabel,
    required this.supportingDetail,
    required this.tone,
    required this.icon,
    required this.isSyncRunning,
    required this.showRunSyncState,
    required this.showPremiumNote,
  });

  final String title;
  final String body;
  final String statusLabel;
  final String historyLabel;
  final AccountStatusAction primaryAction;
  final String? primaryActionLabel;
  final AccountStatusAction secondaryAction;
  final String? secondaryActionLabel;
  final String? supportingDetail;
  final AccountStatusTone tone;
  final IconData icon;
  final bool isSyncRunning;
  final bool showRunSyncState;
  final bool showPremiumNote;
}

final accountStatusPresentationProvider = Provider<AccountStatusPresentation>((
  ref,
) {
  final auth = ref.watch(authSessionProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  final entitlement = ref.watch(entitlementStateProvider);
  final lifecycle = ref.watch(subscriptionLifecycleProvider);
  final status = ref.watch(effectivePersonalCloudStatusProvider);
  final runtime = ref.watch(cloudSyncRuntimeStateProvider);
  final purchase = ref.watch(purchaseRepositoryProvider);
  final fairUse = ref
      .watch(proofMediaFairUseStateProvider)
      .maybeWhen(data: (value) => value, orElse: () => null);

  final lastBackup = account.lastSyncAt == null
      ? null
      : 'Last backed up: ${_relativeTimestamp(account.lastSyncAt!)}';
  final restoreAction = purchase.isPurchaseAvailable
      ? AccountStatusAction.restorePurchase
      : AccountStatusAction.none;
  final restoreLabel = purchase.isPurchaseAvailable ? 'Restore purchase' : null;

  if (runtime.isRunning) {
    return AccountStatusPresentation(
      title: 'Backing up now',
      body: 'Pebble is saving your latest changes.',
      statusLabel: 'Backing up now',
      historyLabel: 'Backing up now',
      primaryAction: AccountStatusAction.none,
      primaryActionLabel: null,
      secondaryAction: AccountStatusAction.managePlan,
      secondaryActionLabel: 'Manage plan',
      supportingDetail: lastBackup,
      tone: AccountStatusTone.active,
      icon: LucideIcons.refreshCw,
      isSyncRunning: true,
      showRunSyncState: true,
      showPremiumNote: false,
    );
  }

  if (status == PersonalCloudAccessStatus.accountSwitchBlocked) {
    final unownedOnly = _looksLikeUnownedLocalData(account.lastSyncError);
    return AccountStatusPresentation(
      title: unownedOnly
          ? 'Choose what happens to this device\'s data'
          : 'Backup is paused',
      body: unownedOnly
          ? 'This device already has Pebble data. You can link it to your signed-in account, or keep it only on this device.'
          : 'Some Pebble data on this device belongs to another account. Pebble will not upload it to this account.',
      statusLabel: 'Backup is paused',
      historyLabel: 'Backup is paused',
      primaryAction: AccountStatusAction.reviewLocalData,
      primaryActionLabel: unownedOnly ? 'Review local data' : 'Review',
      secondaryAction: unownedOnly
          ? AccountStatusAction.keepLocal
          : AccountStatusAction.none,
      secondaryActionLabel: unownedOnly ? 'Keep local for now' : null,
      supportingDetail: null,
      tone: AccountStatusTone.attention,
      icon: LucideIcons.shieldAlert,
      isSyncRunning: false,
      showRunSyncState: false,
      showPremiumNote: false,
    );
  }

  if (!purchase.isPurchaseAvailable && !entitlement.isPersonalPaid) {
    return AccountStatusPresentation(
      title: 'Premium isn\'t available yet',
      body:
          'Premium is not ready in Google Play yet. Pebble still works on this device.',
      statusLabel: 'Stored on this device',
      historyLabel: 'Stored on this device',
      primaryAction: AccountStatusAction.none,
      primaryActionLabel: null,
      secondaryAction: restoreAction,
      secondaryActionLabel: restoreLabel,
      supportingDetail:
          'You have not done anything wrong. This build is waiting for store setup.',
      tone: AccountStatusTone.neutral,
      icon: LucideIcons.clock3,
      isSyncRunning: false,
      showRunSyncState: false,
      showPremiumNote: false,
    );
  }

  if (lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace) {
    return AccountStatusPresentation(
      title: 'Premium recently ended',
      body:
          'Your extended history is still available for now. Renew Premium to keep backup on.',
      statusLabel: 'Backup is paused',
      historyLabel: 'Backup is paused',
      primaryAction: purchase.isPurchaseAvailable
          ? AccountStatusAction.renewPremium
          : AccountStatusAction.none,
      primaryActionLabel: purchase.isPurchaseAvailable ? 'Renew Premium' : null,
      secondaryAction: AccountStatusAction.managePlan,
      secondaryActionLabel: 'Manage plan',
      supportingDetail: null,
      tone: AccountStatusTone.paused,
      icon: LucideIcons.clock3,
      isSyncRunning: false,
      showRunSyncState: false,
      showPremiumNote: false,
    );
  }

  if (lifecycle.phase == SubscriptionLifecyclePhase.expired) {
    return AccountStatusPresentation(
      title: 'Stored on this device',
      body: 'Pebble is using the free history window again.',
      statusLabel: 'Stored on this device',
      historyLabel: 'Stored on this device',
      primaryAction: purchase.isPurchaseAvailable
          ? AccountStatusAction.startPremium
          : AccountStatusAction.none,
      primaryActionLabel: purchase.isPurchaseAvailable ? 'Start Premium' : null,
      secondaryAction: restoreAction,
      secondaryActionLabel: restoreLabel,
      supportingDetail: null,
      tone: AccountStatusTone.neutral,
      icon: LucideIcons.hardDrive,
      isSyncRunning: false,
      showRunSyncState: false,
      showPremiumNote: true,
    );
  }

  switch (status) {
    case PersonalCloudAccessStatus.offFree:
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return AccountStatusPresentation(
        title: 'Stored on this device',
        body:
            'Pebble works without an account. Free keeps your recent history on this device.',
        statusLabel: 'Stored on this device',
        historyLabel: 'Stored on this device',
        primaryAction: purchase.isPurchaseAvailable
            ? AccountStatusAction.startPremium
            : AccountStatusAction.none,
        primaryActionLabel: purchase.isPurchaseAvailable
            ? 'Start Premium'
            : null,
        secondaryAction: restoreAction,
        secondaryActionLabel: restoreLabel,
        supportingDetail: auth.isSignedIn
            ? 'Signed in as ${auth.email ?? 'your account'}.'
            : null,
        tone: AccountStatusTone.neutral,
        icon: LucideIcons.hardDrive,
        isSyncRunning: false,
        showRunSyncState: false,
        showPremiumNote: true,
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
      return const AccountStatusPresentation(
        title: 'Premium active',
        body: 'Sign in if you want backup and account recovery.',
        statusLabel: 'Backup is paused',
        historyLabel: 'Waiting for sign-in',
        primaryAction: AccountStatusAction.signIn,
        primaryActionLabel: 'Sign in',
        secondaryAction: AccountStatusAction.managePlan,
        secondaryActionLabel: 'Manage plan',
        supportingDetail: null,
        tone: AccountStatusTone.ready,
        icon: LucideIcons.shieldCheck,
        isSyncRunning: false,
        showRunSyncState: false,
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.consentRequired:
      return AccountStatusPresentation(
        title: 'Ready to turn on backup',
        body: 'Nothing is uploaded until you choose to turn backup on.',
        statusLabel: 'Ready to turn on backup',
        historyLabel: 'Ready to turn on backup',
        primaryAction: AccountStatusAction.reviewBackup,
        primaryActionLabel: 'Review backup',
        secondaryAction: AccountStatusAction.managePlan,
        secondaryActionLabel: 'Manage plan',
        supportingDetail: auth.email == null
            ? null
            : 'Signed in as ${auth.email}.',
        tone: AccountStatusTone.ready,
        icon: LucideIcons.fileCheck,
        isSyncRunning: false,
        showRunSyncState: false,
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.available:
    case PersonalCloudAccessStatus.syncing:
      return AccountStatusPresentation(
        title: 'Backup is on',
        body: 'Pebble is keeping your recent history backed up.',
        statusLabel: 'Backup is on',
        historyLabel: 'Backup is on',
        primaryAction: AccountStatusAction.none,
        primaryActionLabel: null,
        secondaryAction: AccountStatusAction.managePlan,
        secondaryActionLabel: 'Manage plan',
        supportingDetail: _fairUseDetail(fairUse) ?? lastBackup,
        tone: AccountStatusTone.active,
        icon: LucideIcons.cloudCheck,
        isSyncRunning: false,
        showRunSyncState: true,
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.offlinePending:
      return AccountStatusPresentation(
        title: 'Backup is paused',
        body:
            'Pebble will save your latest changes when the connection is back.',
        statusLabel: 'Backup is paused',
        historyLabel: 'Backup is paused',
        primaryAction: AccountStatusAction.syncNow,
        primaryActionLabel: 'Try now',
        secondaryAction: AccountStatusAction.managePlan,
        secondaryActionLabel: 'Manage plan',
        supportingDetail: lastBackup,
        tone: AccountStatusTone.paused,
        icon: LucideIcons.wifiOff,
        isSyncRunning: false,
        showRunSyncState: true,
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.error:
      return AccountStatusPresentation(
        title: 'Backup needs attention',
        body: 'Pebble could not finish saving the latest changes.',
        statusLabel: 'Backup needs attention',
        historyLabel: 'Backup is paused',
        primaryAction: AccountStatusAction.syncNow,
        primaryActionLabel: 'Try again',
        secondaryAction: AccountStatusAction.managePlan,
        secondaryActionLabel: 'Manage plan',
        supportingDetail: lastBackup,
        tone: AccountStatusTone.attention,
        icon: LucideIcons.cloudAlert,
        isSyncRunning: false,
        showRunSyncState: true,
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.expiredGrace:
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      throw StateError('Handled before switch.');
  }
});

String? _fairUseDetail(ProofMediaFairUseState? state) {
  if (state?.status == ProofMediaFairUseStatus.full) {
    return 'Photo storage is full. Routine backup still works.';
  }
  if (state?.status == ProofMediaFairUseStatus.warning) {
    return 'Photo storage is nearly full.';
  }
  return null;
}

bool _looksLikeUnownedLocalData(String? error) {
  if (error == null || error.isEmpty) {
    return false;
  }
  return error.toLowerCase().contains('not linked to this account');
}

String _relativeTimestamp(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  return '${diff.inDays}d ago';
}
