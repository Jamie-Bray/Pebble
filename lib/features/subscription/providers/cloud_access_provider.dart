import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

// Source-of-truth state matrix:
// Signed out + Free => local only.
// Signed in + Free => local only, account exists.
// Signed in + Paid + consent accepted => cloud backup/sync active.
// Signed out + Paid => cloud preserved, sign-in required to resume.
// Signed in + Paid + bootstrap pending => local writes continue while backup prepares.

final entitlementStateProvider = Provider<EntitlementState>((ref) {
  final account = ref.watch(subscriptionAccountControllerProvider);
  return EntitlementState(
    personalTier: account.entitlementTier,
    source: account.entitlementSource,
    lastCheckedAt: account.lastEntitlementCheckAt,
    isRefreshing: false,
    lastError: account.entitlementError,
    status: account.entitlementStatus,
  );
});

final workspaceAccessProvider = Provider<WorkspaceAccessState>((ref) {
  final account = ref.watch(subscriptionAccountControllerProvider);
  return WorkspaceAccessState(
    status: account.entitlementTier.isBusiness
        ? WorkspaceAccessStatus.member
        : WorkspaceAccessStatus.none,
  );
});

final personalCloudAccessProvider = Provider<PersonalCloudAccessState>((ref) {
  final auth = ref.watch(authSessionProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  final lifecycle = ref.watch(subscriptionLifecycleProvider);
  final hasServerVerifiedCloudEntitlement =
      lifecycle.canUploadCloudChanges &&
      account.entitlementSource == EntitlementSource.serverVerified;
  final consent = auth.isSignedIn && hasServerVerifiedCloudEntitlement
      ? ref.watch(cloudBackupConsentControllerProvider)
      : const CloudBackupConsentState(
          isLoading: false,
          record: null,
          lastError: null,
          isRemoteConfirmed: false,
        );

  if (lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace) {
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.expiredGrace,
      label: 'Premium grace period',
      detail:
          'Cloud uploads are paused. Your extended history stays visible during the grace period.',
    );
  }

  if (!lifecycle.canUploadCloudChanges) {
    return auth.isSignedIn
        ? const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.offSignedInNoEntitlement,
            label: 'Cloud backup is off',
            detail: 'This plan stays local on this device.',
          )
        : const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.offFree,
            label: 'Cloud backup is off',
            detail:
                'Sign in and Personal Premium are both required for backup.',
          );
  }

  if (!hasServerVerifiedCloudEntitlement) {
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.syncing,
      label: 'Finishing Premium verification',
      detail:
          'Cloud backup will unlock after RevenueCat confirms Premium with Pebble.',
    );
  }

  if (!auth.isSignedIn) {
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.pausedSignedOut,
      label: 'Backup is paused',
      detail: 'Sign in again to continue backup and sync.',
    );
  }

  if (!consent.canEnableCloudUpload) {
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.consentRequired,
      label: 'Review cloud backup',
      detail:
          'Before Pebble uploads supported routine data, confirm that cloud backup may include sensitive content.',
    );
  }

  if (account.bootstrapStatus == BootstrapStatus.error &&
      _looksAccountSwitchBlocked(account.lastSyncError)) {
    return PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.accountSwitchBlocked,
      label: 'Backup paused for safety',
      detail:
          account.lastSyncError ??
          'Pebble will keep existing local data local until you choose how to handle this account.',
    );
  }

  switch (account.bootstrapStatus) {
    case BootstrapStatus.preparing:
    case BootstrapStatus.syncing:
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.syncing,
        label: 'Syncing your routines',
        detail: 'Pebble is preparing your backup.',
      );
    case BootstrapStatus.error:
      return PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.error,
        label: 'Needs attention',
        detail: account.lastSyncError ?? 'Backup is not ready yet.',
      );
    case BootstrapStatus.idle:
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.syncing,
        label: 'Preparing your backup',
        detail: 'Pebble is getting your backup ready.',
      );
    case BootstrapStatus.ready:
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.available,
        label: 'Backup is up to date',
        detail: 'Supported routine data is synced.',
      );
  }
});

final cloudAccessPolicyProvider = Provider<CloudAccessPolicy>((ref) {
  final account = ref.watch(subscriptionAccountControllerProvider);
  final auth = ref.watch(authSessionProvider);
  final lifecycle = ref.watch(subscriptionLifecycleProvider);
  final workspace = ref.watch(workspaceAccessProvider);
  final hasServerVerifiedCloudEntitlement =
      lifecycle.canUploadCloudChanges &&
      account.entitlementSource == EntitlementSource.serverVerified;
  final cachedOwnerUserId = account.userId != null && account.userId!.isNotEmpty
      ? account.userId
      : null;
  final accountSwitchBlocked =
      account.bootstrapStatus == BootstrapStatus.error &&
      _looksAccountSwitchBlocked(account.lastSyncError);
  final consentAccepted = auth.isSignedIn && hasServerVerifiedCloudEntitlement
      ? ref.watch(cloudBackupConsentControllerProvider).canEnableCloudUpload
      : false;

  return CloudAccessPolicy(
    cachedOwnerUserId: cachedOwnerUserId,
    personalCloudEnabled:
        auth.isSignedIn &&
        hasServerVerifiedCloudEntitlement &&
        consentAccepted &&
        !accountSwitchBlocked &&
        cachedOwnerUserId != null,
    canQueuePersonalSync:
        auth.isSignedIn &&
        hasServerVerifiedCloudEntitlement &&
        consentAccepted &&
        !accountSwitchBlocked &&
        cachedOwnerUserId != null,
    workspaceCloudEnabled: auth.isSignedIn && workspace.isCloudEnabled,
    isSignedIn: auth.isSignedIn,
    isAccountSwitchBlocked: accountSwitchBlocked,
  );
});

bool _looksAccountSwitchBlocked(String? message) {
  if (message == null || message.isEmpty) {
    return false;
  }
  final normalized = message.toLowerCase();
  return normalized.contains('local data') ||
      normalized.contains('another account') ||
      normalized.contains('linked to this account') ||
      normalized.contains('without your choice');
}
