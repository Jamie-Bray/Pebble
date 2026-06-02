import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/revenuecat_purchase_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

void main() {
  group('RevenueCat purchase mapping', () {
    test('maps monthly and yearly packages to Pebble premium products', () {
      final monthly = _package(
        identifier: r'$rc_monthly',
        packageType: rc.PackageType.monthly,
        productIdentifier: 'personal_premium:monthly',
        price: '\$0.99',
      );
      final yearly = _package(
        identifier: r'$rc_annual',
        packageType: rc.PackageType.annual,
        productIdentifier: 'personal_premium:yearly',
        price: '\$6.99',
      );

      final monthlyProduct = revenueCatPremiumProductFromPackage(monthly);
      final yearlyProduct = revenueCatPremiumProductFromPackage(yearly);

      expect(monthlyProduct?.plan, BillingPlan.monthly);
      expect(monthlyProduct?.basePlanId, PebbleBasePlanIds.monthly);
      expect(monthlyProduct?.priceLabel, '\$0.99');
      expect(monthlyProduct?.hasValidOfferToken, isTrue);

      expect(yearlyProduct?.plan, BillingPlan.yearly);
      expect(yearlyProduct?.basePlanId, PebbleBasePlanIds.yearly);
      expect(yearlyProduct?.priceLabel, '\$6.99');
      expect(yearlyProduct?.badgeLabel, 'Best value');
    });

    test('falls back to Google base-plan suffixes for custom packages', () {
      final package = _package(
        identifier: 'premium_custom',
        packageType: rc.PackageType.custom,
        productIdentifier: 'personal_premium:yearly',
        price: '\$6.99',
      );

      expect(revenueCatBillingPlanForPackage(package), BillingPlan.yearly);
    });

    test('reads active personal premium entitlement from CustomerInfo', () {
      final customerInfo = _customerInfo(
        activeEntitlementIds: const ['personal_premium'],
      );

      expect(
        revenueCatActiveEntitlement(customerInfo, 'personal_premium')?.isActive,
        isTrue,
      );
      expect(revenueCatActiveEntitlement(customerInfo, 'other'), isNull);
    });

    test('maps purchase errors to friendly user-facing copy', () {
      expect(
        revenueCatMessageForPurchasesError(
          rc.PurchasesErrorCode.productAlreadyPurchasedError,
        ),
        'Premium is already active on this store account.',
      );
      expect(
        revenueCatMessageForPurchasesError(
          rc.PurchasesErrorCode.paymentPendingError,
        ),
        contains('pending'),
      );
      expect(
        revenueCatMessageForPurchasesError(rc.PurchasesErrorCode.networkError),
        contains('connection'),
      );
      expect(
        revenueCatMessageForPurchasesError(
          rc.PurchasesErrorCode.configurationError,
        ),
        contains('not configured'),
      );
    });
  });
}

rc.Package _package({
  required String identifier,
  required rc.PackageType packageType,
  required String productIdentifier,
  required String price,
}) {
  return rc.Package(
    identifier,
    packageType,
    rc.StoreProduct(
      productIdentifier,
      'Pebble Premium',
      'Pebble Premium',
      0.99,
      price,
      'USD',
    ),
    const rc.PresentedOfferingContext('default', null, null),
  );
}

rc.CustomerInfo _customerInfo({required List<String> activeEntitlementIds}) {
  final active = <String, rc.EntitlementInfo>{
    for (final id in activeEntitlementIds)
      id: rc.EntitlementInfo(
        id,
        true,
        true,
        '2026-05-22T00:00:00Z',
        '2026-05-22T00:00:00Z',
        'personal_premium',
        false,
      ),
  };
  return rc.CustomerInfo(
    rc.EntitlementInfos(active, active),
    const {},
    const ['personal_premium'],
    const ['personal_premium'],
    const [],
    '2026-05-22T00:00:00Z',
    'user-id',
    const {},
    '2026-05-22T00:00:00Z',
  );
}
