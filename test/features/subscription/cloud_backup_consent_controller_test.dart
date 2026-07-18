import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const userId = '11111111-1111-1111-1111-111111111111';
  const auth = AuthSessionSummary(
    isSignedIn: true,
    userId: userId,
    email: 'jamie@example.com',
    provider: 'google',
  );

  test(
    'failed enable leaves an automatic retry pending and stops loading',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _FailingConsentStore(prefs);
      final controller = _TestConsentController(
        prefs: prefs,
        auth: auth,
        store: store,
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      await expectLater(controller.accept(), throwsStateError);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isAccepted, isFalse);
      expect(controller.state.lastError, contains('try again'));
      expect(store.isEnablePending(userId), isTrue);
    },
  );

  test('failed pause preserves the active consent state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = _FailingConsentStore(prefs);
    final controller = _TestConsentController(
      prefs: prefs,
      auth: auth,
      store: store,
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    controller.setStateForTest(
      CloudBackupConsentState(
        isLoading: false,
        record: _acceptedRecord(userId),
        lastError: null,
        isRemoteConfirmed: true,
      ),
    );

    await expectLater(controller.withdraw(), throwsStateError);

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.canEnableCloudUpload, isTrue);
    expect(controller.state.lastError, contains('could not be paused'));
  });
}

CloudBackupConsentRecord _acceptedRecord(String userId) {
  return CloudBackupConsentRecord(
    userId: userId,
    feature: cloudBackupConsentFeature,
    featureEnabled: true,
    appVersion: cloudBackupConsentAppVersion,
    privacyVersion: cloudBackupConsentPrivacyVersion,
    termsVersion: cloudBackupConsentTermsVersion,
    consentTextHash: cloudBackupConsentTextHash,
    consentedAt: DateTime.utc(2026, 7, 15),
    withdrawnAt: null,
  );
}

class _TestConsentController extends CloudBackupConsentController {
  _TestConsentController({
    required super.prefs,
    required super.auth,
    required CloudBackupConsentStore store,
  }) : super(client: null, store: store);

  void setStateForTest(CloudBackupConsentState value) {
    state = value;
  }
}

class _FailingConsentStore extends CloudBackupConsentStore {
  _FailingConsentStore(SharedPreferences prefs)
    : super(prefs: prefs, client: null);

  @override
  bool get isRemoteAvailable => true;

  @override
  Future<CloudBackupConsentRecord?> fetchRecord(String userId) async => null;

  @override
  Future<CloudBackupConsentRecord> acceptFor(String userId) async {
    throw StateError('offline');
  }

  @override
  Future<CloudBackupConsentRecord> withdrawFor(
    String userId, {
    CloudBackupConsentRecord? current,
  }) async {
    await clearEnablePending(userId);
    throw StateError('offline');
  }
}
