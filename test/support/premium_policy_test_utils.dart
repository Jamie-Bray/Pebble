import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';

PremiumFeaturePolicy premiumFeaturePolicyForTier(UserTier tier) {
  final isPremium = tier == UserTier.personalPremium;
  return PremiumFeaturePolicy(
    localPremiumAccess: isPremium
        ? LocalPremiumAccess.active
        : LocalPremiumAccess.free,
    serverFeatureStatus: ServerFeatureStatus.signedOut,
    canUseUnlimitedRoutines: isPremium,
    canUsePremiumThemes: isPremium,
    canUseGuidanceAudio: isPremium,
    canUseExtraProofPhotos: isPremium,
    hasPremiumHistoryRetention: isPremium,
    canUseSharedAlerts: false,
    canUseCloudBackup: false,
    needsSignInForServerFeatures: isPremium,
    hasServerVerifiedPremium: false,
    userFacingStatus: null,
  );
}
