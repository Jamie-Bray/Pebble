import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/data/revenuecat_purchase_repository.dart';

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

class PurchaseCancelledException implements Exception {
  const PurchaseCancelledException();
}

class PurchaseFlowException implements Exception {
  const PurchaseFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class EntitlementStore {
  Future<void> applyRevenueCatEntitlement(
    UserTier tier, {
    DateTime? periodEndsAt,
  });
  Future<void> applyExpiredEntitlement();
  Future<void> recordEntitlementError(String message);
  Future<bool> refreshServerVerifiedEntitlement({
    bool requestServerReconciliation = false,
  });
}

class LocalEntitlementStore implements EntitlementStore {
  LocalEntitlementStore(this._ref);

  final Ref _ref;

  @override
  Future<void> applyRevenueCatEntitlement(
    UserTier tier, {
    DateTime? periodEndsAt,
  }) async {
    await _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .applyRevenueCatEntitlement(tier, periodEndsAt: periodEndsAt);
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

  @override
  Future<bool> refreshServerVerifiedEntitlement({
    bool requestServerReconciliation = false,
  }) async {
    return _ref
        .read(subscriptionAccountControllerProvider.notifier)
        .refreshServerVerifiedEntitlement(
          requestServerReconciliation: requestServerReconciliation,
        );
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
  Future<void> syncPurchasesSilently({bool waitForServerMirror = false});
  Future<void> logOut();
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

  @override
  Future<void> syncPurchasesSilently({bool waitForServerMirror = false}) async {
    throw StateError(_message);
  }

  @override
  Future<void> logOut() async {}
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
      priceLabel: '',
      detailLabel: 'per month',
      isPurchasable: isPurchasable,
    ),
    PremiumProduct(
      productId: PebbleProductIds.personalPremium,
      basePlanId: PebbleBasePlanIds.yearly,
      plan: BillingPlan.yearly,
      title: 'Annual',
      priceLabel: '',
      detailLabel: 'per year',
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
  return RevenueCatPurchaseRepository(ref);
});
