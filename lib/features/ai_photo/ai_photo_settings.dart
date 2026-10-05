import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';

/// The step indexes whose photos AI describes: the first [aiPhotoMaxSteps]
/// photo steps, in order.
// ponytail: no per-step choice. If people want to pick which photo steps use
// AI, add an `aiDescribe` flag to RoutineStep.check and filter on it here.
Set<int> aiPhotoStepIndexes(List<RoutineStep> steps) {
  final indexes = <int>{};
  for (var i = 0; i < steps.length; i++) {
    if (indexes.length == aiPhotoMaxSteps) break;
    if (steps[i].hasPhotoRequirement) indexes.add(i);
  }
  return indexes;
}

int photoStepCount(List<RoutineStep> steps) =>
    steps.where((step) => step.hasPhotoRequirement).length;

/// Which routine has AI switched on for this account on this phone, and the
/// consent that goes with it. One routine at a time.
class AiPhotoSettings {
  const AiPhotoSettings({
    this.routineId,
    this.routineTitle,
    this.consentVersion,
    this.consentedAt,
    this.emailDescriptions,
    this.withdrawalPending = false,
  });

  static const off = AiPhotoSettings();

  final int? routineId;

  /// The routine's name when AI was switched on, for "On for ...".
  final String? routineTitle;
  final String? consentVersion;
  final DateTime? consentedAt;

  /// Whether descriptions go in this routine's completion email. Null until
  /// the person answers; only `true` ever adds them.
  final bool? emailDescriptions;

  /// AI was turned off but the server has not yet recorded the withdrawal.
  final bool withdrawalPending;

  /// On, and agreed to the wording this build shows. A consent to older
  /// wording counts as off, so the person is asked again.
  bool get isOn => routineId != null && consentVersion == aiPhotoConsentVersion;

  bool isOnFor(int id) => isOn && routineId == id;

  Map<String, dynamic> toJson() => {
    'routineId': routineId,
    'routineTitle': routineTitle,
    'consentVersion': consentVersion,
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'emailDescriptions': emailDescriptions,
    'withdrawalPending': withdrawalPending,
  };

  factory AiPhotoSettings.fromJson(Map<String, dynamic> json) {
    return AiPhotoSettings(
      routineId: (json['routineId'] as num?)?.toInt(),
      routineTitle: json['routineTitle'] as String?,
      consentVersion: json['consentVersion'] as String?,
      consentedAt: DateTime.tryParse(json['consentedAt']?.toString() ?? ''),
      emailDescriptions: json['emailDescriptions'] as bool?,
      withdrawalPending: json['withdrawalPending'] == true,
    );
  }
}

class AiPhotoController extends StateNotifier<AiPhotoSettings> {
  AiPhotoController({
    required SharedPreferences prefs,
    required AiPhotoService service,
    required String? userId,
    DateTime Function()? clock,
  }) : _prefs = prefs,
       _service = service,
       _userId = userId,
       _clock = clock ?? DateTime.now,
       super(_read(prefs, userId)) {
    if (state.withdrawalPending) {
      _withdrawal = Future.microtask(_recordWithdrawal);
    }
  }

  final SharedPreferences _prefs;
  final AiPhotoService _service;
  final String? _userId;
  final DateTime Function() _clock;
  Future<void>? _withdrawal;

  static String _key(String userId) => 'pebble.ai_photo.$userId';

  static AiPhotoSettings _read(SharedPreferences prefs, String? userId) {
    if (userId == null) return AiPhotoSettings.off;
    try {
      final decoded = jsonDecode(prefs.getString(_key(userId)) ?? '');
      return AiPhotoSettings.fromJson(Map<String, dynamic>.from(decoded as Map));
    } catch (_) {
      return AiPhotoSettings.off;
    }
  }

  Future<void> _save(AiPhotoSettings next) async {
    state = next;
    final userId = _userId;
    if (userId != null) {
      await _prefs.setString(_key(userId), jsonEncode(next.toJson()));
    }
  }

  /// Switches AI on for one routine, replacing any other. Call only after the
  /// person has checked the box on the consent sheet. The consent is recorded
  /// on the server first; if that fails this throws [AiPhotoException] and
  /// nothing changes.
  Future<void> turnOn({
    required int routineId,
    required String routineTitle,
    required String routineKey,
  }) async {
    // A withdrawal still on its way must land first, or it would cancel
    // the consent recorded here.
    await _withdrawal;
    await _service.recordConsent(routineKey: routineKey);
    await _save(
      AiPhotoSettings(
        routineId: routineId,
        routineTitle: routineTitle,
        consentVersion: aiPhotoConsentVersion,
        consentedAt: _clock(),
      ),
    );
  }

  /// Stops sending photos straight away, then records the withdrawal on the
  /// server. If the server can't be reached it is tried again the next time
  /// the app starts; nothing is sent in the meantime either way.
  Future<void> turnOff() async {
    await _save(const AiPhotoSettings(withdrawalPending: true));
    await (_withdrawal = _recordWithdrawal());
  }

  Future<void> _recordWithdrawal() async {
    try {
      await _service.withdrawConsent();
      if (mounted && !state.isOn) await _save(AiPhotoSettings.off);
    } catch (_) {
      // Left pending.
    }
  }

  Future<void> setEmailDescriptions(bool include) async {
    if (!state.isOn) return;
    await _save(
      AiPhotoSettings(
        routineId: state.routineId,
        routineTitle: state.routineTitle,
        consentVersion: state.consentVersion,
        consentedAt: state.consentedAt,
        emailDescriptions: include,
      ),
    );
  }
}

final aiPhotoControllerProvider =
    StateNotifierProvider<AiPhotoController, AiPhotoSettings>((ref) {
      final auth = ref.watch(authSessionProvider);
      return AiPhotoController(
        prefs: ref.watch(sharedPreferencesProvider),
        service: ref.watch(aiPhotoServiceProvider),
        userId: auth.isSignedIn ? auth.userId : null,
      );
    });

/// The routine whose photo steps are described right now, or null. Needs the
/// switch, a signed-in account and Personal Premium on this phone; the server
/// checks all three again on every photo.
final aiPhotoActiveRoutineIdProvider = Provider<int?>((ref) {
  final settings = ref.watch(aiPhotoControllerProvider);
  final policy = ref.watch(premiumFeaturePolicyProvider);
  return settings.isOn && policy.hasActiveLocalPremium
      ? settings.routineId
      : null;
});
