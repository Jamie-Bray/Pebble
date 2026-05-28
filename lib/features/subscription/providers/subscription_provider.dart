import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      _load();
    }
  }

  final LocalDb _db;
  final SharedPreferences? prefs;
  final bool isProduction;
  final SupabaseClient? supabaseClient;

  static const _sourceKey = 'pebble.entitlement.source';
  static const _statusKey = 'pebble.entitlement.status';
  static const _lastCheckedAtKey = 'pebble.entitlement.last_checked_at';
  static const _periodEndsAtKey = 'pebble.entitlement.period_ends_at';
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
  }) async {
    final next = state.copyWith(
      entitlementTier: newTier,
      clearPendingTier: true,
      entitlementStatus: _statusForTier(newTier),
      entitlementSource: EntitlementSource.revenueCat,
      lastEntitlementCheckAt: DateTime.now(),
      entitlementPeriodEndsAt: periodEndsAt,
      clearEntitlementPeriodEndsAt: periodEndsAt == null,
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
    final next = state.copyWith(
      entitlementTier: newTier,
      clearPendingTier: true,
      entitlementStatus: _statusForTier(newTier),
      entitlementSource: EntitlementSource.serverVerified,
      lastEntitlementCheckAt: DateTime.now(),
      entitlementPeriodEndsAt: periodEndsAt,
      clearEntitlementPeriodEndsAt: periodEndsAt == null,
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
    final next = state.copyWith(
      entitlementTier: UserTier.personalFree,
      clearPendingTier: true,
      entitlementStatus: EntitlementStatus.expired,
      entitlementSource: _expiredEntitlementSource(state.entitlementSource),
      lastEntitlementCheckAt: DateTime.now(),
      clearEntitlementPeriodEndsAt: true,
      clearEntitlementError: true,
      bootstrapStatus: BootstrapStatus.idle,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
    await _persistEntitlementMetadata(next);
  }

  Future<bool> refreshServerVerifiedEntitlement() async {
    final client = supabaseClient;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return false;
    }

    final rows = await client
        .from('personal_entitlements')
        .select(
          'entitlement_tier,status,period_ends_at,last_verified_at,updated_at',
        )
        .eq('owner_user_id', user.id)
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
        return true;
      }
      if (status == 'expired' && expiredRow == null) {
        expiredRow = row;
      }
    }

    if (expiredRow != null) {
      final checkedAt = _dateFromRow(expiredRow['last_verified_at']) ?? now;
      if (state.lastEntitlementCheckAt != null &&
          checkedAt.isBefore(state.lastEntitlementCheckAt!)) {
        return false;
      }
      final next = state.copyWith(
        entitlementTier: UserTier.personalFree,
        clearPendingTier: true,
        entitlementStatus: EntitlementStatus.expired,
        entitlementSource: EntitlementSource.serverVerified,
        lastEntitlementCheckAt: checkedAt,
        clearEntitlementPeriodEndsAt: true,
        clearEntitlementError: true,
        bootstrapStatus: BootstrapStatus.idle,
        clearLastSyncError: true,
      );
      state = next;
      await _persist(next);
      await _persistEntitlementMetadata(next);
      return true;
    }

    return false;
  }

  Future<void> recordEntitlementCheckError(String message) async {
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
    final next = state.copyWith(
      clearPendingTier: true,
      userId: userId,
      email: email,
      authProvider: authProvider,
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
    final next = state.copyWith(
      bootstrapStatus: status,
      lastBootstrapAt: status == BootstrapStatus.ready ? now : null,
      lastSyncAt: status == BootstrapStatus.ready ? now : null,
      lastSyncError: clearError ? null : error,
      clearLastSyncError: clearError,
    );
    state = next;
    await _persist(next);
  }

  Future<void> noteSyncSuccess() async {
    final now = DateTime.now();
    final next = state.copyWith(
      lastSyncAt: now,
      bootstrapStatus: state.bootstrapStatus == BootstrapStatus.preparing
          ? BootstrapStatus.syncing
          : state.bootstrapStatus == BootstrapStatus.error
          ? BootstrapStatus.ready
          : state.bootstrapStatus,
      clearLastSyncError: true,
    );
    state = next;
    await _persist(next);
  }

  Future<void> noteSyncFailure(String error) async {
    final next = state.copyWith(
      bootstrapStatus: BootstrapStatus.error,
      lastSyncError: error,
    );
    state = next;
    await _persist(next);
  }

  Future<void> signOutIdentity() async {
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

  Future<void> resetAfterAccountDeletion() async {
    state = const SubscriptionAccountState.initial();
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
    return state.copyWith(
      entitlementStatus: status,
      entitlementSource: source,
      lastEntitlementCheckAt: checkedAtRaw == null
          ? null
          : DateTime.tryParse(checkedAtRaw),
      entitlementPeriodEndsAt: periodEndsAtRaw == null
          ? null
          : DateTime.tryParse(periodEndsAtRaw),
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
    final error = next.entitlementError;
    if (error == null || error.isEmpty) {
      await prefs.remove(_lastErrorKey);
    } else {
      await prefs.setString(_lastErrorKey, error);
    }
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
