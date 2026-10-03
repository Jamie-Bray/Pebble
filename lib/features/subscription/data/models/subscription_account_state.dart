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

  /// When this device first confirmed the lapse with the store or the server.
  /// Null while the lapse is only inferred from a cached period end (for
  /// example offline, when a renewal may simply not have been seen yet).
  /// Sticky, so the grace countdown cannot be restarted by later checks.
  final DateTime? entitlementLapseNoticedAt;

  /// Whether the store says the subscription renews at the end of the
  /// current period. False after the user cancels. Null when unknown.
  final bool? entitlementWillRenew;

  /// When the store reported a billing problem (Google Play grace period or
  /// account hold, App Store billing retry). Null when there is none.
  final DateTime? entitlementBillingIssueAt;
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
    this.entitlementLapseNoticedAt,
    this.entitlementWillRenew,
    this.entitlementBillingIssueAt,
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
      entitlementLapseNoticedAt = null,
      entitlementWillRenew = null,
      entitlementBillingIssueAt = null,
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
    DateTime? entitlementLapseNoticedAt,
    bool clearEntitlementLapseNoticedAt = false,
    bool? entitlementWillRenew,
    bool clearEntitlementWillRenew = false,
    DateTime? entitlementBillingIssueAt,
    bool clearEntitlementBillingIssueAt = false,
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
      entitlementLapseNoticedAt: clearEntitlementLapseNoticedAt
          ? null
          : entitlementLapseNoticedAt ?? this.entitlementLapseNoticedAt,
      entitlementWillRenew: clearEntitlementWillRenew
          ? null
          : entitlementWillRenew ?? this.entitlementWillRenew,
      entitlementBillingIssueAt: clearEntitlementBillingIssueAt
          ? null
          : entitlementBillingIssueAt ?? this.entitlementBillingIssueAt,
      entitlementError: clearEntitlementError
          ? null
          : entitlementError ?? this.entitlementError,
    );
  }

  bool get hasCachedAccountIdentity => userId != null && userId!.isNotEmpty;
  bool get isPremiumPendingAuth => pendingTier == UserTier.personalPremium;
}
