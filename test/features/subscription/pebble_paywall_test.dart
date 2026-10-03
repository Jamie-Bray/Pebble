import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
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
    expect(find.text('Personal Premium'), findsOneWidget);
    expect(find.text('Never wonder\ntwice.'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('WHAT PREMIUM GIVES YOU'));
    expect(find.text('WHAT PREMIUM GIVES YOU'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.text('Unlimited routines and steps'),
    );
    expect(find.text('Unlimited routines and steps'), findsOneWidget);
    expect(
      find.textContaining('2 routines, 10 steps', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Unlimited', findRichText: true), findsWidgets);

    await _scrollUntilVisible(tester, find.text('Longer history and backup'));
    expect(find.text('Longer history and backup'), findsOneWidget);
    expect(find.textContaining('48 hours', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('21 days + backup', findRichText: true),
      findsOneWidget,
    );

    await _scrollUntilVisible(tester, find.text('More photos per step'));
    expect(find.text('More photos per step'), findsOneWidget);
    expect(find.textContaining('1 photo', findRichText: true), findsOneWidget);
    expect(find.textContaining('Up to 4', findRichText: true), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Voice tips'));
    expect(find.text('Voice tips'), findsOneWidget);
    expect(
      find.textContaining('Not available', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Included', findRichText: true), findsOneWidget);

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

    final notice = find.textContaining(
      'The monthly plan is not available from Google Play right now.',
    );
    await _scrollUntilVisible(tester, notice);

    expect(notice, findsOneWidget);
    expect(find.textContaining('offer token'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
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

    expect(find.text('Prices unavailable'), findsOneWidget);
    expect(find.text('Store is not ready yet.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Continue with'), findsNothing);
    expect(find.text('Loading'), findsNothing);
    // Restore, Terms and Privacy stay reachable even without prices.
    expect(find.text('Restore purchase'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('Try again re-requests store products and shows the plans', (
    tester,
  ) async {
    final repository = _UnavailablePurchaseRepository(recoverOnRetry: true);
    await _pumpPaywall(
      tester,
      overrides: [purchaseRepositoryProvider.overrideWith((ref) => repository)],
    );

    final retry = find.text('Try again');
    await _scrollUntilVisible(tester, retry);
    await tester.tap(retry);
    await tester.pump();
    expect(repository.retryCount, 1);
    expect(find.text('Checking the store...'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Prices unavailable'), findsNothing);
    expect(find.text('Continue with \$6.99/year'), findsOneWidget);
  });

  testWidgets('a store that never answers turns into Try again', (
    tester,
  ) async {
    final repository = _UnavailablePurchaseRepository(loading: true);
    await _pumpPaywall(
      tester,
      settle: false,
      overrides: [purchaseRepositoryProvider.overrideWith((ref) => repository)],
    );
    await tester.pump();
    expect(find.text('Checking the store...'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    await tester.pump(const Duration(seconds: 13));
    expect(find.text('Prices unavailable'), findsOneWidget);
    expect(find.textContaining('taking longer than usual'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  for (final size in const [Size(390, 844), Size(360, 640)]) {
    testWidgets(
      'paywall at 2x text keeps the CTA, price and legal links visible '
      '(${size.width.toInt()}x${size.height.toInt()})',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await _pumpPaywall(
            tester,
            entrySource: PremiumEntrySource.routineLimit,
            overrides: [
              purchaseRepositoryProvider.overrideWith(
                (ref) => _PlanPurchaseRepository.both(),
              ),
            ],
          );
          expect(tester.takeException(), isNull);

          final cta = find.text('Continue with \$6.99/year');
          await _scrollUntilVisible(tester, cta);
          expect(tester.takeException(), isNull);
          final ctaRect = tester.getRect(cta);
          expect(ctaRect.top, greaterThanOrEqualTo(0));
          expect(ctaRect.bottom, lessThanOrEqualTo(size.height));
          // The label is not clipped by a fixed-height button.
          final button = find.ancestor(
            of: cta,
            matching: find.byType(FilledButton),
          );
          expect(
            tester.getRect(button.first).bottom,
            greaterThanOrEqualTo(ctaRect.bottom),
          );

          // Price, plan length and renewal terms sit with the button.
          expect(find.text('\$6.99'), findsWidgets);
          expect(
            find.textContaining('Personal Premium Annual: \$6.99 per year.'),
            findsOneWidget,
          );
          expect(find.textContaining('Renews automatically'), findsOneWidget);
          final restore = find.text('Restore purchase');
          await _scrollUntilVisible(tester, restore);
          expect(find.text('Terms of Use'), findsOneWidget);
          expect(find.text('Privacy Policy'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

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
    expect(find.text('Personal Premium'), findsOneWidget);
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
    expect(find.textContaining('Optional: sign in'), findsOneWidget);
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

  testWidgets('purchase success while signed in offers one-tap backup', (
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
        cloudBackupConsentStateProvider.overrideWithValue(
          const CloudBackupConsentState(
            isLoading: false,
            record: null,
            lastError: null,
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
    expect(find.text('Turn on backup'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(
      find.textContaining('proof photos, which can include personal details'),
      findsOneWidget,
    );
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

      final notice = find.textContaining(
        'not available from the App Store right now',
      );
      await _scrollUntilVisible(tester, notice);

      expect(notice, findsOneWidget);
      expect(find.textContaining('App Store Connect'), findsNothing);
      expect(
        find.textContaining('Cancel anytime in the App Store'),
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
  bool settle = true,
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
  if (settle) await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

class _UnavailablePurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  _UnavailablePurchaseRepository({
    this.loading = false,
    this.recoverOnRetry = false,
  });

  bool loading;
  final bool recoverOnRetry;
  int retryCount = 0;
  bool _recovered = false;

  @override
  bool get isLoadingProducts => loading;

  @override
  Future<void> retryLoadProducts() async {
    retryCount += 1;
    loading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    loading = false;
    _recovered = recoverOnRetry;
    notifyListeners();
  }

  @override
  bool get isPurchaseAvailable => _recovered;

  @override
  bool get billingAvailable => _recovered;

  @override
  DateTime? get lastPurchaseCheckAt => null;

  @override
  Set<String> get loadedProductIds => const <String>{};

  @override
  String? get manageSubscriptionsUrl => null;

  @override
  List<PremiumProduct> get personalPremiumProducts => _recovered
      ? [
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
        ]
      : getPlaceholderPremiumCatalog(isPurchasable: false);

  @override
  String? get unavailableReason => _recovered
      ? null
      : loading
      ? 'Loading store products...'
      : 'Store is not ready yet.';

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

  @override
  bool get isLoadingProducts => false;

  @override
  Future<void> retryLoadProducts() async {}
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
      message: 'Personal Premium restored from RevenueCat.',
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
