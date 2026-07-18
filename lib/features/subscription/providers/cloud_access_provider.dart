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
      label: 'Premium ended',
      detail:
          'Backup stopped when Premium ended. Your 21-day history stays visible for 7 days.',
    );
  }

  if (!lifecycle.canUploadCloudChanges) {
    return auth.isSignedIn
        ? const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.offSignedInNoEntitlement,
            label: 'Backup is off',
            detail: 'Your routines are saved on this phone only.',
          )
        : const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.offFree,
            label: 'Backup is off',
            detail: 'Backup needs a sign-in and Premium.',
          );
  }

  if (!auth.isSignedIn) {
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.pausedSignedOut,
      label: 'Sign in to back up',
      detail: 'Sign in again and backup will carry on.',
    );
  }

  if (!hasServerVerifiedCloudEntitlement) {
    if (_looksPurchaseVerificationFailed(account.entitlementError)) {
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.verificationFailed,
        label: 'Could not finish backup setup',
        detail:
            'Premium is active, but backup could not be verified for this account yet.',
      );
    }
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.syncing,
      label: 'Checking backup',
      detail: 'Premium is active. Pebble is checking backup for this account.',
    );
  }

  if (!consent.canEnableCloudUpload) {
    if (consent.lastError != null && consent.isAccepted) {
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.offlinePending,
        label: 'Waiting for internet',
        detail:
            'Backup stays paused until Pebble can confirm this account again.',
      );
    }
    if (consent.lastError != null) {
      return PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.consentRequired,
        label: 'Backup is still off',
        detail: consent.lastError,
      );
    }
    // Consent that is still loading, or accepted but awaiting this session's
    // remote confirmation, is a transient check — not a missing consent.
    // Labelling it "turn backup on" at users whose backup was already on was
    // one of the stuck-looking states after sign-in and on offline starts.
    if (consent.isLoading || consent.isAccepted) {
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.syncing,
        label: 'Checking backup',
        detail:
            'Premium is active. Pebble is checking backup for this account.',
      );
    }
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.consentRequired,
      label: 'Ready to turn on',
      detail:
          'Backup can include private details, so Pebble asks you to confirm before it starts.',
    );
  }

  if (account.bootstrapStatus == BootstrapStatus.error &&
      _looksAccountSwitchBlocked(account.lastSyncError)) {
    return PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.accountSwitchBlocked,
      label: 'Choose an account',
      detail:
          account.lastSyncError ??
          'Pebble keeps this phone\'s routines here until you choose how to handle this account.',
    );
  }

  switch (account.bootstrapStatus) {
    case BootstrapStatus.preparing:
    case BootstrapStatus.syncing:
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.syncing,
        label: 'Turning on backup',
        detail: 'Almost there. Your routines stay on this phone too.',
      );
    case BootstrapStatus.error:
      return PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.error,
        label: 'Needs attention',
        detail: account.lastSyncError ?? 'Backup is not ready yet.',
      );
    case BootstrapStatus.idle:
      // Consent is on but the first backup pass has not run yet. This is
      // transient: sign-in, app start, and app resume all restart it.
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.syncing,
        label: 'Starting backup',
        detail: 'Backup begins in a moment.',
      );
    case BootstrapStatus.ready:
      return const PersonalCloudAccessState(
        status: PersonalCloudAccessStatus.available,
        label: 'Backup is up to date',
        detail: 'Your routines are backed up.',
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

bool _looksPurchaseVerificationFailed(String? message) {
  if (message == null || message.isEmpty) {
    return false;
  }
  final normalized = message.toLowerCase();
  return normalized.contains('backup could not be set up') ||
      normalized.contains('could not finish backup setup') ||
      normalized.contains('purchase verification');
}
