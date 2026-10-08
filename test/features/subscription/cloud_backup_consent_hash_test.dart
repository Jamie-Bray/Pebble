import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Bundled through sentry_flutter; see lib/core/config/app_version.dart.
// ignore: depend_on_referenced_packages
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pebble_routines/core/config/app_version.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The sentence that names voice tip recordings (5 October 2026).
const _currentHash =
    '19e2a2c7f63deef9320b02fe2e5950245a1ff4c08259af5551f0a76058d27e4f';
// The sentence before that. It is the one migration 011 put in the database.
const _previousHash =
    '447b66766fb90e5225c8eec970f296939ecd3568ebdb7287b0b62af8d7796744';

const _userId = '11111111-1111-1111-1111-111111111111';

void main() {
  test('consent text names everything backup uploads', () {
    expect(cloudBackupConsentText, contains('routines'));
    expect(cloudBackupConsentText, contains('proof photos'));
    expect(cloudBackupConsentText, contains('voice tip recordings'));
    expect(cloudBackupConsentText, contains('history'));
  });

  test('changing the consent text changes the recorded hash', () {
    // If this fails you changed the consent sentence. Update the hash here,
    // and the database step in supabase/DEPLOY_PLAN.md, in the same change.
    expect(cloudBackupConsentTextHash, _currentHash);
    expect(cloudBackupConsentTextHash, isNot(_previousHash));
  });

  test('the database step for the consent gate matches the app', () {
    // Check the executable migration, not just the proposed deployment prose.
    final step = File(
      'supabase/migrations/024_history_window_policy_dates.sql',
    ).readAsStringSync();

    expect(step, contains("'$cloudBackupConsentTextHash'"));
    // The gate also accepts the previous dates, so older builds keep working.
    expect(
      step,
      contains(
        "c.privacy_version in ('2026-10-05', "
        "'$cloudBackupConsentPrivacyVersion')",
      ),
    );
    expect(
      step,
      contains(
        "c.terms_version in ('2026-10-05', "
        "'$cloudBackupConsentTermsVersion')",
      ),
    );
  });

  test('recorded policy versions are the dates on the published pages', () {
    expect(cloudBackupConsentPrivacyVersion, _lastUpdated('web/privacy.html'));
    expect(cloudBackupConsentTermsVersion, _lastUpdated('web/terms.html'));
  });

  test('consent given to an earlier text or policy is not current', () {
    expect(_record().isCurrentAccepted, isTrue);
    expect(_record(consentTextHash: _previousHash).isCurrentAccepted, isFalse);
    expect(_record(privacyVersion: '2026-05-04').isCurrentAccepted, isFalse);
    expect(_record(termsVersion: '2026-05-04').isCurrentAccepted, isFalse);
  });

  test('someone who accepted the previous text is asked again', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final previous = _record(
      consentTextHash: _previousHash,
      privacyVersion: '2026-05-04',
      termsVersion: '2026-05-04',
    );
    final store = _RemoteRecordStore(prefs, previous);
    await store.cacheRecord(previous);
    final controller = CloudBackupConsentController(
      prefs: prefs,
      client: null,
      auth: const AuthSessionSummary(
        isSignedIn: true,
        userId: _userId,
        email: 'jamie@example.com',
        provider: 'google',
      ),
      store: store,
    );
    addTearDown(controller.dispose);

    // The controller loads itself once it is built.
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.isAccepted, isFalse);
    expect(controller.state.canEnableCloudUpload, isFalse);
  });

  test('the consent record gets the installed version and build', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Pebble',
      packageName: 'com.vix.pebbleroutines',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );

    expect(await readAppVersion(), '1.2.3+45');
  });
}

/// The page's "Last updated: <strong>5 October 2026</strong>" as 2026-10-05.
String _lastUpdated(String path) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final match = RegExp(
    r'Last updated: <strong>(\d{1,2}) (\w+) (\d{4})</strong>',
  ).firstMatch(File(path).readAsStringSync());
  expect(match, isNotNull, reason: '$path has no "Last updated" date');
  final month = months.indexOf(match!.group(2)!) + 1;
  expect(month, greaterThan(0), reason: 'Unknown month in $path');
  return '${match.group(3)}-${month.toString().padLeft(2, '0')}-'
      '${match.group(1)!.padLeft(2, '0')}';
}

CloudBackupConsentRecord _record({
  String? consentTextHash,
  String privacyVersion = cloudBackupConsentPrivacyVersion,
  String termsVersion = cloudBackupConsentTermsVersion,
}) {
  return CloudBackupConsentRecord(
    userId: _userId,
    feature: cloudBackupConsentFeature,
    featureEnabled: true,
    appVersion: '1.0.0+34',
    privacyVersion: privacyVersion,
    termsVersion: termsVersion,
    consentTextHash: consentTextHash ?? cloudBackupConsentTextHash,
    consentedAt: DateTime.utc(2026, 10, 5),
    withdrawnAt: null,
  );
}

class _RemoteRecordStore extends CloudBackupConsentStore {
  _RemoteRecordStore(SharedPreferences prefs, this._remote)
    : super(prefs: prefs, client: null);

  final CloudBackupConsentRecord _remote;

  @override
  bool get isRemoteAvailable => true;

  @override
  Future<CloudBackupConsentRecord?> fetchRecord(String userId) async => _remote;
}
