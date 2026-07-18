import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';

const cloudBackupConsentFeature = 'personal_cloud_backup';
const cloudBackupConsentAppVersion = '1.0.0+1';
const cloudBackupConsentPrivacyVersion = '2026-05-04';
const cloudBackupConsentTermsVersion = '2026-05-04';
const cloudBackupConsentText =
    'I understand Pebble backup may save routines, proof photos, '
    'history, and related details that could reveal sensitive information about my '
    'health, home, family, workplace, habits, or personal circumstances. '
    'I want to turn on backup for this account.';

String get cloudBackupConsentTextHash =>
    sha256.convert(utf8.encode(cloudBackupConsentText)).toString();

class CloudBackupConsentRecord {
  const CloudBackupConsentRecord({
    required this.userId,
    required this.feature,
    required this.featureEnabled,
    required this.appVersion,
    required this.privacyVersion,
    required this.termsVersion,
    required this.consentTextHash,
    required this.consentedAt,
    required this.withdrawnAt,
  });

  final String userId;
  final String feature;
  final bool featureEnabled;
  final String appVersion;
  final String privacyVersion;
  final String termsVersion;
  final String consentTextHash;
  final DateTime? consentedAt;
  final DateTime? withdrawnAt;

  bool get isCurrentAccepted =>
      feature == cloudBackupConsentFeature &&
      featureEnabled &&
      withdrawnAt == null &&
      consentTextHash == cloudBackupConsentTextHash &&
      privacyVersion == cloudBackupConsentPrivacyVersion &&
      termsVersion == cloudBackupConsentTermsVersion;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'feature': feature,
      'featureEnabled': featureEnabled,
      'appVersion': appVersion,
      'privacyVersion': privacyVersion,
      'termsVersion': termsVersion,
      'consentTextHash': consentTextHash,
      'consentedAt': consentedAt?.toUtc().toIso8601String(),
      'withdrawnAt': withdrawnAt?.toUtc().toIso8601String(),
    };
  }

  factory CloudBackupConsentRecord.fromLocalJson(Map<String, dynamic> json) {
    return CloudBackupConsentRecord(
      userId: json['userId']?.toString() ?? '',
      feature: json['feature']?.toString() ?? '',
      featureEnabled: json['featureEnabled'] == true,
      appVersion: json['appVersion']?.toString() ?? '',
      privacyVersion: json['privacyVersion']?.toString() ?? '',
      termsVersion: json['termsVersion']?.toString() ?? '',
      consentTextHash: json['consentTextHash']?.toString() ?? '',
      consentedAt: DateTime.tryParse(json['consentedAt']?.toString() ?? ''),
      withdrawnAt: DateTime.tryParse(json['withdrawnAt']?.toString() ?? ''),
    );
  }

  factory CloudBackupConsentRecord.fromRemoteJson(Map<String, dynamic> json) {
    return CloudBackupConsentRecord(
      userId: json['owner_user_id']?.toString() ?? '',
      feature: json['feature']?.toString() ?? '',
      featureEnabled: json['feature_enabled'] == true,
      appVersion: json['app_version']?.toString() ?? '',
      privacyVersion: json['privacy_version']?.toString() ?? '',
      termsVersion: json['terms_version']?.toString() ?? '',
      consentTextHash: json['consent_text_hash']?.toString() ?? '',
      consentedAt: DateTime.tryParse(json['consented_at']?.toString() ?? ''),
      withdrawnAt: DateTime.tryParse(json['withdrawn_at']?.toString() ?? ''),
    );
  }
}

class CloudBackupConsentState {
  const CloudBackupConsentState({
    required this.isLoading,
    required this.record,
    required this.lastError,
    this.isRemoteConfirmed = false,
  });

  const CloudBackupConsentState.initial()
    : isLoading = true,
      record = null,
      lastError = null,
      isRemoteConfirmed = false;

  final bool isLoading;
  final CloudBackupConsentRecord? record;
  final String? lastError;
  final bool isRemoteConfirmed;

  bool get isAccepted => record?.isCurrentAccepted == true;

  /// Uploads stay gated on a per-session remote confirmation so a consent
  /// withdrawn from another device is noticed before anything new uploads.
  /// UI layers must not read this as "consent missing": [isAccepted] with a
  /// pending confirmation is a transient checking state, not an ask.
  bool get canEnableCloudUpload => isAccepted && isRemoteConfirmed;

  CloudBackupConsentState copyWith({
    bool? isLoading,
    CloudBackupConsentRecord? record,
    bool clearRecord = false,
    String? lastError,
    bool clearError = false,
    bool? isRemoteConfirmed,
  }) {
    return CloudBackupConsentState(
      isLoading: isLoading ?? this.isLoading,
      record: clearRecord ? null : record ?? this.record,
      lastError: clearError ? null : lastError ?? this.lastError,
      isRemoteConfirmed: isRemoteConfirmed ?? this.isRemoteConfirmed,
    );
  }
}

/// Persistence for consent records, deliberately free of any auth-provider
/// dependency. The sign-in flow must read and write consent while
/// authentication is still in flight, and reading the auth-scoped controller
/// from inside the auth controller forms a provider cycle.
class CloudBackupConsentStore {
  CloudBackupConsentStore({
    required SharedPreferences prefs,
    required SupabaseClient? client,
  }) : _prefs = prefs,
       _client = client;

  final SharedPreferences _prefs;
  final SupabaseClient? _client;

  bool get isRemoteAvailable => _client != null;

  String _cacheKey(String userId) => 'pebble.cloud_backup_consent.$userId';
  String _pendingEnableKey(String userId) =>
      'pebble.cloud_backup_consent_pending.$userId';

  bool isEnablePending(String userId) =>
      _prefs.getBool(_pendingEnableKey(userId)) == true;

  Future<void> markEnablePending(String userId) async {
    await _prefs.setBool(_pendingEnableKey(userId), true);
  }

  Future<void> clearEnablePending(String userId) async {
    await _prefs.remove(_pendingEnableKey(userId));
  }

  /// The locally cached record. It is only ever written after a successful
  /// remote upsert or a remote fetch, so it is proof of consent on its own.
  CloudBackupConsentRecord? readCachedRecord(String userId) {
    final raw = _prefs.getString(_cacheKey(userId));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return CloudBackupConsentRecord.fromLocalJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheRecord(CloudBackupConsentRecord record) {
    return _prefs.setString(
      _cacheKey(record.userId),
      jsonEncode(record.toJson()),
    );
  }

  /// The remote record, cached locally when found. Throws when the server
  /// cannot be reached.
  Future<CloudBackupConsentRecord?> fetchRecord(String userId) async {
    final client = _client;
    if (client == null) {
      return readCachedRecord(userId);
    }
    final response = await client
        .from('cloud_backup_consents')
        .select()
        .eq('owner_user_id', userId)
        .eq('feature', cloudBackupConsentFeature)
        .maybeSingle();
    final remoteRecord = response == null
        ? null
        : CloudBackupConsentRecord.fromRemoteJson(
            Map<String, dynamic>.from(response),
          );
    if (remoteRecord == null) {
      // A successful empty response is authoritative. Leaving an older local
      // acceptance behind would let a later bootstrap mistake stale consent
      // for a current server record.
      await _prefs.remove(_cacheKey(userId));
    } else {
      await cacheRecord(remoteRecord);
    }
    return remoteRecord;
  }

  Future<CloudBackupConsentRecord> acceptFor(String userId) async {
    final client = _client;
    if (client == null) {
      throw StateError('Backup is not available in this build.');
    }
    final now = DateTime.now().toUtc();
    final record = CloudBackupConsentRecord(
      userId: userId,
      feature: cloudBackupConsentFeature,
      featureEnabled: true,
      appVersion: cloudBackupConsentAppVersion,
      privacyVersion: cloudBackupConsentPrivacyVersion,
      termsVersion: cloudBackupConsentTermsVersion,
      consentTextHash: cloudBackupConsentTextHash,
      consentedAt: now,
      withdrawnAt: null,
    );
    await client.from('cloud_backup_consents').upsert({
      'owner_user_id': record.userId,
      'feature': record.feature,
      'feature_enabled': record.featureEnabled,
      'app_version': record.appVersion,
      'privacy_version': record.privacyVersion,
      'terms_version': record.termsVersion,
      'consent_text_hash': record.consentTextHash,
      'consented_at': record.consentedAt!.toIso8601String(),
      'withdrawn_at': null,
      'updated_at': now.toIso8601String(),
    }, onConflict: 'owner_user_id,feature');
    await cacheRecord(record);
    return record;
  }

  Future<CloudBackupConsentRecord> withdrawFor(
    String userId, {
    CloudBackupConsentRecord? current,
  }) async {
    // A pause always cancels a queued enable retry, even if the server request
    // itself has to be attempted again later.
    await clearEnablePending(userId);
    final client = _client;
    if (client == null) {
      throw StateError('Backup is not available in this build.');
    }
    final now = DateTime.now().toUtc();
    final record = CloudBackupConsentRecord(
      userId: userId,
      feature: cloudBackupConsentFeature,
      featureEnabled: false,
      appVersion: current?.appVersion ?? cloudBackupConsentAppVersion,
      privacyVersion:
          current?.privacyVersion ?? cloudBackupConsentPrivacyVersion,
      termsVersion: current?.termsVersion ?? cloudBackupConsentTermsVersion,
      consentTextHash: current?.consentTextHash ?? cloudBackupConsentTextHash,
      consentedAt: current?.consentedAt,
      withdrawnAt: now,
    );
    await client.from('cloud_backup_consents').upsert({
      'owner_user_id': record.userId,
      'feature': record.feature,
      'feature_enabled': false,
      'app_version': record.appVersion,
      'privacy_version': record.privacyVersion,
      'terms_version': record.termsVersion,
      'consent_text_hash': record.consentTextHash,
      'consented_at': record.consentedAt?.toIso8601String(),
      'withdrawn_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, onConflict: 'owner_user_id,feature');
    await cacheRecord(record);
    return record;
  }
}

final cloudBackupConsentStoreProvider = Provider<CloudBackupConsentStore>((
  ref,
) {
  return CloudBackupConsentStore(
    prefs: ref.watch(sharedPreferencesProvider),
    client: ref.watch(supabaseClientProvider),
  );
});

class CloudBackupConsentController
    extends StateNotifier<CloudBackupConsentState> {
  CloudBackupConsentController({
    required SharedPreferences prefs,
    required SupabaseClient? client,
    required AuthSessionSummary auth,
    CloudBackupConsentStore? store,
  }) : _store = store ?? CloudBackupConsentStore(prefs: prefs, client: client),
       _hasClient = store?.isRemoteAvailable ?? client != null,
       _auth = auth,
       super(const CloudBackupConsentState.initial()) {
    Future.microtask(load);
  }

  final CloudBackupConsentStore _store;
  final bool _hasClient;
  final AuthSessionSummary _auth;
  int _loadRevision = 0;
  bool _mutationInFlight = false;

  String? get _userId =>
      _auth.userId?.trim().isEmpty == false ? _auth.userId!.trim() : null;

  Future<void> load() async {
    if (_mutationInFlight) {
      return;
    }
    final revision = ++_loadRevision;
    final userId = _userId;
    if (!_auth.isSignedIn || userId == null) {
      if (revision != _loadRevision) return;
      state = const CloudBackupConsentState(
        isLoading: false,
        record: null,
        lastError: null,
        isRemoteConfirmed: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final localRecord = _store.readCachedRecord(userId);
    if (localRecord?.isCurrentAccepted == true) {
      if (revision != _loadRevision) return;
      state = state.copyWith(
        isLoading: false,
        record: localRecord,
        isRemoteConfirmed: false,
      );
    }

    if (!_hasClient) {
      if (revision != _loadRevision) return;
      state = state.copyWith(
        isLoading: false,
        record: localRecord,
        isRemoteConfirmed: false,
      );
      return;
    }

    try {
      final remoteRecord = await _store.fetchRecord(userId);
      if (revision != _loadRevision || _mutationInFlight) return;
      state = CloudBackupConsentState(
        isLoading: false,
        record: remoteRecord,
        lastError: null,
        isRemoteConfirmed: remoteRecord?.isCurrentAccepted == true,
      );
    } catch (_) {
      if (revision != _loadRevision || _mutationInFlight) return;
      state = CloudBackupConsentState(
        isLoading: false,
        record: localRecord,
        lastError:
            'Pebble could not check your cloud backup consent yet. Try again.',
        isRemoteConfirmed: false,
      );
    }
  }

  Future<void> accept() async {
    final userId = _userId;
    if (!_auth.isSignedIn || userId == null || !_hasClient) {
      throw StateError('Sign in before enabling cloud backup.');
    }

    final previous = state;
    _mutationInFlight = true;
    _loadRevision++;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _store.markEnablePending(userId);
      final record = await _store.acceptFor(userId);
      await _store.clearEnablePending(userId);
      state = CloudBackupConsentState(
        isLoading: false,
        record: record,
        lastError: null,
        isRemoteConfirmed: true,
      );
    } catch (_) {
      state = CloudBackupConsentState(
        isLoading: false,
        record: previous.record,
        lastError:
            'Backup is still off. Pebble will try again when you are online.',
        isRemoteConfirmed: previous.isRemoteConfirmed,
      );
      rethrow;
    } finally {
      _mutationInFlight = false;
    }
  }

  Future<void> withdraw() async {
    final userId = _userId;
    if (!_auth.isSignedIn || userId == null || !_hasClient) {
      throw StateError('Sign in before changing cloud backup consent.');
    }

    final previous = state;
    _mutationInFlight = true;
    _loadRevision++;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final record = await _store.withdrawFor(userId, current: previous.record);
      state = CloudBackupConsentState(
        isLoading: false,
        record: record,
        lastError: null,
        isRemoteConfirmed: true,
      );
    } catch (_) {
      state = CloudBackupConsentState(
        isLoading: false,
        record: previous.record,
        lastError: 'Backup could not be paused. Please try again.',
        isRemoteConfirmed: previous.isRemoteConfirmed,
      );
      rethrow;
    } finally {
      _mutationInFlight = false;
    }
  }
}

final cloudBackupConsentControllerProvider =
    StateNotifierProvider<
      CloudBackupConsentController,
      CloudBackupConsentState
    >((ref) {
      return CloudBackupConsentController(
        prefs: ref.watch(sharedPreferencesProvider),
        client: ref.watch(supabaseClientProvider),
        auth: ref.watch(authSessionProvider),
      );
    });

final cloudBackupConsentStateProvider = Provider<CloudBackupConsentState>((
  ref,
) {
  return ref.watch(cloudBackupConsentControllerProvider);
});
