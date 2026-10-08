import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/core/config/app_runtime_config.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';

final subscriptionAccountControllerProvider =
    StateNotifierProvider<
      SubscriptionAccountController,
      SubscriptionAccountState
    >((ref) {
      final db = ref.read(localDbProvider);
      SharedPreferences? prefs;
      try {
        prefs = ref.read(sharedPreferencesProvider);
      } catch (_) {
        prefs = null;
      }
      final runtimeConfig = ref.read(appRuntimeConfigProvider);
      final supabaseClient = ref.watch(supabaseClientProvider);
      return SubscriptionAccountController(
        db,
        prefs: prefs,
        isProduction: runtimeConfig.isProduction,
        supabaseClient: supabaseClient,
      );
    });

final subscriptionProvider = Provider<UserTier>((ref) {
  return ref.watch(subscriptionAccountControllerProvider).entitlementTier;
});

final subscriptionLifecycleProvider = Provider<SubscriptionLifecycle>((ref) {
  return subscriptionLifecycleForAccount(
    ref.watch(subscriptionAccountControllerProvider),
  );
});

/// How much history this account can see: 48 hours on Free, 21 days with
/// Premium (and during the grace period after it ends). The phone keeps
/// [ProofMediaFairUsePolicy.storedHistoryRetention] either way.
final accountHistoryRetentionProvider = Provider<Duration>((ref) {
  final lifecycle = ref.watch(subscriptionLifecycleProvider);

  if (lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace) {
    return lifecycle.localHistoryRetention;
  }
  if (lifecycle.phase == SubscriptionLifecyclePhase.activePremium) {
    return lifecycle.localHistoryRetention;
  }
  return ProofMediaFairUsePolicy.localRetentionDuration;
});

final accountHasPremiumHistoryRetentionProvider = Provider<bool>((ref) {
  return ref.watch(accountHistoryRetentionProvider) !=
      ProofMediaFairUsePolicy.localRetentionDuration;
});

class SubscriptionAccountController
    extends StateNotifier<SubscriptionAccountState> {
  SubscriptionAccountController(
    this._db, {
    this.prefs,
    this.isProduction = false,
    this.supabaseClient,
    bool loadOnInit = true,
  }) : super(const SubscriptionAccountState.initial()) {
    if (loadOnInit) {
      unawaited(_load().whenComplete(_markLoaded));
    } else {
      _markLoaded();
    }
  }

  final Completer<void> _loaded = Completer<void>();

  /// Completes once the stored entitlement has been read. Until then the
  /// state is the Free default, so anything destructive that depends on the
  /// plan (history retention) must wait for this first.
  Future<void> get whenLoaded => _loaded.future;

  void _markLoaded() {
    if (!_loaded.isCompleted) _loaded.complete();
  }

  final LocalDb _db;
  final SharedPreferences? prefs;
  final bool isProduction;
  final SupabaseClient? supabaseClient;

  static const _sourceKey = 'pebble.entitlement.source';
  static const _statusKey = 'pebble.entitlement.status';
  static const _lastCheckedAtKey = 'pebble.entitlement.last_checked_at';
  static const _periodEndsAtKey = 'pebble.entitlement.period_ends_at';
  static const _expiredAtKey = 'pebble.entitlement.expired_at';
  static const _lapseNoticedAtKey = 'pebble.entitlement.lapse_noticed_at';
  static const _willRenewKey = 'pebble.entitlement.will_renew';
  static const _billingIssueAtKey = 'pebble.entitlement.billing_issue_at';
  static const _lastErrorKey = 'pebble.entitlement.last_error';

  Future<void> _load() async {
    final row = await _db.cloudAccountDao.getState();
    if (row == null) {
      await _persist(const SubscriptionAccountState.initial());
      return;
    }

    final persisted = _expireIfPeriodEnded(
      _withEntitlementMetadata(_mapRow(row)),
    );
    final verifiedSource =
        persisted.entitlementSource == EntitlementSource.googlePlay ||
        persisted.entitlementSource == EntitlementSource.revenueCat ||
        persisted.entitlementSource == EntitlementSource.serverVerified;
    if (isProduction &&
        persisted.entitlementTier != UserTier.personalFree &&
        !verifiedSource) {
      final sanitized = SubscriptionAccountState(
        entitlementTier: UserTier.personalFree,
        pendingTier: null,
        bootstrapStatus: BootstrapStatus.idle,
        userId: persisted.userId,
        email: persisted.email,
        authProvider: persisted.authProvider,
        lastBootstrapAt: null,
        lastSyncAt: null,
        lastSyncError: null,
        entitlementStatus: EntitlementStatus.unknown,
        entitlementSource: EntitlementSource.unknown,
        entitlementError:
            'Stored entitlement was ignored because it was not store verified.',
      );
      state = sanitized;
      await _persist(sanitized);
      await _persistEntitlementMetadata(sanitized);
      return;
    }

    state = persisted;
  }

  Future<void> applyRevenueCatEntitlement(
    UserTier newTier, {
    DateTime? periodEndsAt,
    bool? willRenew,
    DateTime? billingIssueAt,
  }) async {
    debugPrint(
      '[PremiumEntitlement] Storing RevenueCat entitlement: '
      'tier=${newTier.name}, periodEndsAt=$periodEndsAt',
    );
    final next = state.copyWith(
      entitlementTier: newTier,
      clearPendingTier: true,
      entitlementStatus: _statusForTier(newTier),
      entitlementSource: EntitlementSource.revenueCat,
      lastEntitlementCheckAt: DateTime.now(),
      entitlementPeriodEndsAt: periodEndsAt,
      clearEntitlementPeriodEndsAt: periodEndsAt == null,
      clearEntitlementExpiredAt: true,
      clearEntitlementLapseNoticedAt: true,
      entitlementWillRenew: willRenew,
      clearEntitlementWillRenew: willRenew == null,
      entitlementBillingIssueAt: billingIssueAt,
      clearEntitlementBillingIssueAt: billingIssueAt == null,
      clearEntitlementError: true,
      bootstrapStatus: newTier == UserTier.personalFree
          ? BootstrapStatus.idle
          : state.bootstrapStatus,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
    await _persistEntitlementMetadata(next);
  }

  Future<void> applyServerVerifiedEntitlement(
    UserTier newTier, {
    DateTime? periodEndsAt,
  }) async {
    debugPrint(
      '[PremiumEntitlement] Storing server-verified entitlement: '
      'tier=${newTier.name}, periodEndsAt=$periodEndsAt',
    );
    final next = state.copyWith(
      entitlementTier: newTier,
      clearPendingTier: true,
      entitlementStatus: _statusForTier(newTier),
      entitlementSource: EntitlementSource.serverVerified,
      lastEntitlementCheckAt: DateTime.now(),
      entitlementPeriodEndsAt: periodEndsAt,
      clearEntitlementPeriodEndsAt: periodEndsAt == null,
      clearEntitlementExpiredAt: true,
      clearEntitlementLapseNoticedAt: true,
      clearEntitlementError: true,
      bootstrapStatus: newTier == UserTier.personalFree
          ? BootstrapStatus.idle
          : state.bootstrapStatus,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
    await _persistEntitlementMetadata(next);
  }

  Future<void> applyExpiredStoreEntitlement() async {
    debugPrint(
      '[PremiumEntitlement] Store entitlement marked expired locally.',
    );
    final next = state.copyWith(
      entitlementTier: UserTier.personalFree,
      clearPendingTier: true,
      entitlementStatus: EntitlementStatus.expired,
      entitlementSource: _expiredEntitlementSource(state.entitlementSource),
      lastEntitlementCheckAt: DateTime.now(),
      entitlementExpiredAt:
          state.entitlementExpiredAt ??
          state.entitlementPeriodEndsAt ??
          DateTime.now(),
      // The store has just said Premium is not active: the lapse is real.
      entitlementLapseNoticedAt:
          state.entitlementLapseNoticedAt ?? DateTime.now(),
      clearEntitlementWillRenew: true,
      clearEntitlementBillingIssueAt: true,
      clearEntitlementPeriodEndsAt: true,
      clearEntitlementError: true,
      bootstrapStatus: BootstrapStatus.idle,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
    await _persistEntitlementMetadata(next);
  }

  /// Records that the store confirmed a lapse that was so far only inferred
  /// from a cached period end. Starts the grace countdown; a no-op when the
  /// plan is not expired or the lapse was already confirmed.
  Future<void> confirmLapseIfExpired() async {
    if (state.entitlementStatus != EntitlementStatus.expired ||
        state.entitlementLapseNoticedAt != null) {
      return;
    }
    debugPrint('[PremiumEntitlement] Store confirmed the Premium lapse.');
    final next = state.copyWith(entitlementLapseNoticedAt: DateTime.now());
    state = next;
    await _persistEntitlementMetadata(next);
  }

  Future<bool> refreshServerVerifiedEntitlement({
    bool requestServerReconciliation = false,
  }) async {
    final client = supabaseClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return false;
    }

    debugPrint(
      '[PremiumEntitlement] Server verification refresh started '
      'for user=${user.id}.',
    );
    if (requestServerReconciliation) {
      await _requestRevenueCatServerReconciliation(client, user.id);
    }
    return _readServerVerifiedEntitlement(client, user.id);
  }

  Future<bool> _readServerVerifiedEntitlement(
    SupabaseClient client,
    String userId,
  ) async {
    final rows = await client
        .from('personal_entitlements')
        .select(
          'entitlement_tier,status,period_ends_at,last_verified_at,updated_at',
        )
        .eq('owner_user_id', userId)
        .order('last_verified_at', ascending: false)
        .limit(10);
    if (rows.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    Map<dynamic, dynamic>? expiredRow;
    for (final row in rows.whereType<Map>()) {
      final tier = _tierFromString(row['entitlement_tier']?.toString() ?? '');
      final status = row['status']?.toString();
      final periodEndsAt = _dateFromRow(row['period_ends_at']);
      final hasActiveStatus =
          status == 'active' ||
          status == 'grace' ||
          status == 'cancelled_active';
      final stillCurrent = periodEndsAt == null || periodEndsAt.isAfter(now);
      if (tier != UserTier.personalFree && hasActiveStatus && stillCurrent) {
        await applyServerVerifiedEntitlement(tier, periodEndsAt: periodEndsAt);
        debugPrint(
          '[PremiumEntitlement] Server verification succeeded '
          'for user=$userId.',
        );
        return true;
      }
      if (status == 'expired' && expiredRow == null) {
        expiredRow = row;
      }
    }

    if (expiredRow != null) {
      final checkedAt = _dateFromRow(expiredRow['last_verified_at']) ?? now;
      if (!shouldApplyServerExpiredEntitlement(state, checkedAt: checkedAt)) {
        debugPrint(
          '[PremiumEntitlement] Ignoring expired server entitlement '
          'because local store entitlement is newer or still active.',
        );
        return false;
      }
      final next = state.copyWith(
        entitlementTier: UserTier.personalFree,
        clearPendingTier: true,
        entitlementStatus: EntitlementStatus.expired,
        entitlementSource: EntitlementSource.serverVerified,
        lastEntitlementCheckAt: checkedAt,
        entitlementExpiredAt:
            state.entitlementExpiredAt ??
            state.entitlementPeriodEndsAt ??
            checkedAt,
        entitlementLapseNoticedAt: state.entitlementLapseNoticedAt ?? now,
        clearEntitlementWillRenew: true,
        clearEntitlementBillingIssueAt: true,
        clearEntitlementPeriodEndsAt: true,
        clearEntitlementError: true,
        bootstrapStatus: BootstrapStatus.idle,
        clearLastSyncError: true,
      );
      state = next;
      await _persist(next);
      await _persistEntitlementMetadata(next);
      debugPrint(
        '[PremiumEntitlement] Server verification returned expired '
        'entitlement for user=$userId.',
      );
      return true;
    }

    debugPrint(
      '[PremiumEntitlement] Server verification found no entitlement rows '
      'for user=$userId.',
    );
    return false;
  }

  Future<void> _requestRevenueCatServerReconciliation(
    SupabaseClient client,
    String userId,
  ) async {
    final accessToken = client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError(
        'Missing Supabase access token for purchase verification.',
      );
    }
    debugPrint(
      '[PremiumEntitlement] Requesting RevenueCat server reconciliation '
      'for user=$userId.',
    );
    try {
      final response = await client.functions.invoke(
        'revenuecat-sync-entitlement',
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      debugPrint(
        '[PremiumEntitlement] RevenueCat server reconciliation completed: '
        'status=${response.status}, data=${response.data}.',
      );
      debugPrint(
        '[PremiumEntitlementDebug] server_reconciliation_called=true '
        'server_reconciliation_status=${response.status} '
        'supabase_auth_uid=$userId',
      );
    } catch (error) {
      final status = _functionErrorStatus(error);
      final details = _functionErrorDetails(error);
      debugPrint(
        '[PremiumEntitlement] RevenueCat server reconciliation failed: '
        'status=${status ?? 'unknown'}, details=${details ?? 'none'}, '
        'error=$error',
      );
      debugPrint(
        '[PremiumEntitlementDebug] server_reconciliation_called=true '
        'server_reconciliation_status=${status ?? 'failed'} '
        'supabase_auth_uid=$userId',
      );
      rethrow;
    }
  }

  String? _functionErrorStatus(Object error) {
    final match = RegExp(
      r'FunctionException\(status: ([0-9]+)',
    ).firstMatch(error.toString());
    return match?.group(1);
  }

  Object? _functionErrorDetails(Object error) {
    if (error is FunctionException) {
      return error.details;
    }
    return null;
  }

  Future<void> recordEntitlementCheckError(String message) async {
    debugPrint('[PremiumEntitlement] Entitlement check error: $message');
    final next = state.copyWith(
      entitlementStatus: state.entitlementTier == UserTier.personalFree
          ? EntitlementStatus.unknown
          : state.entitlementStatus,
      lastEntitlementCheckAt: DateTime.now(),
      entitlementError: message,
    );
    state = next;
    await _persistEntitlementMetadata(next);
  }

  Future<void> beginPremiumUpgradeIntent() async {
    final next = state.copyWith(
      pendingTier: UserTier.personalPremium,
      bootstrapStatus: BootstrapStatus.idle,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
  }

  Future<void> cancelPendingUpgrade() async {
    final next = state.copyWith(clearPendingTier: true);
    state = next;
    await _persist(next);
  }

  Future<void> cacheAuthenticatedIdentity({
    required String userId,
    required String? email,
    required String authProvider,
  }) async {
    final previousUserId = state.userId;
    if (previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != userId) {
      debugPrint(
        '[PremiumEntitlement] Different account signed in: '
        'previous=$previousUserId, next=$userId.',
      );
    }
    final next = state.copyWith(
      clearPendingTier: true,
      userId: userId,
      email: email,
      authProvider: authProvider,
      bootstrapStatus: previousUserId != null && previousUserId != userId
          ? BootstrapStatus.idle
          : null,
      // Sign-out clears the user id but keeps the "last backed up" times for
      // the paused view, so a sign-in after sign-out is treated as a possible
      // new account too.
      clearLastBootstrapAt: previousUserId != userId,
      clearLastSyncAt: previousUserId != userId,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
  }

  Future<void> updateBootstrapStatus(
    BootstrapStatus status, {
    String? error,
    bool clearError = false,
  }) async {
    final now = DateTime.now();
    // A bootstrap only reads the server, so it never counts as "backed up":
    // [lastSyncAt] moves only when a backup pass finishes cleanly.
    final next = state.copyWith(
      bootstrapStatus: status,
      lastBootstrapAt: status == BootstrapStatus.ready ? now : null,
      lastSyncError: clearError ? null : error,
      clearLastSyncError: clearError,
    );
    state = next;
    await _persist(next);
  }

  /// A backup pass finished with nothing failing and nothing left waiting:
  /// everything on this phone is in the backup as of now. Call once per
  /// pass, never per item.
  ///
  /// [reachedServer] is false when the pass had nothing to upload. A setup
  /// (bootstrap) error is then left in place, because the pass did not prove
  /// the server is reachable.
  Future<void> noteBackupPassClean({required bool reachedServer}) async {
    final now = DateTime.now();
    final setupError = state.bootstrapStatus == BootstrapStatus.error;
    if (setupError && !reachedServer) {
      final next = state.copyWith(lastSyncAt: now);
      state = next;
      await _persist(next);
      return;
    }
    final next = state.copyWith(
      lastSyncAt: now,
      bootstrapStatus: state.bootstrapStatus == BootstrapStatus.preparing
          ? BootstrapStatus.syncing
          : setupError
          ? BootstrapStatus.ready
          : state.bootstrapStatus,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
  }

  /// A backup pass ended with changes that failed to upload. The message is
  /// kept until a later pass finishes cleanly. Unlike [noteSyncFailure] this
  /// leaves the setup (bootstrap) state alone: a change that fails to upload
  /// does not mean backup needs setting up again.
  Future<void> noteBackupPassFailed(String error) async {
    final next = state.copyWith(lastSyncError: error);
    state = next;
    await _persist(next);
  }

  /// Backup setup failed (sign-in bootstrap, consent, or another account's
  /// data on this phone).
  Future<void> noteSyncFailure(String error) async {
    final next = state.copyWith(
      bootstrapStatus: BootstrapStatus.error,
      lastSyncError: error,
    );
    state = next;
    await _persist(next);
  }

  Future<void> signOutIdentity() async {
    debugPrint('[PremiumEntitlement] User signed out; preserving store state.');
    final next = state.copyWith(
      clearPendingTier: true,
      clearUserId: true,
      clearEmail: true,
      clearAuthProvider: true,
      clearLastSyncError: true,
      bootstrapStatus: BootstrapStatus.idle,
    );
    state = next;
    await _persist(next);
    await _persistEntitlementMetadata(next);
  }

  Future<void> resetAfterAccountDeletion({
    bool preserveStoreEntitlement = false,
  }) async {
    if (!preserveStoreEntitlement) {
      state = const SubscriptionAccountState.initial();
      await _persist(state);
      await _persistEntitlementMetadata(state);
      return;
    }

    state = state.copyWith(
      clearPendingTier: true,
      clearUserId: true,
      clearEmail: true,
      clearAuthProvider: true,
      clearLastSyncError: true,
      bootstrapStatus: BootstrapStatus.idle,
    );
    await _persist(state);
    await _persistEntitlementMetadata(state);
  }

  SubscriptionAccountState _mapRow(CloudAccountStateRow row) {
    return SubscriptionAccountState(
      entitlementTier: _tierFromString(row.entitlementTier),
      pendingTier: row.pendingTier == null
          ? null
          : _tierFromString(row.pendingTier!),
      bootstrapStatus: _bootstrapStatusFromString(row.bootstrapStatus),
      userId: row.userId,
      email: row.email,
      authProvider: row.authProvider,
      lastBootstrapAt: row.lastBootstrapAt,
      lastSyncAt: row.lastSyncAt,
      lastSyncError: row.lastSyncError,
    );
  }

  Future<void> _persist(SubscriptionAccountState next) {
    return _db.cloudAccountDao.upsertState(
      CloudAccountStateRow(
        singletonId: 1,
        entitlementTier: next.entitlementTier.name,
        pendingTier: next.pendingTier?.name,
        bootstrapStatus: next.bootstrapStatus.name,
        userId: next.userId,
        email: next.email,
        authProvider: next.authProvider,
        lastBootstrapAt: next.lastBootstrapAt,
        lastSyncAt: next.lastSyncAt,
        lastSyncError: next.lastSyncError,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  SubscriptionAccountState _withEntitlementMetadata(
    SubscriptionAccountState state,
  ) {
    final status = _entitlementStatusFromString(
      prefs?.getString(_statusKey),
      fallback: _statusForTier(state.entitlementTier),
    );
    final source = _entitlementSourceFromString(
      prefs?.getString(_sourceKey),
      fallback: state.entitlementTier == UserTier.personalFree
          ? EntitlementSource.localCache
          : EntitlementSource.unknown,
    );
    final checkedAtRaw = prefs?.getString(_lastCheckedAtKey);
    final periodEndsAtRaw = prefs?.getString(_periodEndsAtKey);
    final expiredAtRaw = prefs?.getString(_expiredAtKey);
    final lapseNoticedAtRaw = prefs?.getString(_lapseNoticedAtKey);
    final billingIssueAtRaw = prefs?.getString(_billingIssueAtKey);
    return state.copyWith(
      entitlementStatus: status,
      entitlementSource: source,
      lastEntitlementCheckAt: checkedAtRaw == null
          ? null
          : DateTime.tryParse(checkedAtRaw),
      entitlementPeriodEndsAt: periodEndsAtRaw == null
          ? null
          : DateTime.tryParse(periodEndsAtRaw),
      entitlementExpiredAt: expiredAtRaw == null
          ? null
          : DateTime.tryParse(expiredAtRaw),
      entitlementLapseNoticedAt: lapseNoticedAtRaw == null
          ? null
          : DateTime.tryParse(lapseNoticedAtRaw),
      entitlementWillRenew: prefs?.getBool(_willRenewKey),
      entitlementBillingIssueAt: billingIssueAtRaw == null
          ? null
          : DateTime.tryParse(billingIssueAtRaw),
      entitlementError: prefs?.getString(_lastErrorKey),
    );
  }

  SubscriptionAccountState _expireIfPeriodEnded(
    SubscriptionAccountState state,
  ) {
    final periodEndsAt = state.entitlementPeriodEndsAt;
    if (periodEndsAt == null || periodEndsAt.isAfter(DateTime.now())) {
      return state;
    }
    if (state.entitlementTier == UserTier.personalFree) {
      return state;
    }
    return state.copyWith(
      entitlementTier: UserTier.personalFree,
      clearPendingTier: true,
      bootstrapStatus: BootstrapStatus.idle,
      entitlementStatus: EntitlementStatus.expired,
      lastEntitlementCheckAt: DateTime.now(),
      entitlementExpiredAt: state.entitlementExpiredAt ?? periodEndsAt,
      // Inferred from the cached period end only: the lapse is not
      // confirmed until the store or server says so.
      clearEntitlementWillRenew: true,
      clearEntitlementBillingIssueAt: true,
      clearEntitlementPeriodEndsAt: true,
      clearLastSyncError: true,
    );
  }

  Future<void> _persistEntitlementMetadata(
    SubscriptionAccountState next,
  ) async {
    final prefs = this.prefs;
    if (prefs == null) return;
    await prefs.setString(_statusKey, next.entitlementStatus.name);
    await prefs.setString(_sourceKey, next.entitlementSource.name);
    final checkedAt = next.lastEntitlementCheckAt;
    if (checkedAt == null) {
      await prefs.remove(_lastCheckedAtKey);
    } else {
      await prefs.setString(_lastCheckedAtKey, checkedAt.toIso8601String());
    }
    final periodEndsAt = next.entitlementPeriodEndsAt;
    if (periodEndsAt == null) {
      await prefs.remove(_periodEndsAtKey);
    } else {
      await prefs.setString(_periodEndsAtKey, periodEndsAt.toIso8601String());
    }
    final expiredAt = next.entitlementExpiredAt;
    if (expiredAt == null) {
      await prefs.remove(_expiredAtKey);
    } else {
      await prefs.setString(_expiredAtKey, expiredAt.toIso8601String());
    }
    await _setOrRemoveDate(
      prefs,
      _lapseNoticedAtKey,
      next.entitlementLapseNoticedAt,
    );
    await _setOrRemoveDate(
      prefs,
      _billingIssueAtKey,
      next.entitlementBillingIssueAt,
    );
    final willRenew = next.entitlementWillRenew;
    if (willRenew == null) {
      await prefs.remove(_willRenewKey);
    } else {
      await prefs.setBool(_willRenewKey, willRenew);
    }
    final error = next.entitlementError;
    if (error == null || error.isEmpty) {
      await prefs.remove(_lastErrorKey);
    } else {
      await prefs.setString(_lastErrorKey, error);
    }
  }
}

Future<void> _setOrRemoveDate(
  SharedPreferences prefs,
  String key,
  DateTime? value,
) async {
  if (value == null) {
    await prefs.remove(key);
  } else {
    await prefs.setString(key, value.toIso8601String());
  }
}

EntitlementSource _expiredEntitlementSource(EntitlementSource current) {
  return switch (current) {
    EntitlementSource.googlePlay ||
    EntitlementSource.revenueCat ||
    EntitlementSource.serverVerified => current,
    EntitlementSource.localCache ||
    EntitlementSource.unknown => EntitlementSource.unknown,
  };
}

UserTier _tierFromString(String value) {
  return UserTier.values.firstWhere(
    (tier) => tier.name == value,
    orElse: () => UserTier.personalFree,
  );
}

BootstrapStatus _bootstrapStatusFromString(String value) {
  return BootstrapStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => BootstrapStatus.idle,
  );
}

EntitlementStatus _statusForTier(UserTier tier) {
  return switch (tier) {
    UserTier.personalFree => EntitlementStatus.free,
    UserTier.personalPremium => EntitlementStatus.personalPremium,
    UserTier.pebbleHousehold => EntitlementStatus.household,
    UserTier.workspace ||
    UserTier.growth ||
    UserTier.enterprise => EntitlementStatus.household,
  };
}

EntitlementStatus _entitlementStatusFromString(
  String? value, {
  required EntitlementStatus fallback,
}) {
  if (value == null) return fallback;
  return EntitlementStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => fallback,
  );
}

EntitlementSource _entitlementSourceFromString(
  String? value, {
  required EntitlementSource fallback,
}) {
  if (value == null) return fallback;
  return EntitlementSource.values.firstWhere(
    (source) => source.name == value,
    orElse: () => fallback,
  );
}

DateTime? _dateFromRow(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

bool hasActiveStoreEntitlement(
  SubscriptionAccountState account, {
  DateTime? now,
}) {
  final sourceIsStore =
      account.entitlementSource == EntitlementSource.googlePlay ||
      account.entitlementSource == EntitlementSource.revenueCat;
  final isPaidTier =
      account.entitlementTier == UserTier.personalPremium ||
      account.entitlementTier == UserTier.pebbleHousehold;
  final statusIsActive =
      account.entitlementStatus == EntitlementStatus.personalPremium ||
      account.entitlementStatus == EntitlementStatus.household;
  final periodEndsAt = account.entitlementPeriodEndsAt;
  final stillCurrent =
      periodEndsAt == null || periodEndsAt.isAfter(now ?? DateTime.now());
  return sourceIsStore && isPaidTier && statusIsActive && stillCurrent;
}

@visibleForTesting
bool shouldApplyServerExpiredEntitlement(
  SubscriptionAccountState account, {
  required DateTime checkedAt,
  DateTime? now,
}) {
  if (hasActiveStoreEntitlement(account, now: now)) {
    return false;
  }
  final lastCheckedAt = account.lastEntitlementCheckAt;
  if (lastCheckedAt != null && checkedAt.isBefore(lastCheckedAt)) {
    return false;
  }
  return true;
}
