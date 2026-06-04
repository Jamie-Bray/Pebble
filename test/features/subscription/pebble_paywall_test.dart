import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

void main() {
  testWidgets('premium page renders the annual-first value screen', (
    tester,
  ) async {
    await _pumpPaywall(
      tester,
      entrySource: PremiumEntrySource.premiumTheme,
      overrides: [
        purchaseRepositoryProvider.overrideWith(
          (ref) => _PlanPurchaseRepository.both(),
        ),
      ],
    );

    expect(find.byType(PageView), findsNothing);
    expect(find.text('Pebble Premium'), findsOneWidget);
    expect(find.text('Build more.\nWorry less.'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('WHAT PREMIUM GIVES YOU'));
    expect(find.text('WHAT PREMIUM GIVES YOU'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.text('Unlimited routines and steps'),
    );
    expect(find.text('Unlimited routines and steps'), findsOneWidget);
    expect(find.text('2 routines, 10 steps'), findsOneWidget);
    expect(find.text('Unlimited'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Longer history and backup'));
    expect(find.text('Longer history and backup'), findsOneWidget);
    expect(find.text('48 hours'), findsOneWidget);
    expect(find.text('21 days + backup'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('More photos per step'));
    expect(find.text('More photos per step'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
    expect(find.text('Up to 4'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Voice tips'));
    expect(find.text('Voice tips'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('Included'), findsOneWidget);

    expect(find.text('Private by default'), findsOneWidget);

    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text('\$0.99'), findsWidgets);
    expect(find.text('\$6.99'), findsWidgets);

    expect(find.text('Continue with \$6.99/year'), findsOneWidget);
    expect(find.textContaining('7-day free trial'), findsNothing);

    expect(find.text('Restore purchase'), findsOneWidget);
    expect(find.text('|'), findsNWidgets(2));
    expect(find.text('\u00c2\u00b7'), findsNothing);
    expect(
      find.textContaining('Cancel anytime in Google Play'),
      findsOneWidget,
    );
  });

  testWidgets('premium CTA shows the monthly Google Play plan', (tester) async {
    await _pumpPaywall(
      tester,
      overrides: [
        purchaseRepositoryProvider.overrideWith(
          (ref) => _PlanPurchaseRepository.monthly(),
        ),
      ],
    );

    expect(find.text('Continue with \$0.99/month'), findsOneWidget);
  });

  testWidgets('premium CTA shows the yearly Google Play plan', (tester) async {
    await _pumpPaywall(
      tester,
      overrides: [
        purchaseRepositoryProvider.overrideWith(
          (ref) => _PlanPurchaseRepository.yearly(),
        ),
      ],
    );

    expect(find.text('Continue with \$6.99/year'), findsOneWidget);
  });

  testWidgets('premium defaults to yearly when both base plans are available', (
    tester,
  ) async {
    await _pumpPaywall(
      tester,
      overrides: [
        purchaseRepositoryProvider.overrideWith(
          (ref) => _PlanPurchaseRepository.both(),
        ),
      ],
    );

    expect(find.text('Continue with \$6.99/year'), findsOneWidget);
  });

  testWidgets('premium CTA disables when selected plan has no offer token', (
    tester,
  ) async {
    await _pumpPaywall(
      tester,
      overrides: [
        purchaseRepositoryProvider.overrideWith(
          (ref) => _PlanPurchaseRepository.monthlyMissingOfferToken(),
        ),
      ],
    );

    await _scrollUntilVisible(
      tester,
      find.textContaining('monthly base plan offer token'),
    );

    expect(
      find.textContaining('monthly base plan offer token'),
      findsOneWidget,
    );
    expect(find.text('Continue with \$0.99/month'), findsOneWidget);
  });

  testWidgets('premium CTA disables when store products are unavailable', (
    tester,
  ) async {
    await _pumpPaywall(
      tester,
      overrides: [
        purchaseRepositoryProvider.overrideWith(
          (ref) => _UnavailablePurchaseRepository(),
        ),
      ],
    );

    await _scrollUntilVisible(tester, find.text('Store is not ready yet.'));

    expect(find.text('Store is not ready yet.'), findsOneWidget);
    expect(find.text('Loading store price'), findsOneWidget);
  });

  testWidgets('purchase cancellation quietly returns to the paywall', (
    tester,
  ) async {
    await _pumpPaywall(
      tester,
      overrides: [
        authSessionProvider.overrideWithValue(
          const AuthSessionSummary(
            isSignedIn: true,
            userId: '11111111-1111-1111-1111-111111111111',
            email: 'jamie@example.com',
            provider: 'google',
          ),
        ),
        purchaseRepositoryProvider.overrideWith(
          (ref) => _PlanPurchaseRepository.both(cancelPurchase: true),
        ),
      ],
    );

    final startButton = find.text('Continue with \$6.99/year');
    await _scrollUntilVisible(tester, startButton);
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Pebble Premium'), findsOneWidget);
  });

  testWidgets('purchase success while signed out explains local Premium', (
    tester,
  ) async {
    await _pumpPaywall(
      tester,
      overrides: [
        authSessionProvider.overrideWithValue(
          const AuthSessionSummary(
            isSignedIn: false,
            userId: null,
            email: null,
            provider: null,
          ),
        ),
        purchaseRepositoryProvider.overrideWith(
          (ref) => _PlanPurchaseRepository.both(),
        ),
      ],
    );

    final startButton = find.text('Continue with \$6.99/year');
    await _scrollUntilVisible(tester, startButton);
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Premium activated'), findsOneWidget);
    expect(find.textContaining('One last thing'), findsOneWidget);
    expect(
      find.text(
        'Sign in to back up your history, routines, and photos, and keep them ready across devices. Totally optional; Premium works right now without it.',
      ),
      findsOneWidget,
    );
    expect(find.text('21 days'), findsOneWidget);
    expect(find.text('21d'), findsNothing);
    expect(find.text('21D'), findsNothing);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('Recovery'), findsOneWidget);
    expect(find.text('Sign in to back up'), findsOneWidget);
    expect(find.text('Continue without sign-in'), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
  });

  testWidgets('premium page dynamically displays App Store references on iOS', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pumpPaywall(
        tester,
        overrides: [
          purchaseRepositoryProvider.overrideWith(
            (ref) => _PlanPurchaseRepository.monthlyMissingOfferToken(),
          ),
        ],
      );

      await _scrollUntilVisible(
        tester,
        find.textContaining('monthly base plan offer token'),
      );

      expect(
        find.textContaining('not available from App Store yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('offer token in App Store Connect'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _pumpPaywall(
  WidgetTester tester, {
  PremiumEntrySource entrySource = PremiumEntrySource.general,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.fromId(ThemeId.nordicNight),
        home: PebblePaywall(entrySource: entrySource),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

class _UnavailablePurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  @override
  bool get isPurchaseAvailable => false;

  @override
  bool get billingAvailable => false;

  @override
  DateTime? get lastPurchaseCheckAt => null;

  @override
  Set<String> get loadedProductIds => const <String>{};

  @override
  String? get manageSubscriptionsUrl => null;

  @override
  List<PremiumProduct> get personalPremiumProducts =>
      getPlaceholderPremiumCatalog(isPurchasable: false);

  @override
  String? get unavailableReason => 'Store is not ready yet.';

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) {
    throw StateError('Store is not ready yet.');
  }

  @override
  Future<PurchaseResult> restorePurchases() {
    throw StateError('Store is not ready yet.');
  }

  @override
  Future<void> syncPurchasesSilently({
    bool waitForServerMirror = false,
  }) async {}

  @override
  Future<void> logOut() async {}
}

class _PlanPurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  _PlanPurchaseRepository(this._products, {this.cancelPurchase = false});

  factory _PlanPurchaseRepository.monthly() {
    return _PlanPurchaseRepository([
      _premiumProduct(
        plan: BillingPlan.monthly,
        price: '\$0.99',
        offerToken: 'monthly-token',
      ),
    ]);
  }

  factory _PlanPurchaseRepository.yearly() {
    return _PlanPurchaseRepository([
      _premiumProduct(
        plan: BillingPlan.yearly,
        price: '\$6.99',
        offerToken: 'yearly-token',
      ),
    ]);
  }

  factory _PlanPurchaseRepository.both({bool cancelPurchase = false}) {
    return _PlanPurchaseRepository([
      _premiumProduct(
        plan: BillingPlan.yearly,
        price: '\$6.99',
        offerToken: 'yearly-token',
      ),
      _premiumProduct(
        plan: BillingPlan.monthly,
        price: '\$0.99',
        offerToken: 'monthly-token',
      ),
    ], cancelPurchase: cancelPurchase);
  }

  factory _PlanPurchaseRepository.monthlyMissingOfferToken() {
    return _PlanPurchaseRepository([
      _premiumProduct(plan: BillingPlan.monthly, price: '\$0.99'),
    ]);
  }

  final List<PremiumProduct> _products;
  final bool cancelPurchase;

  @override
  bool get isPurchaseAvailable =>
      _products.any((product) => product.hasValidOfferToken);

  @override
  bool get billingAvailable => true;

  @override
  DateTime? get lastPurchaseCheckAt => DateTime.utc(2026, 5, 18);

  @override
  Set<String> get loadedProductIds => {PebbleProductIds.personalPremium};

  @override
  String? get manageSubscriptionsUrl =>
      'https://play.google.com/store/account/subscriptions';

  @override
  List<PremiumProduct> get personalPremiumProducts => _products;

  @override
  String? get unavailableReason => null;

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    if (cancelPurchase) {
      throw const PurchaseCancelledException();
    }
    return const PurchaseResult(
      tier: UserTier.personalPremium,
      plan: BillingPlan.monthly,
      requiresSignIn: false,
      message: 'Welcome to Personal Premium.',
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return const PurchaseResult(
      tier: UserTier.personalPremium,
      plan: BillingPlan.monthly,
      requiresSignIn: false,
      message: 'Pebble Premium restored from RevenueCat.',
    );
  }

  @override
  Future<void> syncPurchasesSilently({
    bool waitForServerMirror = false,
  }) async {}

  @override
  Future<void> logOut() async {}
}

PremiumProduct _premiumProduct({
  required BillingPlan plan,
  required String price,
  String? offerToken,
}) {
  final isYearly = plan == BillingPlan.yearly;
  return PremiumProduct(
    productId: PebbleProductIds.personalPremium,
    basePlanId: isYearly ? PebbleBasePlanIds.yearly : PebbleBasePlanIds.monthly,
    plan: plan,
    title: isYearly ? 'Yearly' : 'Monthly',
    priceLabel: price,
    detailLabel: isYearly
        ? 'per year. Best value.'
        : 'per month. Cancel anytime.',
    offerToken: offerToken,
    isPurchasable: true,
  );
}
