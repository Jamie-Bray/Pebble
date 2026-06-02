import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/data/auth_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/purchase_repository.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

void main() {
  test('email OTP request reports failure without advancing state', () async {
    final container = await _container(
      _FakeAuthRepository(requestError: StateError('Email failed')),
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);

    final success = await controller.requestEmailOtp('jamie@example.com');

    expect(success, isFalse);
    expect(container.read(authControllerProvider).status, AuthStatus.authError);
    expect(
      container.read(authControllerProvider).errorMessage,
      contains('Email failed'),
    );
  });

  test('email OTP request reports success before code entry', () async {
    final container = await _container(_FakeAuthRepository());
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);

    final success = await controller.requestEmailOtp('jamie@example.com');

    expect(success, isTrue);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.pendingSignIn,
    );
  });

  test('email OTP verification reports failure without signing in', () async {
    final container = await _container(
      _FakeAuthRepository(verifyError: StateError('Bad code')),
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);

    final success = await controller.verifyEmailOtp(
      email: 'jamie@example.com',
      token: '12345678',
    );

    expect(success, isFalse);
    expect(container.read(authControllerProvider).status, AuthStatus.authError);
    expect(
      container.read(authControllerProvider).errorMessage,
      contains('Bad code'),
    );
  });

  test(
    'account deletion clears store identity and refreshes purchases',
    () async {
      final purchases = _FakePurchaseRepository();
      final container = await _container(
        _FakeAuthRepository(),
        purchaseRepository: purchases,
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);

      await controller.deleteAccount();

      expect(purchases.logOutCalled, isTrue);
      expect(purchases.syncCalled, isTrue);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    },
  );
}

Future<ProviderContainer> _container(
  AuthRepository repository, {
  PurchaseRepository? purchaseRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final database = LocalDb.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      localDbProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseRuntimeConfigProvider.overrideWithValue(
        const SupabaseRuntimeConfig.disabled(),
      ),
      supabaseClientProvider.overrideWithValue(null),
      authRepositoryProvider.overrideWithValue(repository),
      purchaseRepositoryProvider.overrideWith(
        (ref) => purchaseRepository ?? _FakePurchaseRepository(),
      ),
      subscriptionAccountControllerProvider.overrideWith(
        (ref) => _TestSubscriptionAccountController(database),
      ),
    ],
  );
  addTearDown(database.close);
  return container;
}

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(super.db) : super(loadOnInit: false) {
    state = const SubscriptionAccountState.initial();
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.requestError, this.verifyError});

  final Object? requestError;
  final Object? verifyError;

  @override
  bool get isConfigured => true;

  @override
  Future<AuthIdentity?> currentIdentity() async => null;

  @override
  Future<void> requestEmailOtp(String email) async {
    final error = requestError;
    if (error != null) throw error;
  }

  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final error = verifyError;
    if (error != null) throw error;
    return AuthIdentity(userId: 'user-id', email: email, provider: 'emailOtp');
  }

  @override
  Future<AuthIdentity> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<AuthIdentity> signInWithApple() {
    throw UnimplementedError();
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
  bool logOutCalled = false;
  bool syncCalled = false;

  @override
  bool get billingAvailable => false;

  @override
  bool get isPurchaseAvailable => false;

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
  String? get unavailableReason => null;

  @override
  Future<void> logOut() async {
    logOutCalled = true;
  }

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
  Future<void> syncPurchasesSilently() async {
    syncCalled = true;
  }
}
