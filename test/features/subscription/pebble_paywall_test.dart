import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

void main() {
  testWidgets('premium page renders the annual-first value screen', (
    tester,
  ) async {
    await _pumpPaywall(tester, entrySource: PremiumEntrySource.premiumTheme);

    expect(find.byType(PageView), findsNothing);
    expect(find.text('Pebble Premium'), findsOneWidget);
    expect(find.text('Make Pebble feel like yours'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('PEBBLE PREMIUM INCLUDES'));
    expect(find.text('PEBBLE PREMIUM INCLUDES'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Unlimited routines & steps'));
    expect(find.text('Unlimited routines & steps'), findsOneWidget);
    expect(
      find.text('Free: 2 routines / 10 steps -> Premium: unlimited'),
      findsOneWidget,
    );

    await _scrollUntilVisible(tester, find.text('Backup & longer history'));
    expect(find.text('Backup & longer history'), findsOneWidget);
    expect(find.text('Free: 48 hrs -> Premium: 21 days'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Voice tips on steps'));
    expect(find.text('Voice tips on steps'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('More proof photos'));
    expect(find.text('More proof photos'), findsOneWidget);
    expect(find.text('Free: 1 photo -> Premium: 4 per step'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Shared reminders'));
    expect(find.text('Shared reminders'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Premium themes & style'));
    expect(find.text('Premium themes & style'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('MONTHLY'));
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.text('\$0.99'), findsWidgets);
    expect(find.text('\$6.99'), findsWidgets);

    expect(find.text('Start yearly - \$6.99'), findsOneWidget);
    expect(find.textContaining('7-day free trial'), findsNothing);

    expect(
      find.text('Restore purchase \u00B7 I already have Premium'),
      findsOneWidget,
    );
    expect(find.textContaining('camera roll is never scanned'), findsWidgets);
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

    expect(find.text('Start monthly - \$0.99'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNotNull);
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

    expect(find.text('Start yearly - \$6.99'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNotNull);
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

    expect(find.text('Start yearly - \$6.99'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNotNull);
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
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNull);
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
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNull);
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
}

class _PlanPurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  _PlanPurchaseRepository(this._products);

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

  factory _PlanPurchaseRepository.both() {
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
    ]);
  }

  factory _PlanPurchaseRepository.monthlyMissingOfferToken() {
    return _PlanPurchaseRepository([
      _premiumProduct(plan: BillingPlan.monthly, price: '\$0.99'),
    ]);
  }

  final List<PremiumProduct> _products;

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
      message: 'Personal Premium restored from Google Play.',
    );
  }
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
