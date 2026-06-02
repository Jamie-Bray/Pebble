import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/data/auth_repository.dart';
import 'package:pebble_routines/features/auth/ui/sign_in_screen.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Google sign-in finishes when Premium server verification is still pending',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final database = LocalDb.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final router = GoRouter(
        initialLocation: '/sign-in',
        routes: [
          GoRoute(
            path: '/sign-in',
            builder: (context, state) => const SignInScreen(),
          ),
          GoRoute(
            path: '/account-hub',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Account hub reached')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDbProvider.overrideWithValue(database),
            sharedPreferencesProvider.overrideWithValue(prefs),
            supabaseRuntimeConfigProvider.overrideWithValue(
              const SupabaseRuntimeConfig(
                enabled: false,
                url: '',
                anonKey: '',
                googleWebClientId: 'test-web-client-id',
              ),
            ),
            supabaseClientProvider.overrideWithValue(null),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            purchaseRepositoryProvider.overrideWith(
              (ref) => _FakePurchaseRepository(),
            ),
            subscriptionAccountControllerProvider.overrideWith(
              (ref) => _TestSubscriptionAccountController(
                database,
                const SubscriptionAccountState(
                  entitlementTier: UserTier.personalPremium,
                  pendingTier: null,
                  bootstrapStatus: BootstrapStatus.idle,
                  userId: null,
                  email: null,
                  authProvider: null,
                  lastBootstrapAt: null,
                  lastSyncAt: null,
                  lastSyncError: null,
                  entitlementStatus: EntitlementStatus.personalPremium,
                  entitlementSource: EntitlementSource.revenueCat,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Account hub reached'), findsOneWidget);
      expect(find.text('Preparing your backup...'), findsNothing);
    },
  );

  testWidgets('email code sheet gives delayed-email recovery actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = LocalDb.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final router = GoRouter(
      initialLocation: '/sign-in',
      routes: [
        GoRoute(
          path: '/sign-in',
          builder: (context, state) => const SignInScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDbProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseRuntimeConfigProvider.overrideWithValue(
            const SupabaseRuntimeConfig.disabled(),
          ),
          supabaseClientProvider.overrideWithValue(null),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          purchaseRepositoryProvider.overrideWith(
            (ref) => _FakePurchaseRepository(),
          ),
          subscriptionAccountControllerProvider.overrideWith(
            (ref) => _TestSubscriptionAccountController(
              database,
              const SubscriptionAccountState.initial(),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use email instead'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Email address'),
      'jamie@example.com',
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Check spam or junk'), findsOneWidget);
    expect(find.text('Use a different email'), findsOneWidget);

    await tester.tap(find.text('Use a different email'));
    await tester.pumpAndSettle();

    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('One-time code'), findsNothing);
  });
}

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(
    super.db,
    SubscriptionAccountState initialState,
  ) : super(loadOnInit: false) {
    state = initialState;
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  bool get isConfigured => true;

  @override
  Future<AuthIdentity?> currentIdentity() async => null;

  @override
  Future<void> requestEmailOtp(String email) async {}

  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    return AuthIdentity(userId: 'user-id', email: email, provider: 'emailOtp');
  }

  @override
  Future<AuthIdentity> signInWithGoogle() async {
    return const AuthIdentity(
      userId: '11111111-1111-1111-1111-111111111111',
      email: 'jamie@example.com',
      provider: 'google',
    );
  }

  @override
  Future<AuthIdentity> signInWithApple() async {
    return const AuthIdentity(
      userId: '11111111-1111-1111-1111-111111111111',
      email: 'jamie@example.com',
      provider: 'apple',
    );
  }

  @override
  Future<void> upsertProfile({required AuthIdentity identity}) async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> signOut() async {}
}

class _FakePurchaseRepository extends ChangeNotifier
    implements PurchaseRepository {
  @override
  bool get billingAvailable => true;

  @override
  bool get isPurchaseAvailable => true;

  @override
  DateTime? get lastPurchaseCheckAt => DateTime.utc(2026, 5, 31);

  @override
  Set<String> get loadedProductIds => {PebbleProductIds.personalPremium};

  @override
  String? get manageSubscriptionsUrl =>
      'https://play.google.com/store/account/subscriptions';

  @override
  List<PremiumProduct> get personalPremiumProducts =>
      getPlaceholderPremiumCatalog(isPurchasable: true);

  @override
  String? get unavailableReason => null;

  @override
  Future<void> logOut() async {}

  @override
  Future<PurchaseResult> purchasePersonalPremium(BillingPlan plan) async {
    return PurchaseResult(
      tier: UserTier.personalPremium,
      plan: plan,
      requiresSignIn: false,
      message: 'Purchased',
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return const PurchaseResult(
      tier: UserTier.personalPremium,
      plan: BillingPlan.monthly,
      requiresSignIn: false,
      message: 'Restored',
    );
  }

  @override
  Future<void> syncPurchasesSilently() async {}
}
