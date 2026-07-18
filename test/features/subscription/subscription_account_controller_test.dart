import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

void main() {
  test('same account keeps a completed backup bootstrap', () async {
    final database = LocalDb.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bootstrappedAt = DateTime.utc(2026, 7, 15, 10);
    final syncedAt = DateTime.utc(2026, 7, 15, 11);
    final controller = _TestSubscriptionAccountController(
      database,
      _accountState(
        userId: 'account-a',
        bootstrappedAt: bootstrappedAt,
        syncedAt: syncedAt,
      ),
    );
    addTearDown(controller.dispose);

    await controller.cacheAuthenticatedIdentity(
      userId: 'account-a',
      email: 'new@example.com',
      authProvider: 'google',
    );

    expect(controller.state.bootstrapStatus, BootstrapStatus.ready);
    expect(controller.state.lastBootstrapAt, bootstrappedAt);
    expect(controller.state.lastSyncAt, syncedAt);
  });

  test('different account clears the previous backup bootstrap', () async {
    final database = LocalDb.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final controller = _TestSubscriptionAccountController(
      database,
      _accountState(
        userId: 'account-a',
        bootstrappedAt: DateTime.utc(2026, 7, 15, 10),
        syncedAt: DateTime.utc(2026, 7, 15, 11),
      ),
    );
    addTearDown(controller.dispose);

    await controller.cacheAuthenticatedIdentity(
      userId: 'account-b',
      email: 'b@example.com',
      authProvider: 'google',
    );

    expect(controller.state.userId, 'account-b');
    expect(controller.state.bootstrapStatus, BootstrapStatus.idle);
    expect(controller.state.lastBootstrapAt, isNull);
    expect(controller.state.lastSyncAt, isNull);
  });
}

SubscriptionAccountState _accountState({
  required String userId,
  required DateTime bootstrappedAt,
  required DateTime syncedAt,
}) {
  return SubscriptionAccountState(
    entitlementTier: UserTier.personalPremium,
    pendingTier: null,
    bootstrapStatus: BootstrapStatus.ready,
    userId: userId,
    email: '$userId@example.com',
    authProvider: 'google',
    lastBootstrapAt: bootstrappedAt,
    lastSyncAt: syncedAt,
    lastSyncError: null,
    entitlementStatus: EntitlementStatus.personalPremium,
    entitlementSource: EntitlementSource.serverVerified,
  );
}

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(
    super.db,
    SubscriptionAccountState initialState,
  ) : super(loadOnInit: false) {
    state = initialState;
  }
}
