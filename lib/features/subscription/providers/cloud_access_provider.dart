import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
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
  final entitlement = ref.watch(entitlementStateProvider);
  final auth = ref.watch(authSessionProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  final consent = auth.isSignedIn && entitlement.isPersonalPaid
      ? ref.watch(cloudBackupConsentControllerProvider)
      : const CloudBackupConsentState(
          isLoading: false,
          record: null,
          lastError: null,
        );

  if (!entitlement.isPersonalPaid) {
    return auth.isSignedIn
        ? const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.offSignedInNoEntitlement,
            label: 'Cloud backup is off',
            detail: 'This plan stays local on this device.',
          )
        : const PersonalCloudAccessState(
            status: PersonalCloudAccessStatus.offFree,
            label: 'Cloud backup is off',
            detail: 'Sign in and Personal Premium are both required for backup.',
          );
  }

  if (!auth.isSignedIn) {
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.pausedSignedOut,
      label: 'Backup is paused',
      detail: 'Sign in again to continue backup and sync.',
    );
  }

  if (!consent.isAccepted) {
    return const PersonalCloudAccessState(
      status: PersonalCloudAccessStatus.consentRequired,
      label: 'Review cloud backup',
      detail:
          'Before Pebble uploads supported routine data, confirm that cloud backup may include sensitive content.',
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
  final entitlement = ref.watch(entitlementStateProvider);
  final workspace = ref.watch(workspaceAccessProvider);
  final cachedOwnerUserId = account.userId != null && account.userId!.isNotEmpty
      ? account.userId
      : null;
  final consentAccepted = auth.isSignedIn && entitlement.isPersonalPaid
      ? ref.watch(cloudBackupConsentControllerProvider).isAccepted
      : false;

  return CloudAccessPolicy(
    cachedOwnerUserId: cachedOwnerUserId,
    personalCloudEnabled:
        auth.isSignedIn &&
        entitlement.isPersonalPaid &&
        consentAccepted &&
        cachedOwnerUserId != null,
    canQueuePersonalSync:
        auth.isSignedIn &&
        entitlement.isPersonalPaid &&
        consentAccepted &&
        cachedOwnerUserId != null,
    workspaceCloudEnabled: auth.isSignedIn && workspace.isCloudEnabled,
    isSignedIn: auth.isSignedIn,
  );
});
