import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';

enum AccountProfileBackupTone { neutral, active, paused, attention }

class AccountProfileLimit {
  const AccountProfileLimit({required this.value, required this.label});

  final String value;
  final String label;
}

class AccountProfileBackupRow {
  const AccountProfileBackupRow({
    required this.label,
    required this.detail,
    required this.trailing,
    required this.icon,
    required this.tone,
    required this.needsAttention,
  });

  final String label;
  final String detail;
  final String? trailing;
  final IconData icon;
  final AccountProfileBackupTone tone;
  final bool needsAttention;
}

class AccountProfilePresentation {
  const AccountProfilePresentation({
    required this.isSignedIn,
    required this.identityLabel,
    required this.identityDetail,
    required this.providerLabel,
    required this.planName,
    required this.planDetail,
    required this.planStatusLabel,
    required this.limits,
    required this.canStartPremium,
    required this.canRestorePurchase,
    required this.canManagePlan,
    required this.backupRow,
  });

  final bool isSignedIn;
  final String identityLabel;
  final String identityDetail;
  final String? providerLabel;
  final String planName;
  final String planDetail;
  final String planStatusLabel;
  final List<AccountProfileLimit> limits;
  final bool canStartPremium;
  final bool canRestorePurchase;
  final bool canManagePlan;
  final AccountProfileBackupRow backupRow;
}

final accountProfilePresentationProvider = Provider<AccountProfilePresentation>(
  (ref) {
    final auth = ref.watch(authSessionProvider);
    final purchase = ref.watch(purchaseRepositoryProvider);
    final entitlement = ref.watch(entitlementStateProvider);
    final policy = ref.watch(premiumFeaturePolicyProvider);
    final lifecycle = ref.watch(subscriptionLifecycleProvider);
    final account = ref.watch(subscriptionAccountControllerProvider);
    final status = ref.watch(effectivePersonalCloudStatusProvider);
    final runtime = ref.watch(cloudSyncRuntimeStateProvider);
    final limits = _limitsFor(policy);
    final hasLocalPremium =
        policy.localPremiumAccess == LocalPremiumAccess.active ||
        policy.localPremiumAccess == LocalPremiumAccess.historyGrace;

    return AccountProfilePresentation(
      isSignedIn: auth.isSignedIn,
      identityLabel: auth.isSignedIn
          ? (auth.email ?? 'Your account')
          : 'Not signed in',
      identityDetail: auth.isSignedIn
          ? 'Backup and restore use this account.'
          : 'Pebble works locally without an account.',
      providerLabel: _providerLabel(auth.provider),
      planName: _planName(entitlement.personalTier, lifecycle),
      planDetail: _planDetail(
        policy: policy,
        purchase: purchase,
        accountError: account.entitlementError,
      ),
      planStatusLabel: _planStatusLabel(policy),
      limits: limits,
      canStartPremium:
          !hasLocalPremium &&
          purchase.isPurchaseAvailable &&
          entitlement.personalTier == UserTier.personalFree,
      canRestorePurchase: purchase.isPurchaseAvailable,
      canManagePlan: hasLocalPremium && purchase.manageSubscriptionsUrl != null,
      backupRow: _backupRowFor(
        status: status,
        isSignedIn: auth.isSignedIn,
        lastSyncAt: account.lastSyncAt,
        accountError: account.lastSyncError,
        isSyncRunning: runtime.isRunning,
      ),
    );
  },
);

List<AccountProfileLimit> _limitsFor(PremiumFeaturePolicy policy) {
  if (policy.localPremiumAccess == LocalPremiumAccess.historyGrace) {
    return const [
      AccountProfileLimit(value: '21 days', label: 'History kept'),
      AccountProfileLimit(value: '2', label: 'Routines'),
      AccountProfileLimit(value: '10', label: 'Steps each'),
    ];
  }
  if (policy.hasActiveLocalPremium) {
    return const [
      AccountProfileLimit(value: '21 days', label: 'History kept'),
      AccountProfileLimit(value: 'Unlimited', label: 'Routines'),
      AccountProfileLimit(value: 'Unlimited', label: 'Steps each'),
    ];
  }
  return const [
    AccountProfileLimit(value: '48h', label: 'History kept'),
    AccountProfileLimit(value: '2', label: 'Routines'),
    AccountProfileLimit(value: '10', label: 'Steps each'),
  ];
}

String _planName(UserTier tier, SubscriptionLifecycle lifecycle) {
  if (lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace) {
    return 'Premium recently ended';
  }
  if (lifecycle.phase == SubscriptionLifecyclePhase.expired) {
    return 'Free plan';
  }
  switch (tier) {
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
    case UserTier.personalFree:
      return 'Free plan';
  }
}

String _planDetail({
  required PremiumFeaturePolicy policy,
  required PurchaseRepository purchase,
  required String? accountError,
}) {
  if (policy.localPremiumAccess == LocalPremiumAccess.unavailable) {
    return purchase.unavailableReason ?? 'Premium is not available yet.';
  }
  if (policy.localPremiumAccess == LocalPremiumAccess.historyGrace) {
    return 'Your longer history is still available during grace.';
  }
  if (policy.localPremiumAccess == LocalPremiumAccess.expired) {
    return 'Pebble is using Free limits again.';
  }
  if (policy.hasActiveLocalPremium) {
    if (policy.serverFeatureStatus == ServerFeatureStatus.verificationFailed) {
      return accountError ?? 'Backup verification needs another check.';
    }
    return 'Unlimited routines, unlimited steps, and longer history are active.';
  }
  return 'Upgrade when you want unlimited routines, longer history, and backup.';
}

String _planStatusLabel(PremiumFeaturePolicy policy) {
  switch (policy.localPremiumAccess) {
    case LocalPremiumAccess.active:
      return 'Premium active';
    case LocalPremiumAccess.historyGrace:
      return 'Grace period';
    case LocalPremiumAccess.expired:
      return 'Premium ended';
    case LocalPremiumAccess.loading:
      return 'Checking plan';
    case LocalPremiumAccess.unavailable:
      return 'Store unavailable';
    case LocalPremiumAccess.free:
      return 'Free';
  }
}

AccountProfileBackupRow _backupRowFor({
  required PersonalCloudAccessStatus status,
  required bool isSignedIn,
  required DateTime? lastSyncAt,
  required String? accountError,
  required bool isSyncRunning,
}) {
  final lastSyncText = lastSyncAt == null
      ? null
      : 'Last backed up ${_relativeTimestamp(lastSyncAt)}';
  switch (status) {
    case PersonalCloudAccessStatus.offFree:
      return const AccountProfileBackupRow(
        label: 'Backup',
        detail: 'Keep a safe copy of your routines.',
        trailing: 'Off',
        icon: LucideIcons.cloud,
        tone: AccountProfileBackupTone.neutral,
        needsAttention: false,
      );
    case PersonalCloudAccessStatus.offSignedInNoEntitlement:
      return const AccountProfileBackupRow(
        label: 'Backup',
        detail: 'Keep a safe copy of your routines. Comes with Premium.',
        trailing: 'Off',
        icon: LucideIcons.cloud,
        tone: AccountProfileBackupTone.neutral,
        needsAttention: false,
      );
    case PersonalCloudAccessStatus.pausedSignedOut:
      return const AccountProfileBackupRow(
        label: 'Backup',
        detail: 'Sign in again and backup will carry on.',
        trailing: 'Sign in',
        icon: LucideIcons.cloudOff,
        tone: AccountProfileBackupTone.paused,
        needsAttention: true,
      );
    case PersonalCloudAccessStatus.consentRequired:
      return const AccountProfileBackupRow(
        label: 'Backup',
        detail: 'One tap to turn on.',
        trailing: 'Ready',
        icon: LucideIcons.fileCheck,
        tone: AccountProfileBackupTone.attention,
        needsAttention: true,
      );
    case PersonalCloudAccessStatus.available:
      return AccountProfileBackupRow(
        label: 'Backup',
        detail: lastSyncText ?? 'Your routines are backed up.',
        trailing: 'On',
        icon: LucideIcons.cloudCheck,
        tone: AccountProfileBackupTone.active,
        needsAttention: false,
      );
    case PersonalCloudAccessStatus.syncing:
      if (isSyncRunning) {
        return const AccountProfileBackupRow(
          label: 'Backup',
          detail: 'Saving your latest changes now.',
          trailing: 'Backing up',
          icon: LucideIcons.refreshCw,
          tone: AccountProfileBackupTone.active,
          needsAttention: false,
        );
      }
      return const AccountProfileBackupRow(
        label: 'Backup',
        detail: 'Getting backup ready.',
        trailing: 'Checking',
        icon: LucideIcons.refreshCw,
        tone: AccountProfileBackupTone.neutral,
        needsAttention: false,
      );
    case PersonalCloudAccessStatus.verificationFailed:
      return const AccountProfileBackupRow(
        label: 'Backup',
        detail: 'Premium is active, but setup needs another try.',
        trailing: 'Try again',
        icon: LucideIcons.cloudAlert,
        tone: AccountProfileBackupTone.attention,
        needsAttention: true,
      );
    case PersonalCloudAccessStatus.expiredGrace:
      return const AccountProfileBackupRow(
        label: 'Backup',
        detail: 'Backup stopped when Premium ended. Your routines stay on this phone.',
        trailing: 'Off',
        icon: LucideIcons.cloudOff,
        tone: AccountProfileBackupTone.paused,
        needsAttention: false,
      );
    case PersonalCloudAccessStatus.accountSwitchBlocked:
      return AccountProfileBackupRow(
        label: 'Backup',
        detail:
            accountError ??
            'This phone has routines from a different account. Choose what to do.',
        trailing: 'Choose',
        icon: LucideIcons.shieldAlert,
        tone: AccountProfileBackupTone.attention,
        needsAttention: true,
      );
    case PersonalCloudAccessStatus.offlinePending:
      return AccountProfileBackupRow(
        label: 'Backup',
        detail: lastSyncText ?? 'Will back up when you\'re online.',
        trailing: 'Offline',
        icon: LucideIcons.wifiOff,
        tone: AccountProfileBackupTone.paused,
        needsAttention: true,
      );
    case PersonalCloudAccessStatus.error:
      return AccountProfileBackupRow(
        label: 'Backup',
        detail: lastSyncText ?? 'The last backup didn\'t finish.',
        trailing: 'Needs attention',
        icon: LucideIcons.cloudAlert,
        tone: AccountProfileBackupTone.attention,
        needsAttention: true,
      );
  }
}

String? _providerLabel(String? provider) {
  switch (provider) {
    case 'google':
      return 'Google';
    case 'emailOtp':
      return 'Email';
    case 'apple':
      return 'Apple';
    case null:
    case '':
      return null;
    default:
      return provider;
  }
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
