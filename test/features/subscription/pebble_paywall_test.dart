import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';

void main() {
  testWidgets('premium page renders the feature cinema journey', (
    tester,
  ) async {
    await _pumpPaywall(tester, entrySource: PremiumEntrySource.premiumTheme);

    expect(find.byType(PageView), findsNothing);
    expect(find.text('Personal Premium'), findsOneWidget);
    expect(find.text('UNLOCK EVERYTHING'), findsOneWidget);
    expect(find.text('More of\nPebble.'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('WHAT YOU GET'));
    expect(find.text('WHAT YOU GET'), findsOneWidget);
    expect(find.text('Proof photo backup'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Unlimited routines & steps'));
    expect(find.text('Unlimited routines & steps'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Shared reminders'));
    expect(find.text('Shared reminders'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Premium themes & style'));
    expect(find.text('Premium themes & style'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('MONTHLY'));
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.text('99p'), findsWidgets);

    expect(find.textContaining('Start Premium'), findsOneWidget);
    expect(find.textContaining('7-day free trial'), findsNothing);

    expect(
      find.text('Restore purchase \u00B7 I already have Premium'),
      findsOneWidget,
    );
    expect(find.textContaining('camera roll is never scanned'), findsWidgets);
  });

  testWidgets('premium CTA shows the monthly Google Play plan', (tester) async {
    await _pumpPaywall(tester);

    expect(find.textContaining('Start Premium'), findsOneWidget);
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
