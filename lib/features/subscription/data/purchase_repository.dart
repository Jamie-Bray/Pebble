import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/data/google_play_purchase_repository.dart';

enum BillingPlan { monthly, yearly }

enum PurchaseStore { googlePlay, appStore }

class PebbleProductIds {
  static const personalPremium = 'personal_premium';
}

class PebbleBasePlanIds {
  static const monthly = 'monthly';
  static const yearly = 'yearly';
}

class PremiumProduct {
  const PremiumProduct({
    required this.productId,
    required this.basePlanId,
    required this.plan,
    required this.title,
    required this.priceLabel,
    required this.detailLabel,
    required this.isPurchasable,
    this.offerToken,
    this.badgeLabel,
  });

  final String productId;
  final String basePlanId;
  final BillingPlan plan;
  final String title;
  final String priceLabel;
  final String detailLabel;
  final String? offerToken;
  final String? badgeLabel;
  final bool isPurchasable;

  bool get hasValidOfferToken => offerToken != null && offerToken!.isNotEmpty;
}

class PurchaseResult {
  const PurchaseResult({
    required this.tier,
    required this.plan,
    required this.requiresSignIn,
    required this.message,
  });

  final UserTier tier;
  final BillingPlan plan;
  final bool requiresSignIn;
  final String message;
}

abstract class EntitlementStore {
  Future<void> applyVerifiedPersonalEntitlement(UserTier tier);
  Future<void> applyExpiredEntitlement();
  Future<void> recordEntitlementError(String message);
}

class LocalEntitlementStore implements EntitlementStore {
  LocalEntitlementStore(this._ref);

  final Ref _ref;

  @override
  Future<void> applyVerifiedPersonalEntitlement(UserTier tier) async {
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .applyStoreEntitlement(tier);
  }

  @override
  Future<void> applyExpiredEntitlement() async {
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .applyExpiredStoreEntitlement();
  }

  @override
  Future<void> recordEntitlementError(String message) async {
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .recordEntitlementCheckError(message);
  }
}

abstract class PurchaseRepository extends ChangeNotifier {
  List<PremiumProduct> get personalPremiumProducts;
  String? get manageSubscriptionsUrl;
  bool get isPurchaseAvailable;
  bool get billingAvailable;
  DateTime? get lastPurchaseCheckAt;
  Set<String> get loadedProductIds;
  String? get unavailableReason;
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan);
  Future<PurchaseResult> restorePurchases();
}

class StoreUnavailablePurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  StoreUnavailablePurchaseRepository(this._message);

  final String _message;

  @override
  String? get manageSubscriptionsUrl => null;

  @override
  bool get isPurchaseAvailable => false;

  @override
  bool get billingAvailable => false;

  @override
  DateTime? get lastPurchaseCheckAt => null;

  @override
  Set<String> get loadedProductIds => const <String>{};

  @override
  String get unavailableReason => _message;

  @override
  List<PremiumProduct> get personalPremiumProducts =>
      getPlaceholderPremiumCatalog(isPurchasable: false);

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    throw StateError(_message);
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    throw StateError(_message);
  }
}

List<PremiumProduct> getPlaceholderPremiumCatalog({
  required bool isPurchasable,
}) {
  return [
    PremiumProduct(
      productId: PebbleProductIds.personalPremium,
      basePlanId: PebbleBasePlanIds.monthly,
      plan: BillingPlan.monthly,
      title: 'Monthly',
      priceLabel: '\$0.99',
      detailLabel: 'per month. Cancel anytime.',
      isPurchasable: isPurchasable,
    ),
    PremiumProduct(
      productId: PebbleProductIds.personalPremium,
      basePlanId: PebbleBasePlanIds.yearly,
      plan: BillingPlan.yearly,
      title: 'Yearly',
      priceLabel: '\$6.99',
      detailLabel: 'per year. About \$0.58 / month.',
      badgeLabel: 'Best value',
      isPurchasable: isPurchasable,
    ),
  ];
}

final entitlementStoreProvider = Provider<EntitlementStore>((ref) {
  return LocalEntitlementStore(ref);
});

final purchaseRepositoryProvider = ChangeNotifierProvider<PurchaseRepository>((
  ref,
) {
  return GooglePlayPurchaseRepository(ref);
});
