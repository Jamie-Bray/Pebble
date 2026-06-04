import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';

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
    required this.planLabel,
    required this.title,
    required this.body,
    required this.statusLabel,
    required this.historyLabel,
    required this.limitChips,
    required this.featureHighlights,
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

  final String planLabel;
  final String title;
  final String body;
  final String statusLabel;
  final String historyLabel;
  final List<AccountPlanChip> limitChips;
  final List<AccountFeatureHighlight> featureHighlights;
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

class AccountPlanChip {
  const AccountPlanChip({required this.value, required this.label});

  final String value;
  final String label;
}

class AccountFeatureHighlight {
  const AccountFeatureHighlight({required this.emphasis, required this.detail});

  final String emphasis;
  final String detail;
}

final accountStatusPresentationProvider = Provider<AccountStatusPresentation>((
  ref,
) {
  final auth = ref.watch(authSessionProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  final entitlement = ref.watch(entitlementStateProvider);
  final lifecycle = ref.watch(subscriptionLifecycleProvider);
  final premiumPolicy = ref.watch(premiumFeaturePolicyProvider);
  final status = ref.watch(effectivePersonalCloudStatusProvider);
  final runtime = ref.watch(cloudSyncRuntimeStateProvider);
  final purchase = ref.watch(purchaseRepositoryProvider);
  final backedUpRoutineCount = ref
      .watch(routineListProvider)
      .maybeWhen(
        data: (routines) => routines
            .where(
              (routine) =>
                  routine.syncStatus == 'synced' ||
                  routine.lastSyncedAt != null,
            )
            .length,
        orElse: () => null,
      );
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
  final planFacts = _planFacts(policy: premiumPolicy);

  if (runtime.isRunning) {
    return AccountStatusPresentation(
      planLabel: planFacts.label,
      title: 'Backing up now',
      body: 'Pebble is saving your latest changes.',
      statusLabel: 'Backing up now',
      historyLabel: 'Backing up now',
      limitChips: planFacts.chips,
      featureHighlights: const [],
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
      planLabel: planFacts.label,
      title: unownedOnly
          ? 'Choose what happens to this device\'s data'
          : 'Backup is paused',
      body: unownedOnly
          ? 'This device already has Pebble data. You can link it to your signed-in account, or keep it only on this device.'
          : 'Some Pebble data on this device belongs to another account. Pebble will not upload it to this account.',
      statusLabel: 'Backup is paused',
      historyLabel: 'Backup is paused',
      limitChips: planFacts.chips,
      featureHighlights: const [],
      primaryAction: AccountStatusAction.reviewLocalData,
      primaryActionLabel: unownedOnly ? 'Review local data' : 'Review',
      secondaryAction: unownedOnly
          ? AccountStatusAction.keepLocal
          : AccountStatusAction.none,
      secondaryActionLabel: unownedOnly ? 'Keep local' : null,
      supportingDetail: null,
      tone: AccountStatusTone.attention,
      icon: LucideIcons.shieldAlert,
      isSyncRunning: false,
      showRunSyncState: false,
      showPremiumNote: false,
    );
  }

  if (!purchase.isPurchaseAvailable &&
      !entitlement.isPersonalPaid &&
      purchase.unavailableReason != null) {
    return AccountStatusPresentation(
      planLabel: planFacts.label,
      title: 'Premium isn\'t available yet',
      body:
          purchase.unavailableReason ??
          'Premium is not ready in Google Play yet. Pebble still works on this device.',
      statusLabel: 'Stored on this device',
      historyLabel: 'Stored on this device',
      limitChips: planFacts.chips,
      featureHighlights: const [],
      primaryAction: AccountStatusAction.none,
      primaryActionLabel: null,
      secondaryAction: restoreAction,
      secondaryActionLabel: restoreLabel,
      supportingDetail: purchase.unavailableReason != null
          ? 'Check your connection or try again later.'
          : 'You have not done anything wrong. This build is waiting for store setup.',
      tone: AccountStatusTone.neutral,
      icon: LucideIcons.clock3,
      isSyncRunning: false,
      showRunSyncState: false,
      showPremiumNote: false,
    );
  }

  if (lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace) {
    return AccountStatusPresentation(
      planLabel: planFacts.label,
      title: 'Premium recently ended',
      body:
          'Your 21-day history is still available for 7 days. Renew Premium to keep longer history and backup.',
      statusLabel: 'Backup is paused',
      historyLabel: 'Backup is paused',
      limitChips: planFacts.chips,
      featureHighlights: const [],
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
      planLabel: planFacts.label,
      title: 'Stored on this device',
      body: 'Pebble is using the free history window again.',
      statusLabel: 'Stored on this device',
      historyLabel: 'Stored on this device',
      limitChips: planFacts.chips,
      featureHighlights: const [],
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
        planLabel: planFacts.label,
        title: 'Stored on this device',
        body:
            'Your routines stay on this device. Everything works, no account needed.',
        statusLabel: 'Stored on this device',
        historyLabel: 'Stored on this device',
        limitChips: planFacts.chips,
        featureHighlights: const [
          AccountFeatureHighlight(
            emphasis: 'Premium adds',
            detail: 'unlimited routines, unlimited steps, and backup.',
          ),
        ],
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
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
      return AccountStatusPresentation(
        planLabel: planFacts.label,
        title: 'Premium is on this device',
        body:
            'Premium is active on this device. Sign in only if you want backup and account recovery.',
        statusLabel: 'Backup is paused',
        historyLabel: 'Waiting for sign-in',
        limitChips: planFacts.chips,
        featureHighlights: const [
          AccountFeatureHighlight(
            emphasis: '21-day history',
            detail: 'is active on this device.',
          ),
          AccountFeatureHighlight(
            emphasis: 'Cloud backup',
            detail: 'is optional and needs sign-in.',
          ),
          AccountFeatureHighlight(
            emphasis: 'No account needed',
            detail: 'for extra routines and steps on this device.',
          ),
        ],
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
        planLabel: planFacts.label,
        title: 'Ready to turn on backup',
        body: 'Nothing is uploaded until you choose to turn backup on.',
        statusLabel: 'Ready to turn on backup',
        historyLabel: 'Ready to turn on backup',
        limitChips: planFacts.chips,
        featureHighlights: const [
          AccountFeatureHighlight(
            emphasis: '21 days',
            detail: 'of history once backup is on.',
          ),
          AccountFeatureHighlight(
            emphasis: 'Unlimited',
            detail: 'routines and steps are already active.',
          ),
        ],
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
      if (premiumPolicy.serverFeatureStatus == ServerFeatureStatus.verifying) {
        return AccountStatusPresentation(
          planLabel: planFacts.label,
          title: 'Premium is active',
          body:
              'Pebble is waiting for secure purchase verification before cloud backup and email alerts can start.',
          statusLabel: 'Verifying purchase',
          historyLabel: 'Backup pending',
          limitChips: planFacts.chips,
          featureHighlights: const [
            AccountFeatureHighlight(
              emphasis: 'Local Premium',
              detail: 'is unlocked on this device.',
            ),
            AccountFeatureHighlight(
              emphasis: 'Backup',
              detail: 'starts after account verification.',
            ),
          ],
          primaryAction: AccountStatusAction.restorePurchase,
          primaryActionLabel: 'Refresh status',
          secondaryAction: AccountStatusAction.managePlan,
          secondaryActionLabel: 'Manage plan',
          supportingDetail: lastBackup,
          tone: AccountStatusTone.ready,
          icon: LucideIcons.cloudUpload,
          isSyncRunning: false,
          showRunSyncState: false,
          showPremiumNote: false,
        );
      }
      return AccountStatusPresentation(
        planLabel: planFacts.label,
        title: 'Backup is on',
        body:
            'Premium keeps your history backed up, so it is safer if you change phone or reinstall Pebble.',
        statusLabel: 'Backup is on',
        historyLabel: 'Backup is on',
        limitChips: planFacts.chips,
        featureHighlights: _backupHealthHighlights(
          backedUpRoutineCount: backedUpRoutineCount,
          lastBackup: lastBackup,
        ),
        primaryAction: AccountStatusAction.none,
        primaryActionLabel: null,
        secondaryAction: AccountStatusAction.managePlan,
        secondaryActionLabel: 'Manage plan',
        supportingDetail: _fairUseDetail(fairUse),
        tone: AccountStatusTone.active,
        icon: LucideIcons.cloudCheck,
        isSyncRunning: false,
        showRunSyncState: true,
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.verificationFailed:
      return AccountStatusPresentation(
        planLabel: planFacts.label,
        title: 'Couldn\'t finish backup setup',
        body:
            'Premium is active, but backup could not be verified for this account yet.',
        statusLabel: 'Backup setup failed',
        historyLabel: 'Backup pending',
        limitChips: planFacts.chips,
        featureHighlights: const [
          AccountFeatureHighlight(
            emphasis: 'Local Premium',
            detail: 'stays unlocked on this device.',
          ),
          AccountFeatureHighlight(
            emphasis: 'Backup',
            detail: 'needs purchase verification.',
          ),
        ],
        primaryAction: AccountStatusAction.restorePurchase,
        primaryActionLabel: 'Try again',
        secondaryAction: AccountStatusAction.managePlan,
        secondaryActionLabel: 'Manage plan',
        supportingDetail:
            account.entitlementError ?? 'Try again to re-check Premium.',
        tone: AccountStatusTone.attention,
        icon: LucideIcons.cloudAlert,
        isSyncRunning: false,
        showRunSyncState: false,
        showPremiumNote: false,
      );
    case PersonalCloudAccessStatus.offlinePending:
      return AccountStatusPresentation(
        planLabel: planFacts.label,
        title: 'Backup is paused',
        body:
            'Pebble will save your latest changes when the connection is back.',
        statusLabel: 'Backup is paused',
        historyLabel: 'Backup is paused',
        limitChips: planFacts.chips,
        featureHighlights: const [],
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
        planLabel: planFacts.label,
        title: 'Backup needs attention',
        body: 'Pebble could not finish saving the latest changes.',
        statusLabel: 'Backup needs attention',
        historyLabel: 'Backup is paused',
        limitChips: planFacts.chips,
        featureHighlights: const [],
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

class _PlanFacts {
  const _PlanFacts({required this.label, required this.chips});

  final String label;
  final List<AccountPlanChip> chips;
}

_PlanFacts _planFacts({required PremiumFeaturePolicy policy}) {
  if (policy.localPremiumAccess == LocalPremiumAccess.historyGrace) {
    return const _PlanFacts(
      label: 'History access',
      chips: [
        AccountPlanChip(value: '21 days', label: 'History kept'),
        AccountPlanChip(value: '2', label: 'Routines'),
        AccountPlanChip(value: '10', label: 'Steps each'),
      ],
    );
  }

  if (policy.hasActiveLocalPremium) {
    return const _PlanFacts(
      label: 'Premium active',
      chips: [
        AccountPlanChip(value: '21 days', label: 'History kept'),
        AccountPlanChip(value: 'Unlimited', label: 'Routines'),
        AccountPlanChip(value: 'Unlimited', label: 'Steps each'),
      ],
    );
  }

  return const _PlanFacts(
    label: 'Free plan',
    chips: [
      AccountPlanChip(value: '48h', label: 'History kept'),
      AccountPlanChip(value: '2', label: 'Routines'),
      AccountPlanChip(value: '10', label: 'Steps each'),
    ],
  );
}

List<AccountFeatureHighlight> _backupHealthHighlights({
  required int? backedUpRoutineCount,
  required String? lastBackup,
}) {
  final highlights = <AccountFeatureHighlight>[];
  if (backedUpRoutineCount != null) {
    highlights.add(
      AccountFeatureHighlight(
        emphasis:
            '$backedUpRoutineCount routine${backedUpRoutineCount == 1 ? '' : 's'}',
        detail: 'backed up.',
      ),
    );
  }
  highlights.add(
    const AccountFeatureHighlight(emphasis: 'History', detail: 'backed up.'),
  );
  if (lastBackup != null) {
    highlights.add(
      AccountFeatureHighlight(
        emphasis: 'Last backup',
        detail: '${lastBackup.replaceFirst('Last backed up: ', '')}.',
      ),
    );
  }
  return highlights;
}

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
