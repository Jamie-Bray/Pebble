import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';

enum ProofMediaFairUseStatus { ok, warning, full }

enum ProofMediaUploadBlockReason {
  none,
  fileTooLarge,
  storageFull,
  uploadsFull,
}

class ProofMediaFairUsePolicy {
  static const int storageLimitBytes = 1024 * 1024 * 1024; // 1 GB
  static const int monthlyUploadLimit = 500;
  static const int perFileLimitBytes = 8 * 1024 * 1024;
  static const double warningThreshold = 0.8;
  static const int uploadRollingWindowDays = 30;
  static const int cloudRetentionDays = 21;
  static const int localRetentionHours = 48;
  static const Duration localRetentionDuration = Duration(
    hours: localRetentionHours,
  );
}

class ProofMediaFairUseState {
  const ProofMediaFairUseState({
    required this.activeCloudBytes,
    required this.storageLimitBytes,
    required this.uploadsThisPeriod,
    required this.monthlyUploadLimit,
  });

  final int activeCloudBytes;
  final int storageLimitBytes;
  final int uploadsThisPeriod;
  final int monthlyUploadLimit;

  double get storageFraction {
    if (storageLimitBytes <= 0) return 0;
    return (activeCloudBytes / storageLimitBytes).clamp(0, 1).toDouble();
  }

  ProofMediaFairUseStatus get status {
    if (activeCloudBytes >= storageLimitBytes ||
        uploadsThisPeriod >= monthlyUploadLimit) {
      return ProofMediaFairUseStatus.full;
    }
    if (storageFraction >= ProofMediaFairUsePolicy.warningThreshold ||
        uploadsThisPeriod >=
            (monthlyUploadLimit * ProofMediaFairUsePolicy.warningThreshold)) {
      return ProofMediaFairUseStatus.warning;
    }
    return ProofMediaFairUseStatus.ok;
  }

  String get storageLabel {
    return '${_formatBytes(activeCloudBytes)} of ${_formatBytes(storageLimitBytes)} used';
  }

  String get uploadLabel {
    return '$uploadsThisPeriod of $monthlyUploadLimit proof photo uploads used this month';
  }
}

class ProofMediaFairUseCheck {
  const ProofMediaFairUseCheck({
    required this.allowed,
    required this.reason,
    required this.state,
  });

  final bool allowed;
  final ProofMediaUploadBlockReason reason;
  final ProofMediaFairUseState state;
}

abstract class ProofMediaFairUseStore {
  Future<ProofMediaFairUseState> load();
  Future<ProofMediaFairUseCheck> canUploadProof({required int byteCount});
  Future<void> recordProofUpload({required int byteCount});
}

class LocalProofMediaFairUseStore implements ProofMediaFairUseStore {
  LocalProofMediaFairUseStore(this._prefs);

  static const _activeBytesKey = 'pebble.fair_use.proof.active_cloud_bytes';
  static const _uploadsKey = 'pebble.fair_use.proof.uploads_this_period';
  static const _periodStartKey = 'pebble.fair_use.proof.period_start';

  final SharedPreferences _prefs;

  @override
  Future<ProofMediaFairUseState> load() async {
    await _resetRollingWindowIfNeeded();
    return ProofMediaFairUseState(
      activeCloudBytes: _prefs.getInt(_activeBytesKey) ?? 0,
      storageLimitBytes: ProofMediaFairUsePolicy.storageLimitBytes,
      uploadsThisPeriod: _prefs.getInt(_uploadsKey) ?? 0,
      monthlyUploadLimit: ProofMediaFairUsePolicy.monthlyUploadLimit,
    );
  }

  @override
  Future<ProofMediaFairUseCheck> canUploadProof({
    required int byteCount,
  }) async {
    final state = await load();
    if (byteCount > ProofMediaFairUsePolicy.perFileLimitBytes) {
      return ProofMediaFairUseCheck(
        allowed: false,
        reason: ProofMediaUploadBlockReason.fileTooLarge,
        state: state,
      );
    }
    if (state.uploadsThisPeriod >= state.monthlyUploadLimit) {
      return ProofMediaFairUseCheck(
        allowed: false,
        reason: ProofMediaUploadBlockReason.uploadsFull,
        state: state,
      );
    }
    if (state.activeCloudBytes + byteCount > state.storageLimitBytes) {
      return ProofMediaFairUseCheck(
        allowed: false,
        reason: ProofMediaUploadBlockReason.storageFull,
        state: state,
      );
    }
    return ProofMediaFairUseCheck(
      allowed: true,
      reason: ProofMediaUploadBlockReason.none,
      state: state,
    );
  }

  @override
  Future<void> recordProofUpload({required int byteCount}) async {
    await _resetRollingWindowIfNeeded();
    final activeBytes = (_prefs.getInt(_activeBytesKey) ?? 0) + byteCount;
    final uploads = (_prefs.getInt(_uploadsKey) ?? 0) + 1;
    await _prefs.setInt(_activeBytesKey, activeBytes);
    await _prefs.setInt(_uploadsKey, uploads);
  }

  Future<void> _resetRollingWindowIfNeeded() async {
    final now = DateTime.now();
    final rawStart = _prefs.getString(_periodStartKey);
    final periodStart = rawStart == null ? null : DateTime.tryParse(rawStart);
    if (periodStart != null &&
        now.difference(periodStart).inDays <
            ProofMediaFairUsePolicy.uploadRollingWindowDays) {
      return;
    }
    await _prefs.setString(_periodStartKey, now.toIso8601String());
    await _prefs.setInt(_activeBytesKey, 0);
    await _prefs.setInt(_uploadsKey, 0);
  }
}

final proofMediaFairUseStoreProvider = Provider<ProofMediaFairUseStore>((ref) {
  return LocalProofMediaFairUseStore(ref.watch(sharedPreferencesProvider));
});

final proofMediaFairUseStateProvider = FutureProvider<ProofMediaFairUseState>((
  ref,
) {
  return ref.watch(proofMediaFairUseStoreProvider).load();
});

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    final gb = bytes / (1024 * 1024 * 1024);
    return '${_formatUnit(gb)} GB';
  }
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '${_formatUnit(mb)} MB';
  }
  if (bytes >= 1024) {
    final kb = bytes / 1024;
    return '${_formatUnit(kb)} KB';
  }
  return '$bytes B';
}

String _formatUnit(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(value >= 10 ? 0 : 1);
}
