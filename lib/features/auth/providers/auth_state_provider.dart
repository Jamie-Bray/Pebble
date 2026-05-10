import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/auth/data/auth_repository.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';

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

  Future<void> requestEmailOtp(String email) async {
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
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.authError,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _completeSignIn(
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
    await _repository.signOut();
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
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .resetAfterAccountDeletion();
      state = const AuthState.initial();
    } catch (error) {
      state = state.copyWith(
        status: hadActiveUser ? AuthStatus.signedIn : AuthStatus.signedOut,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> _completeSignIn(
    Future<AuthIdentity> Function() signInAction,
  ) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    try {
      final identity = await signInAction();
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
      await _refreshStoreEntitlement();
      await _ensureCloudReady(identity.userId);
      state = state.copyWith(status: AuthStatus.signedIn, clearError: true);
    } catch (error) {
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .noteSyncFailure(
            'Backup setup is not ready yet. Your routines are still available on this device.',
          );
      state = state.copyWith(
        status: AuthStatus.authError,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refreshCloudAccessAfterEntitlementChange() async {
    if (state.activeUserId == null || state.activeUserId!.isEmpty) {
      state = state.copyWith(status: AuthStatus.signedOut, clearError: true);
      return;
    }
    await _ensureCloudReady(state.activeUserId!);
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
      final refreshedAccount = _ref.read(subscriptionAccountControllerProvider);
      final needsBootstrap =
          refreshedAccount.bootstrapStatus != BootstrapStatus.ready ||
          refreshedAccount.lastBootstrapAt == null;
      try {
        if (needsBootstrap) {
          await _ensureCloudReady(identity.userId);
        } else {
          unawaited(_ref.read(cloudSyncCoordinatorProvider).kick());
        }
      } catch (error) {
        await _ref
            .read(subscriptionAccountControllerProvider.notifier)
            .noteSyncFailure(
              'Backup setup is not ready yet. Your routines are still available on this device.',
            );
        state = state.copyWith(
          status: AuthStatus.authError,
          errorMessage: error.toString(),
        );
      }
    }
  }

  bool _hasPaidPersonalEntitlement(SubscriptionAccountState accountState) {
    return accountState.entitlementTier == UserTier.personalPremium ||
        accountState.entitlementTier == UserTier.pebbleHousehold;
  }

  Future<void> _ensureCloudReady(String userId) async {
    final account = _ref.read(subscriptionAccountControllerProvider);
    if (!_hasPaidPersonalEntitlement(account)) {
      return;
    }
    if (!_ref.read(cloudBackupConsentControllerProvider).isAccepted) {
      await _ref
          .read(subscriptionAccountControllerProvider.notifier)
          .updateBootstrapStatus(BootstrapStatus.idle, clearError: true);
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
      await _ref.read(purchaseRepositoryProvider).restorePurchases();
    } catch (_) {
      // No active Play purchase, or Play is unreachable. The entitlement layer
      // keeps the last verified local state and exposes the check error.
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
