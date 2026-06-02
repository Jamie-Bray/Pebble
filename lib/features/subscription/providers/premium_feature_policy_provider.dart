import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

enum LocalPremiumAccess {
  free,
  active,
  historyGrace,
  expired,
  loading,
  unavailable,
}

enum ServerFeatureStatus {
  signedOut,
  verifying,
  ready,
  needsBackupConsent,
  error,
}

class PremiumFeaturePolicy {
  const PremiumFeaturePolicy({
    required this.localPremiumAccess,
    required this.serverFeatureStatus,
    required this.canUseUnlimitedRoutines,
    required this.canUsePremiumThemes,
    required this.canUseGuidanceAudio,
    required this.canUseExtraProofPhotos,
    required this.hasPremiumHistoryRetention,
    required this.canUseSharedAlerts,
    required this.canUseCloudBackup,
    required this.needsSignInForServerFeatures,
    required this.hasServerVerifiedPremium,
    required this.userFacingStatus,
  });

  final LocalPremiumAccess localPremiumAccess;
  final ServerFeatureStatus serverFeatureStatus;
  final bool canUseUnlimitedRoutines;
  final bool canUsePremiumThemes;
  final bool canUseGuidanceAudio;
  final bool canUseExtraProofPhotos;
  final bool hasPremiumHistoryRetention;
  final bool canUseSharedAlerts;
  final bool canUseCloudBackup;
  final bool needsSignInForServerFeatures;
  final bool hasServerVerifiedPremium;
  final String? userFacingStatus;

  bool get hasActiveLocalPremium =>
      localPremiumAccess == LocalPremiumAccess.active;

  bool get isStoreLoading => localPremiumAccess == LocalPremiumAccess.loading;

  bool get isStoreUnavailable =>
      localPremiumAccess == LocalPremiumAccess.unavailable;
}

final premiumFeaturePolicyProvider = Provider<PremiumFeaturePolicy>((ref) {
  final account = ref.watch(subscriptionAccountControllerProvider);
  final lifecycle = ref.watch(subscriptionLifecycleProvider);
  final auth = ref.watch(authSessionProvider);
  final purchase = ref.watch(purchaseRepositoryProvider);

  final hasActiveLocalPremium =
      lifecycle.phase == SubscriptionLifecyclePhase.activePremium;
  final localAccess = _localAccessFor(
    lifecycle: lifecycle,
    purchase: purchase,
    hasAnyStoredPremiumState: _hasAnyStoredPremiumState(account),
  );
  final hasServerVerifiedPremium =
      hasActiveLocalPremium &&
      account.entitlementSource == EntitlementSource.serverVerified;
  final consent = auth.isSignedIn && hasServerVerifiedPremium
      ? ref.watch(cloudBackupConsentStateProvider)
      : null;
  final serverStatus = _serverStatusFor(
    auth: auth,
    hasActiveLocalPremium: hasActiveLocalPremium,
    hasServerVerifiedPremium: hasServerVerifiedPremium,
    consent: consent,
    account: account,
  );
  final hasFeatureAccess = localAccess == LocalPremiumAccess.active;

  return PremiumFeaturePolicy(
    localPremiumAccess: localAccess,
    serverFeatureStatus: serverStatus,
    canUseUnlimitedRoutines: hasFeatureAccess,
    canUsePremiumThemes: hasFeatureAccess,
    canUseGuidanceAudio: hasFeatureAccess,
    canUseExtraProofPhotos: hasFeatureAccess,
    hasPremiumHistoryRetention: lifecycle.hasPremiumRetention,
    canUseSharedAlerts: auth.isSignedIn && hasServerVerifiedPremium,
    canUseCloudBackup:
        auth.isSignedIn &&
        hasServerVerifiedPremium &&
        consent?.canEnableCloudUpload == true &&
        !_looksAccountSwitchBlocked(account.lastSyncError),
    needsSignInForServerFeatures: hasActiveLocalPremium && !auth.isSignedIn,
    hasServerVerifiedPremium: hasServerVerifiedPremium,
    userFacingStatus: _userFacingStatusFor(
      localAccess: localAccess,
      serverStatus: serverStatus,
      purchase: purchase,
      account: account,
    ),
  );
});

LocalPremiumAccess _localAccessFor({
  required SubscriptionLifecycle lifecycle,
  required PurchaseRepository purchase,
  required bool hasAnyStoredPremiumState,
}) {
  switch (lifecycle.phase) {
    case SubscriptionLifecyclePhase.activePremium:
      return LocalPremiumAccess.active;
    case SubscriptionLifecyclePhase.expiredGrace:
      return LocalPremiumAccess.historyGrace;
    case SubscriptionLifecyclePhase.expired:
      return LocalPremiumAccess.expired;
    case SubscriptionLifecyclePhase.free:
      final unavailableReason = purchase.unavailableReason?.toLowerCase() ?? '';
      if (!hasAnyStoredPremiumState && unavailableReason.contains('loading')) {
        return LocalPremiumAccess.loading;
      }
      if (!hasAnyStoredPremiumState &&
          !purchase.isPurchaseAvailable &&
          unavailableReason.isNotEmpty) {
        return LocalPremiumAccess.unavailable;
      }
      return LocalPremiumAccess.free;
  }
}

ServerFeatureStatus _serverStatusFor({
  required AuthSessionSummary auth,
  required bool hasActiveLocalPremium,
  required bool hasServerVerifiedPremium,
  required CloudBackupConsentState? consent,
  required SubscriptionAccountState account,
}) {
  if (!hasActiveLocalPremium || !auth.isSignedIn) {
    return ServerFeatureStatus.signedOut;
  }
  if (!hasServerVerifiedPremium) {
    return ServerFeatureStatus.verifying;
  }
  if (_looksAccountSwitchBlocked(account.lastSyncError)) {
    return ServerFeatureStatus.error;
  }
  if (consent?.canEnableCloudUpload != true) {
    return ServerFeatureStatus.needsBackupConsent;
  }
  return ServerFeatureStatus.ready;
}

bool _hasAnyStoredPremiumState(SubscriptionAccountState account) {
  return account.entitlementTier != UserTier.personalFree ||
      account.entitlementStatus == EntitlementStatus.expired ||
      account.entitlementPeriodEndsAt != null;
}

String? _userFacingStatusFor({
  required LocalPremiumAccess localAccess,
  required ServerFeatureStatus serverStatus,
  required PurchaseRepository purchase,
  required SubscriptionAccountState account,
}) {
  switch (localAccess) {
    case LocalPremiumAccess.loading:
    case LocalPremiumAccess.unavailable:
      return purchase.unavailableReason;
    case LocalPremiumAccess.historyGrace:
      return 'Premium recently ended. Your extended history stays visible for now.';
    case LocalPremiumAccess.expired:
      return 'Premium has ended. Pebble is using Free limits again.';
    case LocalPremiumAccess.active:
      if (serverStatus == ServerFeatureStatus.verifying) {
        return 'Premium is on for this device. Server features are finishing setup.';
      }
      if (serverStatus == ServerFeatureStatus.signedOut) {
        return 'Premium is on for this device. Sign in for backup, email alerts, and recovery.';
      }
      if (serverStatus == ServerFeatureStatus.error) {
        return account.lastSyncError ?? 'Backup needs your attention.';
      }
      return null;
    case LocalPremiumAccess.free:
      return null;
  }
}

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
