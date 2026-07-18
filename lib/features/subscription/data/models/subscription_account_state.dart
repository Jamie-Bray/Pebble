import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';

enum BootstrapStatus { idle, preparing, syncing, ready, error }

class SubscriptionAccountState {
  // Storage-only transitional model. These identity fields are cached account
  // details for local/cloud ownership and resume logic, not the active auth
  // session source of truth.
  final UserTier entitlementTier;
  final UserTier? pendingTier;
  final BootstrapStatus bootstrapStatus;
  final String? userId;
  final String? email;
  final String? authProvider;
  final DateTime? lastBootstrapAt;
  final DateTime? lastSyncAt;
  final String? lastSyncError;
  final EntitlementStatus entitlementStatus;
  final EntitlementSource entitlementSource;
  final DateTime? lastEntitlementCheckAt;
  final DateTime? entitlementPeriodEndsAt;

  /// When the entitlement first became expired. Sticky across repeated
  /// entitlement checks so the grace countdown does not slide forward.
  final DateTime? entitlementExpiredAt;
  final String? entitlementError;

  const SubscriptionAccountState({
    required this.entitlementTier,
    required this.pendingTier,
    required this.bootstrapStatus,
    required this.userId,
    required this.email,
    required this.authProvider,
    required this.lastBootstrapAt,
    required this.lastSyncAt,
    required this.lastSyncError,
    this.entitlementStatus = EntitlementStatus.free,
    this.entitlementSource = EntitlementSource.localCache,
    this.lastEntitlementCheckAt,
    this.entitlementPeriodEndsAt,
    this.entitlementExpiredAt,
    this.entitlementError,
  });

  const SubscriptionAccountState.initial()
    : entitlementTier = UserTier.personalFree,
      pendingTier = null,
      bootstrapStatus = BootstrapStatus.idle,
      userId = null,
      email = null,
      authProvider = null,
      lastBootstrapAt = null,
      lastSyncAt = null,
      lastSyncError = null,
      entitlementStatus = EntitlementStatus.free,
      entitlementSource = EntitlementSource.localCache,
      lastEntitlementCheckAt = null,
      entitlementPeriodEndsAt = null,
      entitlementExpiredAt = null,
      entitlementError = null;

  SubscriptionAccountState copyWith({
    UserTier? entitlementTier,
    UserTier? pendingTier,
    bool clearPendingTier = false,
    BootstrapStatus? bootstrapStatus,
    String? userId,
    bool clearUserId = false,
    String? email,
    bool clearEmail = false,
    String? authProvider,
    bool clearAuthProvider = false,
    DateTime? lastBootstrapAt,
    bool clearLastBootstrapAt = false,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
    String? lastSyncError,
    bool clearLastSyncError = false,
    EntitlementStatus? entitlementStatus,
    EntitlementSource? entitlementSource,
    DateTime? lastEntitlementCheckAt,
    DateTime? entitlementPeriodEndsAt,
    bool clearEntitlementPeriodEndsAt = false,
    DateTime? entitlementExpiredAt,
    bool clearEntitlementExpiredAt = false,
    String? entitlementError,
    bool clearEntitlementError = false,
  }) {
    return SubscriptionAccountState(
      entitlementTier: entitlementTier ?? this.entitlementTier,
      pendingTier: clearPendingTier ? null : pendingTier ?? this.pendingTier,
      bootstrapStatus: bootstrapStatus ?? this.bootstrapStatus,
      userId: clearUserId ? null : userId ?? this.userId,
      email: clearEmail ? null : email ?? this.email,
      authProvider: clearAuthProvider
          ? null
          : authProvider ?? this.authProvider,
      lastBootstrapAt: clearLastBootstrapAt
          ? null
          : lastBootstrapAt ?? this.lastBootstrapAt,
      lastSyncAt: clearLastSyncAt ? null : lastSyncAt ?? this.lastSyncAt,
      lastSyncError: clearLastSyncError
          ? null
          : lastSyncError ?? this.lastSyncError,
      entitlementStatus: entitlementStatus ?? this.entitlementStatus,
      entitlementSource: entitlementSource ?? this.entitlementSource,
      lastEntitlementCheckAt:
          lastEntitlementCheckAt ?? this.lastEntitlementCheckAt,
      entitlementPeriodEndsAt: clearEntitlementPeriodEndsAt
          ? null
          : entitlementPeriodEndsAt ?? this.entitlementPeriodEndsAt,
      entitlementExpiredAt: clearEntitlementExpiredAt
          ? null
          : entitlementExpiredAt ?? this.entitlementExpiredAt,
      entitlementError: clearEntitlementError
          ? null
          : entitlementError ?? this.entitlementError,
    );
  }

  bool get hasCachedAccountIdentity => userId != null && userId!.isNotEmpty;
  bool get isPremiumPendingAuth => pendingTier == UserTier.personalPremium;
}
