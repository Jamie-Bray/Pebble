import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/entitlement_flow_messages.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/revenuecat_runtime_config.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

class RevenueCatPurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  RevenueCatPurchaseRepository(this._ref) {
    unawaited(_initialise());
  }

  static const _backupVerificationFailedMessage =
      EntitlementFlowMessages.backupSetupFailed;

  final Ref _ref;

  bool _configured = false;
  bool _billingAvailable = false;
  String? _configuredUserId;
  String? _unavailableReason = 'Loading store products...';
  DateTime? _lastPurchaseCheckAt;
  bool _loadingProducts = true;
  Future<void>? _retryInFlight;
  final Map<BillingPlan, rc.Package> _packagesByPlan = {};
  String? _storeManagementUrl;

  static const _storeLoadFailedMessage =
      'Could not load store products. Check your connection and try again.';

  @override
  String? get manageSubscriptionsUrl => revenueCatManageSubscriptionsUrl(
    managementUrl: _storeManagementUrl,
    platform: defaultTargetPlatform,
  );

  @override
  bool get billingAvailable => _billingAvailable;

  @override
  DateTime? get lastPurchaseCheckAt => _lastPurchaseCheckAt;

  @override
  Set<String> get loadedProductIds => _packagesByPlan.values
      .map((package) => package.storeProduct.identifier)
      .toSet();

  @override
  bool get isPurchaseAvailable =>
      _billingAvailable && _packagesByPlan.isNotEmpty;

  @override
  String? get unavailableReason =>
      isPurchaseAvailable ? null : _unavailableReason;

  @override
  bool get isLoadingProducts => _loadingProducts;

  @override
  Future<void> retryLoadProducts() {
    return _retryInFlight ??= _retryLoadProducts().whenComplete(() {
      _retryInFlight = null;
    });
  }

  Future<void> _retryLoadProducts() async {
    final config = _ref.read(revenueCatRuntimeConfigProvider);
    if (!config.supportsCurrentPlatform) {
      _loadingProducts = false;
      notifyListeners();
      return;
    }
    _loadingProducts = true;
    notifyListeners();
    try {
      // Configures RevenueCat if start-up failed before it got that far; a
      // no-op when it is already configured for this user.
      // Bounded so a hung store call can always be retried again; a late
      // answer still lands through _loadOfferings and notifies listeners.
      await () async {
        await _configureForUser(_currentUserId);
        await _loadOfferings();
      }().timeout(const Duration(seconds: 20));
    } catch (error) {
      if (_packagesByPlan.isEmpty) {
        _billingAvailable = false;
        _unavailableReason = _storeLoadFailedMessage;
      }
      debugPrint('Retrying RevenueCat offerings failed: $error');
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  @override
  List<PremiumProduct> get personalPremiumProducts {
    if (_packagesByPlan.isEmpty) {
      return getPlaceholderPremiumCatalog(isPurchasable: false);
    }
    final products = _packagesByPlan.values
        .map(revenueCatPremiumProductFromPackage)
        .whereType<PremiumProduct>()
        .toList();
    products.sort((a, b) => a.plan.index.compareTo(b.plan.index));
    return products;
  }

  Future<void> _initialise() async {
    final config = _ref.read(revenueCatRuntimeConfigProvider);
    if (!config.supportsCurrentPlatform) {
      _billingAvailable = false;
      _loadingProducts = false;
      _unavailableReason =
          'Purchases are not configured for this platform yet.';
      notifyListeners();
      return;
    }
    final userId = _currentUserId;
    try {
      await _configureForUser(userId);
      await _loadOfferingsMarkingLoaded();
      await syncPurchasesSilently();
    } catch (error) {
      _billingAvailable = false;
      _loadingProducts = false;
      _unavailableReason = _storeLoadFailedMessage;
      await _ref
          .read(entitlementStoreProvider)
          .recordEntitlementError(_unavailableReason!);
      debugPrint('Failed to initialise RevenueCat purchases: $error');
      notifyListeners();
    }
  }

  /// Start-up offerings load: products count as loaded (or unavailable) as
  /// soon as the offerings call returns, before the silent sync finishes.
  Future<void> _loadOfferingsMarkingLoaded() async {
    try {
      await _loadOfferings();
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    final userId = _currentUserId;
    await _configureForUser(userId);
    if (_packagesByPlan.isEmpty) {
      await _loadOfferings();
    }
    final package = _packagesByPlan[plan];
    if (package == null) {
      throw StateError(
        plan == BillingPlan.yearly
            ? 'Yearly Personal Premium is not available yet.'
            : 'Monthly Personal Premium is not available yet.',
      );
    }
    late final rc.PurchaseResult result;
    try {
      result = await rc.Purchases.purchase(rc.PurchaseParams.package(package));
      debugPrint(
        '[PremiumEntitlement] Purchase completed through RevenueCat '
        'for plan=${plan.name}.',
      );
    } on PlatformException catch (error) {
      final errorCode = rc.PurchasesErrorHelper.getErrorCode(error);
      if (errorCode == rc.PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelledException();
      }
      if (errorCode == rc.PurchasesErrorCode.paymentPendingError) {
        throw PurchasePendingException(
          revenueCatMessageForPurchasesError(errorCode),
        );
      }
      if (errorCode == rc.PurchasesErrorCode.productAlreadyPurchasedError) {
        final restored = await restorePurchases();
        return PurchaseResult(
          tier: restored.tier,
          plan: plan,
          requiresSignIn: false,
          message: 'Premium is already active on this store account.',
        );
      }
      throw PurchaseFlowException(
        revenueCatMessageForPurchasesError(errorCode),
        isPending: errorCode == rc.PurchasesErrorCode.paymentPendingError,
      );
    }
    return _applyCustomerInfo(
      result.customerInfo,
      plan: plan,
      purchased: true,
      waitForServerMirror: true,
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    final userId = _currentUserId;
    await _configureForUser(userId);
    late final rc.CustomerInfo customerInfo;
    try {
      customerInfo = await rc.Purchases.restorePurchases();
    } on PlatformException catch (error) {
      throw PurchaseFlowException(
        revenueCatMessageForPurchasesError(
          rc.PurchasesErrorHelper.getErrorCode(error),
        ),
      );
    }
    return _applyCustomerInfo(
      customerInfo,
      plan: BillingPlan.monthly,
      waitForServerMirror: true,
    );
  }

  @override
  Future<void> syncPurchasesSilently({bool waitForServerMirror = false}) async {
    final userId = _currentUserId;
    final appUserIdBeforeLogin = await _safeRevenueCatAppUserId();
    await _configureForUser(userId);
    var appUserIdAfterLogin = await _safeRevenueCatAppUserId();
    late final rc.CustomerInfo customerInfo;
    try {
      customerInfo = await rc.Purchases.getCustomerInfo();
    } on PlatformException catch (error) {
      throw PurchaseFlowException(
        revenueCatMessageForPurchasesError(
          rc.PurchasesErrorHelper.getErrorCode(error),
        ),
      );
    }
    _noteManagementUrl(customerInfo);
    var entitlement = _activeEntitlement(customerInfo);
    var restoredAfterLogin = false;
    if (entitlement == null &&
        userId != null &&
        revenueCatAllowsSilentRestore(defaultTargetPlatform)) {
      debugPrint(
        '[PremiumEntitlement] No active RevenueCat entitlement after '
        'logIn; attempting restore for signed-in user=$userId.',
      );
      try {
        final restoredInfo = await rc.Purchases.restorePurchases();
        restoredAfterLogin = true;
        appUserIdAfterLogin = await _safeRevenueCatAppUserId();
        entitlement = _activeEntitlement(restoredInfo);
        debugPrint(
          '[PremiumEntitlement] Signed-in RevenueCat restore completed: '
          'appUserId=${appUserIdAfterLogin ?? 'unknown'}, '
          'hasActiveEntitlement=${entitlement != null}.',
        );
      } on PlatformException catch (error) {
        debugPrint(
          '[PremiumEntitlement] Signed-in RevenueCat restore failed: '
          '${revenueCatMessageForPurchasesError(rc.PurchasesErrorHelper.getErrorCode(error))}',
        );
      }
    }
    if (entitlement == null) {
      _logReconciliationDebug(
        supabaseAuthUid: userId,
        appUserIdBeforeLogin: appUserIdBeforeLogin,
        appUserIdAfterLogin: appUserIdAfterLogin,
        localEntitlementActive: false,
        serverReconciliationCalled: false,
        serverReconciliationStatus: restoredAfterLogin
            ? 'skipped_no_local_active_entitlement_after_restore'
            : 'skipped_no_local_active_entitlement',
      );
      if (await _preserveActiveStoreEntitlementWhenMissing(
        'silent purchase sync',
      )) {
        return;
      }
      if (userId != null && _hasVerifiedPaidRevenueCatEntitlement()) {
        await _ref.read(entitlementStoreProvider).applyExpiredEntitlement();
      } else {
        // Bookkeeping only: no store call. A lapse inferred from the cached
        // period end is now confirmed, which starts the grace countdown.
        await _ref.read(entitlementStoreProvider).confirmLapseIfExpired();
      }
      return;
    }
    debugPrint(
      '[PremiumEntitlement] Active store entitlement detected during sync.',
    );
    final mirrored = await _applyVerifiedEntitlement(
      entitlement,
      waitForServerMirror: waitForServerMirror,
    );
    _logReconciliationDebug(
      supabaseAuthUid: userId,
      appUserIdBeforeLogin: appUserIdBeforeLogin,
      appUserIdAfterLogin: appUserIdAfterLogin,
      localEntitlementActive: true,
      serverReconciliationCalled: userId != null,
      serverReconciliationStatus: userId == null
          ? 'skipped_signed_out'
          : mirrored
          ? 'mirrored'
          : 'not_mirrored',
    );
  }

  @override
  Future<void> logOut() async {
    if (!_configured) return;
    final before = await _safeRevenueCatAppUserId();
    debugPrint(
      '[PremiumEntitlement] RevenueCat logOut requested: '
      'currentAppUserId=${before ?? 'unknown'}.',
    );
    await rc.Purchases.logOut();
    _configuredUserId = null;
    try {
      await _loadOfferings();
    } catch (error) {
      _billingAvailable = false;
      _unavailableReason = _storeLoadFailedMessage;
      debugPrint('Failed to refresh RevenueCat after sign-out: $error');
      notifyListeners();
    }
  }

  Future<void> _configureForUser(String? userId) async {
    final normalizedUserId = userId == null || userId.isEmpty ? null : userId;
    if (_configured && _configuredUserId == normalizedUserId) {
      return;
    }
    if (_configured) {
      if (normalizedUserId != null) {
        final before = await _safeRevenueCatAppUserId();
        debugPrint(
          '[PremiumEntitlement] RevenueCat logIn requested: '
          'currentAppUserId=${before ?? 'unknown'}, '
          'supabaseUserId=$normalizedUserId.',
        );
        final result = await rc.Purchases.logIn(normalizedUserId);
        _configuredUserId = normalizedUserId;
        debugPrint(
          '[PremiumEntitlement] RevenueCat logIn completed: '
          'created=${result.created}, '
          'originalAppUserId=${result.customerInfo.originalAppUserId}, '
          'hasActiveEntitlement=${_activeEntitlement(result.customerInfo) != null}.',
        );
      } else {
        final before = await _safeRevenueCatAppUserId();
        debugPrint(
          '[PremiumEntitlement] RevenueCat switching to anonymous user: '
          'currentAppUserId=${before ?? 'unknown'}.',
        );
        await rc.Purchases.logOut();
        _configuredUserId = null;
      }
      return;
    }
    final config = _ref.read(revenueCatRuntimeConfigProvider);
    final apiKey = config.apiKeyForCurrentPlatform;
    if (apiKey == null) {
      throw StateError('Purchases are not configured for this platform yet.');
    }
    final purchasesConfig = rc.PurchasesConfiguration(apiKey);
    if (normalizedUserId != null) {
      purchasesConfig.appUserID = normalizedUserId;
    }
    await rc.Purchases.configure(purchasesConfig);
    rc.Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _storeManagementUrl = customerInfo.managementURL;
    });
    _configured = true;
    _configuredUserId = normalizedUserId;
    final configuredAppUserId = await _safeRevenueCatAppUserId();
    debugPrint(
      '[PremiumEntitlement] RevenueCat configured: '
      'supabaseUserId=${normalizedUserId ?? 'none'}, '
      'appUserId=${configuredAppUserId ?? 'unknown'}.',
    );
  }

  Future<void> _loadOfferings() async {
    final offerings = await rc.Purchases.getOfferings();
    _lastPurchaseCheckAt = DateTime.now();
    final packages =
        offerings.current?.availablePackages ?? const <rc.Package>[];
    _packagesByPlan
      ..clear()
      ..addEntries(
        packages.map((package) {
          final plan = revenueCatBillingPlanForPackage(package);
          return plan == null ? null : MapEntry(plan, package);
        }).whereType<MapEntry<BillingPlan, rc.Package>>(),
      );
    _billingAvailable = _packagesByPlan.isNotEmpty;
    _unavailableReason = _billingAvailable
        ? null
        : 'Personal Premium is not available from the store yet.';
    notifyListeners();
  }

  /// The listener only fires on changes, so the store that sold the plan
  /// (for "Manage subscription") is also read from every fetched result.
  void _noteManagementUrl(rc.CustomerInfo customerInfo) {
    final url = customerInfo.managementURL;
    if (url != null && url.isNotEmpty) {
      _storeManagementUrl = url;
    }
  }

  Future<PurchaseResult> _applyCustomerInfo(
    rc.CustomerInfo customerInfo, {
    required BillingPlan plan,
    bool purchased = false,
    bool waitForServerMirror = false,
  }) async {
    _noteManagementUrl(customerInfo);
    final entitlement = _activeEntitlement(customerInfo);
    if (entitlement == null) {
      final preserved = await _preserveActiveStoreEntitlementWhenMissing(
        'purchase result',
      );
      if (!preserved && _hasVerifiedPaidRevenueCatEntitlement()) {
        await _ref.read(entitlementStoreProvider).applyExpiredEntitlement();
      }
      throw StateError(
        'No active Personal Premium purchase was found on this store account.',
      );
    }
    await _applyVerifiedEntitlement(
      entitlement,
      waitForServerMirror: waitForServerMirror,
    );
    return PurchaseResult(
      tier: UserTier.personalPremium,
      plan: plan,
      requiresSignIn: false,
      message: purchased
          ? 'Welcome to Personal Premium.'
          : 'Personal Premium restored.',
    );
  }

  Future<bool> _applyVerifiedEntitlement(
    rc.EntitlementInfo entitlement, {
    bool waitForServerMirror = false,
  }) async {
    final entitlementStore = _ref.read(entitlementStoreProvider);
    final previousEntitlementError = _ref
        .read(subscriptionAccountControllerProvider)
        .entitlementError;
    await entitlementStore.applyRevenueCatEntitlement(
      UserTier.personalPremium,
      periodEndsAt: _expirationDate(entitlement),
      willRenew: entitlement.willRenew,
      billingIssueAt: DateTime.tryParse(
        entitlement.billingIssueDetectedAt ?? '',
      ),
    );
    final mirrored = await _refreshServerMirror(
      waitForServerMirror: waitForServerMirror,
    );
    if (!mirrored &&
        !waitForServerMirror &&
        _looksBackupVerificationError(previousEntitlementError)) {
      await entitlementStore.recordEntitlementError(previousEntitlementError!);
    }
    return mirrored;
  }

  Future<bool> _refreshServerMirror({required bool waitForServerMirror}) async {
    final entitlementStore = _ref.read(entitlementStoreProvider);
    if (_currentUserId == null) {
      return false;
    }
    debugPrint('[PremiumEntitlement] Server mirror refresh requested.');
    if (!waitForServerMirror) {
      try {
        final refreshed = await entitlementStore
            .refreshServerVerifiedEntitlement();
        debugPrint(
          '[PremiumEntitlement] Server mirror refresh completed: '
          'refreshed=$refreshed.',
        );
        return refreshed;
      } catch (error) {
        debugPrint('RevenueCat entitlement mirror refresh failed: $error');
        return false;
      }
    }

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    Object? lastError;
    var requestedReconciliation = false;
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await entitlementStore.refreshServerVerifiedEntitlement(
          requestServerReconciliation: !requestedReconciliation,
        )) {
          debugPrint('[PremiumEntitlement] Server mirror refresh completed.');
          return true;
        }
        requestedReconciliation = true;
      } catch (error) {
        requestedReconciliation = true;
        lastError = error;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (lastError != null) {
      debugPrint('RevenueCat entitlement mirror refresh failed: $lastError');
    }
    await entitlementStore.recordEntitlementError(
      _backupVerificationFailedMessage,
    );
    debugPrint(
      '[PremiumEntitlement] Server mirror refresh timed out after bounded wait.',
    );
    return false;
  }

  rc.EntitlementInfo? _activeEntitlement(rc.CustomerInfo customerInfo) {
    final entitlementId = _ref
        .read(revenueCatRuntimeConfigProvider)
        .entitlementId;
    return revenueCatActiveEntitlement(customerInfo, entitlementId);
  }

  DateTime? _expirationDate(rc.EntitlementInfo entitlement) {
    return DateTime.tryParse(entitlement.expirationDate ?? '');
  }

  bool _hasVerifiedPaidRevenueCatEntitlement() {
    final account = _ref.read(subscriptionAccountControllerProvider);
    return account.entitlementSource == EntitlementSource.revenueCat &&
        account.entitlementTier != UserTier.personalFree;
  }

  Future<bool> _preserveActiveStoreEntitlementWhenMissing(
    String context,
  ) async {
    final account = _ref.read(subscriptionAccountControllerProvider);
    if (!hasActiveStoreEntitlement(account)) {
      return false;
    }
    const message = EntitlementFlowMessages.awaitingServerVerification;
    debugPrint(
      '[PremiumEntitlement] No active RevenueCat entitlement during $context; '
      'preserving active local store entitlement.',
    );
    await _ref.read(entitlementStoreProvider).recordEntitlementError(message);
    return true;
  }

  Future<String?> _safeRevenueCatAppUserId() async {
    try {
      return await rc.Purchases.appUserID;
    } catch (_) {
      return null;
    }
  }

  void _logReconciliationDebug({
    required String? supabaseAuthUid,
    required String? appUserIdBeforeLogin,
    required String? appUserIdAfterLogin,
    required bool localEntitlementActive,
    required bool serverReconciliationCalled,
    required String serverReconciliationStatus,
  }) {
    debugPrint(
      '[PremiumEntitlementDebug] '
      'supabase_auth_uid=${supabaseAuthUid ?? 'none'} '
      'revenuecat_app_user_id_before_login=${appUserIdBeforeLogin ?? 'unknown'} '
      'revenuecat_app_user_id_after_login=${appUserIdAfterLogin ?? 'unknown'} '
      'revenuecat_entitlement_active_local=$localEntitlementActive '
      'server_reconciliation_called=$serverReconciliationCalled '
      'server_reconciliation_status=$serverReconciliationStatus',
    );
  }

  bool _looksBackupVerificationError(String? message) =>
      EntitlementFlowMessages.looksPurchaseVerificationFailed(message);

  String? get _currentUserId {
    final authUserId = _ref.read(authSessionProvider).userId;
    final supabaseUserId = _ref
        .read(supabaseClientProvider)
        ?.auth
        .currentUser
        ?.id;
    final userId = authUserId ?? supabaseUserId;
    return userId == null || userId.isEmpty ? null : userId;
  }
}

/// RevenueCat's managementURL points at the store the subscription was bought
/// from, so a Google Play purchase opened on an iPhone (or the reverse) still
/// lands on the right store. Without one, use this platform's store.
String? revenueCatManageSubscriptionsUrl({
  required String? managementUrl,
  required TargetPlatform platform,
}) {
  if (managementUrl != null && managementUrl.isNotEmpty) {
    return managementUrl;
  }
  switch (platform) {
    case TargetPlatform.android:
      return 'https://play.google.com/store/account/subscriptions';
    case TargetPlatform.iOS:
      return 'https://apps.apple.com/account/subscriptions';
    default:
      return null;
  }
}

/// Whether a background sync may call `restorePurchases()` on its own.
///
/// On iOS a restore can raise the Apple ID sign-in sheet, which must only
/// follow an explicit tap (the Restore buttons). StoreKit transactions are
/// observed by RevenueCat automatically, so `getCustomerInfo()` after
/// `logIn()` already reflects them. Android keeps its silent restore, which
/// reattaches Play purchases made before sign-in.
@visibleForTesting
bool revenueCatAllowsSilentRestore(TargetPlatform platform) =>
    platform == TargetPlatform.android;

@visibleForTesting
String revenueCatMessageForPurchasesError(rc.PurchasesErrorCode code) {
  switch (code) {
    case rc.PurchasesErrorCode.paymentPendingError:
      return "Your payment is pending. Premium turns on when the store confirms it, so you don't need to buy again.";
    case rc.PurchasesErrorCode.productAlreadyPurchasedError:
      return 'Premium is already active on this store account.';
    case rc.PurchasesErrorCode.networkError:
    case rc.PurchasesErrorCode.offlineConnectionError:
      return 'Could not reach the store. Check your connection and try again.';
    case rc.PurchasesErrorCode.productNotAvailableForPurchaseError:
      return 'This Premium plan is not available from the store yet.';
    case rc.PurchasesErrorCode.purchaseNotAllowedError:
    case rc.PurchasesErrorCode.insufficientPermissionsError:
      return 'Purchases are not allowed on this store account.';
    case rc.PurchasesErrorCode.configurationError:
    case rc.PurchasesErrorCode.invalidCredentialsError:
      return "Premium isn't set up correctly yet. Try again later.";
    case rc.PurchasesErrorCode.operationAlreadyInProgressError:
      return 'A store request is already in progress.';
    case rc.PurchasesErrorCode.storeProblemError:
      return "The store couldn't finish that. Try again.";
    default:
      return "The store couldn't finish that. Try again.";
  }
}

PremiumProduct? revenueCatPremiumProductFromPackage(rc.Package package) {
  final plan = revenueCatBillingPlanForPackage(package);
  if (plan == null) return null;
  final product = package.storeProduct;
  final isYearly = plan == BillingPlan.yearly;
  return PremiumProduct(
    productId: product.identifier,
    basePlanId: isYearly ? PebbleBasePlanIds.yearly : PebbleBasePlanIds.monthly,
    plan: plan,
    title: isYearly ? 'Yearly' : 'Monthly',
    priceLabel: product.priceString,
    detailLabel: isYearly
        ? 'per year. Best value.'
        : 'per month. Cancel anytime.',
    badgeLabel: isYearly ? 'Best value' : null,
    offerToken: package.identifier,
    isPurchasable: true,
  );
}

rc.EntitlementInfo? revenueCatActiveEntitlement(
  rc.CustomerInfo customerInfo,
  String entitlementId,
) {
  return customerInfo.entitlements.active[entitlementId];
}

BillingPlan? revenueCatBillingPlanForPackage(rc.Package package) {
  switch (package.packageType) {
    case rc.PackageType.annual:
      return BillingPlan.yearly;
    case rc.PackageType.monthly:
      return BillingPlan.monthly;
    default:
      break;
  }
  final id = [
    package.identifier,
    package.storeProduct.identifier,
    package.storeProduct.subscriptionPeriod ?? '',
  ].join(' ').toLowerCase();
  if (id.contains('year') || id.contains('annual') || id.contains('p1y')) {
    return BillingPlan.yearly;
  }
  if (id.contains('month') || id.contains('monthly') || id.contains('p1m')) {
    return BillingPlan.monthly;
  }
  return null;
}
