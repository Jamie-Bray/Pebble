import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/data/auth_repository.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/local_data_ownership_guard.dart';

enum AuthStatus {
  signedOut,
  pendingSignIn,
  authenticating,
  signedIn,
  authError,
}

class AuthState {
  final AuthStatus status;
  final String? activeUserId;
  final String? activeEmail;
  final String? activeProvider;
  final String? emailDraft;
  final String? errorMessage;

  const AuthState({
    required this.status,
    required this.activeUserId,
    required this.activeEmail,
    required this.activeProvider,
    required this.emailDraft,
    required this.errorMessage,
  });

  const AuthState.initial()
    : status = AuthStatus.signedOut,
      activeUserId = null,
      activeEmail = null,
      activeProvider = null,
      emailDraft = null,
      errorMessage = null;

  AuthState copyWith({
    AuthStatus? status,
    String? activeUserId,
    bool clearActiveUserId = false,
    String? activeEmail,
    bool clearActiveEmail = false,
    String? activeProvider,
    bool clearActiveProvider = false,
    String? emailDraft,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      activeUserId: clearActiveUserId
          ? null
          : activeUserId ?? this.activeUserId,
      activeEmail: clearActiveEmail ? null : activeEmail ?? this.activeEmail,
      activeProvider: clearActiveProvider
          ? null
          : activeProvider ?? this.activeProvider,
      emailDraft: emailDraft ?? this.emailDraft,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthSessionSummary {
  const AuthSessionSummary({
    required this.isSignedIn,
    required this.userId,
    required this.email,
    required this.provider,
  });

  final bool isSignedIn;
  final String? userId;
  final String? email;
  final String? provider;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, this._repository)
    : super(const AuthState.initial()) {
    Future.microtask(_hydrateAuthSession);
  }

  final Ref _ref;
  final AuthRepository _repository;

  bool get isConfigured => _repository.isConfigured;

  Future<void> beginPremiumUpgrade() async {
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .beginPremiumUpgradeIntent();
    state = state.copyWith(
      status: state.status == AuthStatus.signedIn
          ? AuthStatus.signedIn
          : AuthStatus.pendingSignIn,
      clearError: true,
    );
  }

  Future<void> cancelPremiumUpgrade() async {
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .cancelPendingUpgrade();
    state = state.copyWith(
      status: state.activeUserId != null
          ? AuthStatus.signedIn
          : AuthStatus.signedOut,
      clearError: true,
    );
  }

  Future<bool> requestEmailOtp(String email) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      emailDraft: email,
      clearError: true,
    );
    try {
      await _repository.requestEmailOtp(email);
      state = state.copyWith(
        status: AuthStatus.pendingSignIn,
        emailDraft: email,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.authError,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<bool> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    return _completeSignIn(
      () => _repository.verifyEmailOtp(email: email, token: token),
    );
  }

  Future<void> signInWithGoogle() async {
    await _completeSignIn(_repository.signInWithGoogle);
  }

  Future<void> signInWithApple() async {
    await _completeSignIn(_repository.signInWithApple);
  }

  Future<void> signOut() async {
    debugPrint('[PremiumEntitlement] Sign-out requested.');
    await _repository.signOut();
    await _logOutPurchaseSession('sign-out');
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .signOutIdentity();
    state = state.copyWith(
      status: AuthStatus.signedOut,
      clearActiveUserId: true,
      clearActiveEmail: true,
      clearActiveProvider: true,
      clearError: true,
    );
  }

  Future<void> deleteAccount() async {
    final hadActiveUser =
        state.activeUserId != null && state.activeUserId!.isNotEmpty;
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    try {
      await _repository.deleteAccount();
      await _logOutPurchaseSession('account deletion');
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .resetAfterAccountDeletion(preserveStoreEntitlement: true);
      state = const AuthState.initial();
      try {
        await _ref.read(purchaseRepositoryProvider).syncPurchasesSilently();
      } catch (_) {
        // Account deletion succeeded. Purchase refresh can be retried from
        // account restore without bringing back the deleted identity.
      }
    } catch (error) {
      state = state.copyWith(
        status: hadActiveUser ? AuthStatus.signedIn : AuthStatus.signedOut,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> _logOutPurchaseSession(String context) async {
    try {
      await _ref.read(purchaseRepositoryProvider).logOut();
    } catch (error) {
      debugPrint('Failed to clear RevenueCat session after $context: $error');
    }
  }

  Future<bool> _completeSignIn(
    Future<AuthIdentity> Function() signInAction,
  ) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    final AuthIdentity identity;
    try {
      identity = await signInAction();
      await _repository.upsertProfile(identity: identity);
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .cacheAuthenticatedIdentity(
            userId: identity.userId,
            email: identity.email,
            authProvider: identity.provider,
          );
      state = state.copyWith(
        status: AuthStatus.authenticating,
        activeUserId: identity.userId,
        activeEmail: identity.email,
        activeProvider: identity.provider,
        clearError: true,
      );
    } catch (error) {
      // Only a real authentication failure may fail the sign-in. Backup work
      // below is best-effort and must never bounce a signed-in user back to
      // an error screen.
      state = state.copyWith(
        status: AuthStatus.authError,
        errorMessage: error.toString(),
      );
      return false;
    }

    try {
      await _refreshStoreEntitlement();
      debugPrint(
        '[PremiumEntitlement] Entitlement refreshed after account sign-in.',
      );
      final confirmedConsent = await _grantBackupConsentIfPremium(
        identity.userId,
      );
      await _ensureCloudReady(
        identity.userId,
        remotelyConfirmedConsent: confirmedConsent,
        consentCheckCompleted: confirmedConsent != null,
      );
    } catch (error) {
      debugPrint('Backup setup after sign-in failed: $error');
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(
            'Backup setup is not ready yet. Your routines are still available on this device.',
          );
    }
    state = state.copyWith(status: AuthStatus.signedIn, clearError: true);
    return true;
  }

  /// The sign-in screen tells Premium users that signing in turns on backup,
  /// so record that choice here — the moment they act on it. This runs before
  /// [_ensureCloudReady] so the bootstrap can start in the same flow instead
  /// of stranding the account in a "waiting to turn on" state.
  ///
  /// Uses the auth-free [CloudBackupConsentStore]: the auth-scoped consent
  /// controller cannot be read from here without a provider cycle, and it
  /// still reports signed-out while this flow is in progress anyway.
  Future<CloudBackupConsentRecord?> _grantBackupConsentIfPremium(
    String userId,
  ) async {
    if (!_hasPaidPersonalEntitlement(
      _ref.read(subscriptionAccountControllerProvider),
    )) {
      return null;
    }
    final store = _ref.read(cloudBackupConsentStoreProvider);
    await store.markEnablePending(userId);
    final record = await _completePendingBackupConsent(userId);
    if (record != null) {
      debugPrint('[PremiumEntitlement] Backup consent recorded at sign-in.');
    }
    return record;
  }

  Future<CloudBackupConsentRecord?> _completePendingBackupConsent(
    String userId,
  ) async {
    final store = _ref.read(cloudBackupConsentStoreProvider);
    if (!store.isEnablePending(userId)) {
      return null;
    }
    var record = await store.fetchRecord(userId);
    if (record?.isCurrentAccepted != true) {
      record = await store.acceptFor(userId);
    }
    await store.clearEnablePending(userId);
    return record;
  }

  Future<void> refreshCloudAccessAfterEntitlementChange({
    bool refreshEntitlement = true,
  }) async {
    if (state.activeUserId == null || state.activeUserId!.isEmpty) {
      state = state.copyWith(status: AuthStatus.signedOut, clearError: true);
      return;
    }
    final userId = state.activeUserId!;
    if (refreshEntitlement) {
      await _refreshStoreEntitlement();
    }
    await _completePendingBackupConsent(userId);
    final consentController = _ref.read(
      cloudBackupConsentControllerProvider.notifier,
    );
    await consentController.load();
    final consent = _ref.read(cloudBackupConsentControllerProvider);
    if (consent.lastError != null) {
      throw StateError(consent.lastError!);
    }
    await _ensureCloudReady(
      userId,
      remotelyConfirmedConsent: consent.canEnableCloudUpload
          ? consent.record
          : null,
      consentCheckCompleted: true,
    );
    state = state.copyWith(status: AuthStatus.signedIn, clearError: true);
  }

  Future<void> _hydrateAuthSession() async {
    final identity = await _repository.currentIdentity();
    final accountState = _ref.read(subscriptionAccountControllerProvider);
    if (identity == null) {
      _syncWithStoredState(accountState);
      return;
    }

    await _repository.upsertProfile(identity: identity);
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .cacheAuthenticatedIdentity(
          userId: identity.userId,
          email: identity.email,
          authProvider: identity.provider,
        );
    state = state.copyWith(
      status: AuthStatus.signedIn,
      activeUserId: identity.userId,
      activeEmail: identity.email,
      activeProvider: identity.provider,
      clearError: true,
    );
    if (_hasPaidPersonalEntitlement(
      _ref.read(subscriptionAccountControllerProvider),
    )) {
      try {
        await _completePendingBackupConsent(identity.userId);
        final consentController = _ref.read(
          cloudBackupConsentControllerProvider.notifier,
        );
        await consentController.load();
        final consent = _ref.read(cloudBackupConsentControllerProvider);
        if (consent.lastError != null) {
          throw StateError(consent.lastError!);
        }
        await _ensureCloudReady(
          identity.userId,
          remotelyConfirmedConsent: consent.canEnableCloudUpload
              ? consent.record
              : null,
          consentCheckCompleted: true,
        );
      } catch (error) {
        debugPrint('Backup setup after session restore failed: $error');
        await _ref
            .read(subscriptionAccountControllerProvider.notifier)
            .noteSyncFailure(
              'Backup setup is not ready yet. Your routines are still available on this device.',
            );
        // The stored auth session is valid. A cloud problem must not turn it
        // into a misleading "Could not sign in" state on app launch.
        state = state.copyWith(status: AuthStatus.signedIn, clearError: true);
      }
    }
  }

  bool _hasPaidPersonalEntitlement(SubscriptionAccountState accountState) {
    return accountState.entitlementTier == UserTier.personalPremium ||
        accountState.entitlementTier == UserTier.pebbleHousehold;
  }

  Future<void> _ensureCloudReady(
    String userId, {
    CloudBackupConsentRecord? remotelyConfirmedConsent,
    bool consentCheckCompleted = false,
  }) async {
    var account = _ref.read(subscriptionAccountControllerProvider);
    if (!_hasPaidPersonalEntitlement(account)) {
      return;
    }
    if (account.entitlementSource != EntitlementSource.serverVerified) {
      final refreshed = await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .refreshServerVerifiedEntitlement();
      if (refreshed) {
        account = _ref.read(subscriptionAccountControllerProvider);
      }
    }
    if (account.entitlementSource != EntitlementSource.serverVerified) {
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .updateBootstrapStatus(BootstrapStatus.idle, clearError: true);
      return;
    }
    // During sign-in the auth-scoped consent controller still reports signed
    // out, so the caller can pass the record it just confirmed remotely. All
    // other callers perform a fresh server read before bootstrap; stale local
    // consent is never enough to start cloud work.
    final consentRecord = consentCheckCompleted
        ? remotelyConfirmedConsent
        : await _ref.read(cloudBackupConsentStoreProvider).fetchRecord(userId);
    if (consentRecord?.isCurrentAccepted != true) {
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .updateBootstrapStatus(BootstrapStatus.idle, clearError: true);
      return;
    }

    var ownership = await LocalDataOwnershipGuard.inspect(
      database: _ref.read(localDbProvider),
      signedInUserId: userId,
    );
    if (ownership.state == LocalDataOwnershipState.unownedOnly) {
      // Never-owned rows belong to no other account, and sign-in, verified
      // Premium, and current consent are all confirmed above, so the consent
      // choice covers linking. Only different-owner data needs manual review.
      ownership = await LocalDataOwnershipGuard.linkUnownedLocalData(
        database: _ref.read(localDbProvider),
        signedInUserId: userId,
      );
    }
    if (ownership.blocksCloudSync) {
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(ownership.userFacingMessage);
      return;
    }

    account = _ref.read(subscriptionAccountControllerProvider);
    if (account.bootstrapStatus == BootstrapStatus.ready &&
        account.userId == userId) {
      unawaited(_ref.read(cloudSyncCoordinatorProvider).kick());
      return;
    }

    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .updateBootstrapStatus(BootstrapStatus.preparing, clearError: true);
    await _ref.read(cloudRestoreCoordinatorProvider).bootstrapAndMerge(userId);
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .updateBootstrapStatus(BootstrapStatus.ready, clearError: true);
    unawaited(_ref.read(cloudSyncCoordinatorProvider).kick());
  }

  Future<void> _refreshStoreEntitlement() async {
    try {
      debugPrint('[PremiumEntitlement] Refreshing store entitlement.');
      await _ref
          .read(purchaseRepositoryProvider)
          .syncPurchasesSilently(waitForServerMirror: true);
    } catch (error) {
      // No active store purchase, or RevenueCat is unreachable. The entitlement
      // layer keeps the last verified local state and exposes the check error.
      debugPrint(
        '[PremiumEntitlement] Store entitlement refresh failed: $error',
      );
    }
  }

  void _syncWithStoredState(SubscriptionAccountState accountState) {
    if (accountState.isPremiumPendingAuth) {
      state = state.copyWith(status: AuthStatus.pendingSignIn);
      return;
    }
    if (state.status == AuthStatus.authenticating) {
      return;
    }
    state = state.copyWith(status: AuthStatus.signedOut);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repository = ref.watch(authRepositoryProvider);
    return AuthController(ref, repository);
  },
);

final authSessionProvider = Provider<AuthSessionSummary>((ref) {
  final authState = ref.watch(authControllerProvider);
  return AuthSessionSummary(
    isSignedIn: authState.status == AuthStatus.signedIn,
    userId: authState.activeUserId,
    email: authState.activeEmail,
    provider: authState.activeProvider,
  );
});
