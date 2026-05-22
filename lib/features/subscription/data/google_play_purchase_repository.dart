import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';

class PurchaseFlowException implements Exception {
  const PurchaseFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GooglePlayPurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  GooglePlayPurchaseRepository(this._ref) {
    _initStream();
    unawaited(_initialise());
  }

  static const _personalProductIds = <String>{PebbleProductIds.personalPremium};
  static const _allProductIds = <String>{PebbleProductIds.personalPremium};

  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _billingAvailable = false;
  String? _unavailableReason = 'Loading Google Play Billing...';
  DateTime? _lastPurchaseCheckAt;
  List<ProductDetails> _products = [];
  Completer<PurchaseResult>? _purchaseCompleter;
  BillingPlan? _purchasePlan;

  @override
  String? get manageSubscriptionsUrl => Platform.isAndroid
      ? 'https://play.google.com/store/account/subscriptions'
      : null;

  @override
  bool get billingAvailable => _billingAvailable;

  @override
  DateTime? get lastPurchaseCheckAt => _lastPurchaseCheckAt;

  @override
  Set<String> get loadedProductIds => _products.map((p) => p.id).toSet();

  @override
  bool get isPurchaseAvailable =>
      _billingAvailable &&
      personalPremiumProducts.any((product) => product.hasValidOfferToken);

  @override
  String? get unavailableReason =>
      isPurchaseAvailable ? null : _unavailableReason;

  @override
  List<PremiumProduct> get personalPremiumProducts {
    final products = <PremiumProduct>[];
    for (final candidate in _products) {
      final product = _premiumProductFromDetails(candidate);
      if (product != null) {
        products.add(product);
      }
    }
    if (products.isEmpty) {
      return getPlaceholderPremiumCatalog(isPurchasable: false);
    }
    products.sort((a, b) => a.plan.index.compareTo(b.plan.index));
    return products;
  }

  void _initStream() {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseDetailsUpdate,
      onDone: () => _subscription.cancel(),
      onError: (Object error) {
        _unavailableReason = 'Google Play Billing reported an error.';
        _recordEntitlementError(_unavailableReason!);
        notifyListeners();
      },
    );
  }

  Future<void> _initialise() async {
    if (!Platform.isAndroid) {
      _billingAvailable = false;
      _unavailableReason =
          'Purchases are available from Google Play on Android.';
      notifyListeners();
      return;
    }

    await _loadProducts();
    await _restoreOwnedPurchases(silent: true);
  }

  Future<void> _loadProducts() async {
    try {
      _billingAvailable = await _iap.isAvailable();
      if (!_billingAvailable) {
        _unavailableReason =
            'Google Play Billing is not available on this device right now.';
        notifyListeners();
        return;
      }

      final response = await _iap.queryProductDetails(_allProductIds);
      _lastPurchaseCheckAt = DateTime.now();
      if (response.error != null) {
        _billingAvailable = false;
        _unavailableReason =
            'Could not load Google Play products: ${response.error!.message}';
        _recordEntitlementError(_unavailableReason!);
        notifyListeners();
        return;
      }

      _products = response.productDetails;
      final missingPersonalPremium = !personalPremiumProducts.any(
        (product) => product.hasValidOfferToken,
      );
      _unavailableReason = missingPersonalPremium
          ? 'Personal Premium is not available from Google Play yet.'
          : null;
      notifyListeners();
    } catch (error) {
      _billingAvailable = false;
      _unavailableReason =
          'Could not reach Google Play Billing. Check your connection and try again.';
      _recordEntitlementError(_unavailableReason!);
      debugPrint('Failed to load Google Play products: $error');
      notifyListeners();
    }
  }

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    if (!isPurchaseAvailable) {
      throw PurchaseFlowException(
        unavailableReason ?? 'Personal Premium is not available right now.',
      );
    }
    final premiumProduct = personalPremiumProducts.firstWhere(
      (product) => product.plan == plan && product.hasValidOfferToken,
      orElse: () => throw PurchaseFlowException(
        plan == BillingPlan.yearly
            ? 'Yearly Personal Premium is not available from Google Play yet.'
            : 'Monthly Personal Premium is not available from Google Play yet.',
      ),
    );
    final productDetails = _products.firstWhere(
      (product) => _matchesPremiumProduct(product, premiumProduct),
    );

    _purchaseCompleter?.completeError(
      const PurchaseFlowException('A purchase is already in progress.'),
    );
    final completer = Completer<PurchaseResult>();
    _purchaseCompleter = completer;
    _purchasePlan = premiumProduct.plan;

    try {
      final purchaseParam = Platform.isAndroid
          ? GooglePlayPurchaseParam(
              productDetails: productDetails,
              offerToken: premiumProduct.offerToken,
            )
          : PurchaseParam(productDetails: productDetails);
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started && !completer.isCompleted) {
        completer.completeError(
          const PurchaseFlowException('Google Play could not start checkout.'),
        );
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(
          const PurchaseFlowException(
            'Google Play checkout could not be started.',
          ),
        );
      }
    }

    return completer.future.whenComplete(() {
      if (identical(_purchaseCompleter, completer)) {
        _purchaseCompleter = null;
        _purchasePlan = null;
      }
    });
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    final restored = await _restoreOwnedPurchases(silent: false);
    if (restored != null) {
      return restored;
    }
    throw const PurchaseFlowException(
      'No active Personal Premium purchase was found on this Google Play account.',
    );
  }

  Future<PurchaseResult?> _restoreOwnedPurchases({required bool silent}) async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final androidAddition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();
      _lastPurchaseCheckAt = DateTime.now();
      if (response.error != null) {
        final message =
            'Could not check existing Google Play purchases: ${response.error!.message}';
        _recordEntitlementError(message);
        if (!silent) throw PurchaseFlowException(message);
        notifyListeners();
        return null;
      }

      final purchases = response.pastPurchases
          .where((purchase) => _allProductIds.contains(purchase.productID))
          .toList();
      if (purchases.isEmpty) {
        if (!silent) {
          await _ref.read(entitlementStoreProvider).applyExpiredEntitlement();
        }
        notifyListeners();
        return null;
      }

      for (final purchase in purchases) {
        final result = await _verifyAndApply(purchase, restored: true);
        if (result != null &&
            _personalProductIds.contains(purchase.productID)) {
          notifyListeners();
          return result;
        }
      }
    } on PurchaseFlowException {
      rethrow;
    } catch (error) {
      const message =
          'Could not check Google Play purchases. Existing verified access will stay cached until Play is reachable.';
      _recordEntitlementError(message);
      debugPrint('Failed to restore Google Play purchases: $error');
      if (!silent) throw const PurchaseFlowException(message);
    } finally {
      notifyListeners();
    }
    return null;
  }

  Future<void> _onPurchaseDetailsUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (!_allProductIds.contains(purchaseDetails.productID)) {
        continue;
      }

      _lastPurchaseCheckAt = DateTime.now();
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _completePurchaseFlowError(
            'Your payment is pending in Google Play. Pebble will unlock Personal Premium once it is approved.',
          );
          break;
        case PurchaseStatus.error:
          _completePurchaseFlowError(
            purchaseDetails.error?.message ?? 'Google Play purchase failed.',
          );
          break;
        case PurchaseStatus.canceled:
          _completePurchaseFlowError('Google Play checkout was cancelled.');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final result = await _verifyAndApply(
            purchaseDetails,
            restored: purchaseDetails.status == PurchaseStatus.restored,
            plan: _purchasePlan,
          );
          if (result != null &&
              _purchaseCompleter != null &&
              !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(result);
          }
          break;
      }

      if (purchaseDetails.pendingCompletePurchase &&
          purchaseDetails.status != PurchaseStatus.pending) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
    notifyListeners();
  }

  Future<PurchaseResult?> _verifyAndApply(
    PurchaseDetails purchaseDetails, {
    required bool restored,
    BillingPlan? plan,
  }) async {
    final verification = await _verifyPurchaseOnServer(purchaseDetails);
    switch (verification.status) {
      case _VerifiedPurchaseStatus.active:
        final tier = verification.tier;
        if (tier == null) {
          _completePurchaseFlowError(
            'Purchase verification returned an unknown entitlement tier.',
          );
          return null;
        }
        await _ref
            .read(entitlementStoreProvider)
            .applyVerifiedPersonalEntitlement(tier);
        return PurchaseResult(
          tier: tier,
          plan: plan ?? BillingPlan.monthly,
          requiresSignIn: false,
          message: restored
              ? 'Personal Premium restored from Google Play.'
              : 'Welcome to Personal Premium.',
        );
      case _VerifiedPurchaseStatus.expired:
        await _ref.read(entitlementStoreProvider).applyExpiredEntitlement();
        _completePurchaseFlowError(
          'Google Play says this subscription is no longer active.',
        );
        return null;
      case _VerifiedPurchaseStatus.failed:
        _completePurchaseFlowError(
          verification.error ??
              'Google Play purchase verification failed. Please try again.',
        );
        return null;
    }
  }

  Future<_VerificationResult> _verifyPurchaseOnServer(
    PurchaseDetails purchaseDetails,
  ) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) {
      const message = 'Purchase verification is not configured in this build.';
      await _ref.read(entitlementStoreProvider).recordEntitlementError(message);
      return const _VerificationResult.failed(message);
    }

    try {
      final response = await client.functions.invoke(
        'verify-purchase',
        body: {
          'store': 'googlePlay',
          'productId': purchaseDetails.productID,
          'serverVerificationData':
              purchaseDetails.verificationData.serverVerificationData,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final message =
            _errorFromResponseData(response.data) ??
            'Google Play purchase verification failed.';
        await _ref
            .read(entitlementStoreProvider)
            .recordEntitlementError(message);
        return _VerificationResult.failed(message);
      }

      final data = response.data;
      if (data is! Map || data['entitlement'] is! Map) {
        const message =
            'Purchase verification returned an unexpected response.';
        await _ref
            .read(entitlementStoreProvider)
            .recordEntitlementError(message);
        return const _VerificationResult.failed(message);
      }
      final entitlement = data['entitlement'] as Map;
      final status = entitlement['status']?.toString();
      final tier = _tierFromServer(entitlement['tier']?.toString());
      if (_isActiveServerStatus(status)) {
        if (tier == null) {
          const message =
              'Purchase verification returned an unknown entitlement tier.';
          await _ref
              .read(entitlementStoreProvider)
              .recordEntitlementError(message);
          return const _VerificationResult.failed(message);
        }
        return _VerificationResult.active(tier);
      }
      return const _VerificationResult.expired();
    } catch (error) {
      const message =
          'Could not verify with Google Play right now. Existing verified access will stay cached until the next check.';
      await _ref.read(entitlementStoreProvider).recordEntitlementError(message);
      debugPrint('Failed to verify purchase: $error');
      return const _VerificationResult.failed(message);
    }
  }

  void _completePurchaseFlowError(String message) {
    _recordEntitlementError(message);
    final completer = _purchaseCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(PurchaseFlowException(message));
    }
  }

  void _recordEntitlementError(String message) {
    unawaited(
      _ref.read(entitlementStoreProvider).recordEntitlementError(message),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

PremiumProduct? _premiumProductFromDetails(ProductDetails product) {
  if (product.id != PebbleProductIds.personalPremium ||
      product is! GooglePlayProductDetails) {
    return null;
  }
  final subscriptionIndex = product.subscriptionIndex;
  final offerDetails = product.productDetails.subscriptionOfferDetails;
  if (subscriptionIndex == null ||
      offerDetails == null ||
      subscriptionIndex >= offerDetails.length) {
    return null;
  }

  final offer = offerDetails[subscriptionIndex];
  final plan = _planForBasePlanId(offer.basePlanId);
  if (plan == null) {
    return null;
  }

  return PremiumProduct(
    productId: product.id,
    basePlanId: offer.basePlanId,
    plan: plan,
    title: plan == BillingPlan.yearly ? 'Yearly' : 'Monthly',
    priceLabel: product.price,
    detailLabel: plan == BillingPlan.yearly
        ? 'per year. Best value.'
        : 'per month. Cancel anytime.',
    badgeLabel: plan == BillingPlan.yearly ? 'Best value' : null,
    offerToken: product.offerToken,
    isPurchasable: product.offerToken != null && product.offerToken!.isNotEmpty,
  );
}

bool _matchesPremiumProduct(
  ProductDetails productDetails,
  PremiumProduct premiumProduct,
) {
  if (productDetails.id != premiumProduct.productId ||
      productDetails is! GooglePlayProductDetails) {
    return false;
  }
  return productDetails.offerToken == premiumProduct.offerToken;
}

BillingPlan? _planForBasePlanId(String basePlanId) {
  return switch (basePlanId) {
    PebbleBasePlanIds.monthly => BillingPlan.monthly,
    PebbleBasePlanIds.yearly => BillingPlan.yearly,
    _ => null,
  };
}

enum _VerifiedPurchaseStatus { active, expired, failed }

class _VerificationResult {
  const _VerificationResult._(this.status, this.tier, this.error);
  const _VerificationResult.active(UserTier tier)
    : this._(_VerifiedPurchaseStatus.active, tier, null);
  const _VerificationResult.expired()
    : this._(_VerifiedPurchaseStatus.expired, null, null);
  const _VerificationResult.failed(String error)
    : this._(_VerifiedPurchaseStatus.failed, null, error);

  final _VerifiedPurchaseStatus status;
  final UserTier? tier;
  final String? error;
}

UserTier? _tierFromServer(String? tier) {
  return switch (tier) {
    'personalPremium' => UserTier.personalPremium,
    'pebbleHousehold' => UserTier.pebbleHousehold,
    _ => null,
  };
}

bool _isActiveServerStatus(String? status) {
  return status == 'active' ||
      status == 'grace' ||
      status == 'cancelled_active';
}

String? _errorFromResponseData(Object? data) {
  if (data is Map && data['error'] != null) {
    return data['error'].toString();
  }
  return null;
}
