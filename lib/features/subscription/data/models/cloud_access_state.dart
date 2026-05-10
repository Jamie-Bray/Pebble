import 'package:pebble_routines/features/subscription/domain/user_tier.dart';

enum EntitlementStatus { free, personalPremium, household, expired, unknown }

enum EntitlementSource { localCache, googlePlay, serverVerified, unknown }

class EntitlementState {
  const EntitlementState({
    required this.personalTier,
    required this.source,
    required this.lastCheckedAt,
    required this.isRefreshing,
    required this.lastError,
    this.status,
  });

  final UserTier personalTier;
  final EntitlementSource source;
  final DateTime? lastCheckedAt;
  final bool isRefreshing;
  final String? lastError;
  final EntitlementStatus? status;

  bool get isPersonalPaid =>
      personalTier == UserTier.personalPremium ||
      personalTier == UserTier.pebbleHousehold;
}

enum PersonalCloudAccessStatus {
  offFree,
  offSignedInNoEntitlement,
  consentRequired,
  syncing,
  available,
  pausedSignedOut,
  offlinePending,
  error,
}

class PersonalCloudAccessState {
  const PersonalCloudAccessState({
    required this.status,
    required this.label,
    required this.detail,
  });

  final PersonalCloudAccessStatus status;
  final String label;
  final String? detail;

  bool get isEnabled =>
      status == PersonalCloudAccessStatus.available ||
      status == PersonalCloudAccessStatus.syncing ||
      status == PersonalCloudAccessStatus.offlinePending;
}

enum WorkspaceAccessStatus { none, member }

class WorkspaceAccessState {
  const WorkspaceAccessState({required this.status});

  final WorkspaceAccessStatus status;

  bool get isCloudEnabled => status == WorkspaceAccessStatus.member;
}

class CloudAccessPolicy {
  const CloudAccessPolicy({
    required this.cachedOwnerUserId,
    required this.personalCloudEnabled,
    required this.canQueuePersonalSync,
    required this.workspaceCloudEnabled,
    required this.isSignedIn,
  });

  final String? cachedOwnerUserId;
  final bool personalCloudEnabled;
  final bool canQueuePersonalSync;
  final bool workspaceCloudEnabled;
  final bool isSignedIn;

  bool get canUploadCloudChanges =>
      (personalCloudEnabled || workspaceCloudEnabled) &&
      cachedOwnerUserId != null &&
      cachedOwnerUserId!.isNotEmpty;
}
