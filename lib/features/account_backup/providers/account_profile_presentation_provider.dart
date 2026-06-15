import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

class AccountProfileLimit {
  const AccountProfileLimit({required this.value, required this.label});

  final String value;
  final String label;
}

class AccountProfilePresentation {
  const AccountProfilePresentation({
    required this.isSignedIn,
    required this.identityLabel,
    required this.identityDetail,
    required this.providerLabel,
    required this.planName,
    required this.planDetail,
    required this.planStatusLabel,
    required this.limits,
    required this.canStartPremium,
    required this.canRestorePurchase,
    required this.canManagePlan,
  });

  final bool isSignedIn;
  final String identityLabel;
  final String identityDetail;
  final String? providerLabel;
  final String planName;
  final String planDetail;
  final String planStatusLabel;
  final List<AccountProfileLimit> limits;
  final bool canStartPremium;
  final bool canRestorePurchase;
  final bool canManagePlan;
}

final accountProfilePresentationProvider = Provider<AccountProfilePresentation>(
  (ref) {
    final auth = ref.watch(authSessionProvider);
    final purchase = ref.watch(purchaseRepositoryProvider);
    final entitlement = ref.watch(entitlementStateProvider);
    final policy = ref.watch(premiumFeaturePolicyProvider);
    final lifecycle = ref.watch(subscriptionLifecycleProvider);
    final account = ref.watch(subscriptionAccountControllerProvider);
    final limits = _limitsFor(policy);
    final hasLocalPremium =
        policy.localPremiumAccess == LocalPremiumAccess.active ||
        policy.localPremiumAccess == LocalPremiumAccess.historyGrace;

    return AccountProfilePresentation(
      isSignedIn: auth.isSignedIn,
      identityLabel: auth.isSignedIn
          ? (auth.email ?? 'Your account')
          : 'Not signed in',
      identityDetail: auth.isSignedIn
          ? 'Backup and restore use this account.'
          : 'Pebble works locally without an account.',
      providerLabel: _providerLabel(auth.provider),
      planName: _planName(entitlement.personalTier, lifecycle),
      planDetail: _planDetail(
        policy: policy,
        purchase: purchase,
        accountError: account.entitlementError,
      ),
      planStatusLabel: _planStatusLabel(policy),
      limits: limits,
      canStartPremium:
          !hasLocalPremium &&
          purchase.isPurchaseAvailable &&
          entitlement.personalTier == UserTier.personalFree,
      canRestorePurchase: purchase.isPurchaseAvailable,
      canManagePlan: hasLocalPremium && purchase.manageSubscriptionsUrl != null,
    );
  },
);

List<AccountProfileLimit> _limitsFor(PremiumFeaturePolicy policy) {
  if (policy.localPremiumAccess == LocalPremiumAccess.historyGrace) {
    return const [
      AccountProfileLimit(value: '21 days', label: 'History kept'),
      AccountProfileLimit(value: '2', label: 'Routines'),
      AccountProfileLimit(value: '10', label: 'Steps each'),
    ];
  }
  if (policy.hasActiveLocalPremium) {
    return const [
      AccountProfileLimit(value: '21 days', label: 'History kept'),
      AccountProfileLimit(value: 'Unlimited', label: 'Routines'),
      AccountProfileLimit(value: 'Unlimited', label: 'Steps each'),
    ];
  }
  return const [
    AccountProfileLimit(value: '48h', label: 'History kept'),
    AccountProfileLimit(value: '2', label: 'Routines'),
    AccountProfileLimit(value: '10', label: 'Steps each'),
  ];
}

String _planName(UserTier tier, SubscriptionLifecycle lifecycle) {
  if (lifecycle.phase == SubscriptionLifecyclePhase.expiredGrace) {
    return 'Premium recently ended';
  }
  if (lifecycle.phase == SubscriptionLifecyclePhase.expired) {
    return 'Free plan';
  }
  switch (tier) {
    case UserTier.personalPremium:
      return 'Personal Premium';
    case UserTier.pebbleHousehold:
      return 'Household';
    case UserTier.workspace:
      return 'Workspace';
    case UserTier.growth:
      return 'Growth';
    case UserTier.enterprise:
      return 'Enterprise';
    case UserTier.personalFree:
      return 'Free plan';
  }
}

String _planDetail({
  required PremiumFeaturePolicy policy,
  required PurchaseRepository purchase,
  required String? accountError,
}) {
  if (policy.localPremiumAccess == LocalPremiumAccess.unavailable) {
    return purchase.unavailableReason ?? 'Premium is not available yet.';
  }
  if (policy.localPremiumAccess == LocalPremiumAccess.historyGrace) {
    return 'Your longer history is still available during grace.';
  }
  if (policy.localPremiumAccess == LocalPremiumAccess.expired) {
    return 'Pebble is using Free limits again.';
  }
  if (policy.hasActiveLocalPremium) {
    if (policy.serverFeatureStatus == ServerFeatureStatus.verificationFailed) {
      return accountError ?? 'Backup verification needs another check.';
    }
    return 'Unlimited routines, unlimited steps, and longer history are active.';
  }
  return 'Upgrade when you want unlimited routines, longer history, and backup.';
}

String _planStatusLabel(PremiumFeaturePolicy policy) {
  switch (policy.localPremiumAccess) {
    case LocalPremiumAccess.active:
      return 'Premium active';
    case LocalPremiumAccess.historyGrace:
      return 'Grace period';
    case LocalPremiumAccess.expired:
      return 'Premium ended';
    case LocalPremiumAccess.loading:
      return 'Checking plan';
    case LocalPremiumAccess.unavailable:
      return 'Store unavailable';
    case LocalPremiumAccess.free:
      return 'Free';
  }
}

String? _providerLabel(String? provider) {
  switch (provider) {
    case 'google':
      return 'Google';
    case 'emailOtp':
      return 'Email';
    case 'apple':
      return 'Apple';
    case null:
    case '':
      return null;
    default:
      return provider;
  }
}
