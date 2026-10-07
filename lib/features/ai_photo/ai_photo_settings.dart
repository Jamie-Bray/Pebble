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

/// Which routines have AI switched on for this account on this phone, and
/// the consent that goes with them. The monthly allowance on the server is
/// the limit, not the number of routines.
class AiPhotoSettings {
  const AiPhotoSettings({
    this.routineIds = const {},
    this.consentVersion,
    this.consentedAt,
    this.emailRoutineIds = const {},
    this.withdrawalPending = false,
  });

  static const off = AiPhotoSettings();

  final Set<int> routineIds;
  final String? consentVersion;
  final DateTime? consentedAt;

  /// Routines whose completion email includes the descriptions. A routine is
  /// only here after the person said yes for it.
  final Set<int> emailRoutineIds;

  /// AI was turned off but the server has not yet recorded the withdrawal.
  final bool withdrawalPending;

  /// On, and agreed to the wording this build shows. A consent to older
  /// wording counts as off, so the person is asked again.
  bool get isOn =>
      routineIds.isNotEmpty && consentVersion == aiPhotoConsentVersion;

  bool isOnFor(int id) => isOn && routineIds.contains(id);

  bool emailDescriptionsFor(int id) =>
      isOnFor(id) && emailRoutineIds.contains(id);

  Map<String, dynamic> toJson() => {
    'routineIds': routineIds.toList(),
    'consentVersion': consentVersion,
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'emailRoutineIds': emailRoutineIds.toList(),
    'withdrawalPending': withdrawalPending,
  };

  factory AiPhotoSettings.fromJson(Map<String, dynamic> json) {
    Set<int> ids(Object? value) => value is List
        ? value.whereType<num>().map((n) => n.toInt()).toSet()
        : {};
    // Before several routines were allowed there was one `routineId`.
    final legacyId = (json['routineId'] as num?)?.toInt();
    return AiPhotoSettings(
      routineIds: {...ids(json['routineIds']), if (legacyId != null) legacyId},
      consentVersion: json['consentVersion'] as String?,
      consentedAt: DateTime.tryParse(json['consentedAt']?.toString() ?? ''),
      emailRoutineIds: {
        ...ids(json['emailRoutineIds']),
        if (legacyId != null && json['emailDescriptions'] == true) legacyId,
      },
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
      return AiPhotoSettings.fromJson(
        Map<String, dynamic>.from(decoded as Map),
      );
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

  /// Switches AI on for a routine, keeping any others. Call only after the
  /// person has checked the box on the consent sheet. The consent is recorded
  /// on the server first; if that fails this throws [AiPhotoException] and
  /// nothing changes.
  Future<void> turnOn({
    required int routineId,
    required String routineKey,
  }) async {
    // A withdrawal still on its way must land first, or it would cancel
    // the consent recorded here.
    await _withdrawal;
    await _service.recordConsent(routineKey: routineKey);
    await _save(
      AiPhotoSettings(
        // Routines agreed under older wording are asked again, one by one.
        routineIds: {if (state.isOn) ...state.routineIds, routineId},
        consentVersion: aiPhotoConsentVersion,
        consentedAt: _clock(),
        emailRoutineIds: state.isOn
            ? state.emailRoutineIds.difference({routineId})
            : const {},
      ),
    );
  }

  /// Stops sending this routine's photos straight away. When it was the last
  /// routine using AI, the withdrawal is also recorded on the server; if the
  /// server can't be reached that is tried again the next time the app
  /// starts, and nothing is sent in the meantime either way.
  Future<void> turnOff(int routineId) async {
    final remaining = state.routineIds.difference({routineId});
    if (state.isOn && remaining.isNotEmpty) {
      await _save(
        AiPhotoSettings(
          routineIds: remaining,
          consentVersion: state.consentVersion,
          consentedAt: state.consentedAt,
          emailRoutineIds: state.emailRoutineIds.difference({routineId}),
        ),
      );
      return;
    }
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

  Future<void> setEmailDescriptions(int routineId, bool include) async {
    if (!state.isOnFor(routineId)) return;
    await _save(
      AiPhotoSettings(
        routineIds: state.routineIds,
        consentVersion: state.consentVersion,
        consentedAt: state.consentedAt,
        emailRoutineIds: include
            ? {...state.emailRoutineIds, routineId}
            : state.emailRoutineIds.difference({routineId}),
      ),
    );
  }
}

final aiPhotoControllerProvider =
    StateNotifierProvider<AiPhotoController, AiPhotoSettings>((ref) {
      // Only the signed-in account matters here. Watching the whole auth
      // summary rebuilt this controller (and everything below it, including
      // the routine player) every time the app came back to the front.
      final userId = ref.watch(
        authSessionProvider.select(
          (auth) => auth.isSignedIn ? auth.userId : null,
        ),
      );
      return AiPhotoController(
        prefs: ref.watch(sharedPreferencesProvider),
        service: ref.watch(aiPhotoServiceProvider),
        userId: userId,
      );
    });

/// The routines whose photo steps are described right now. Needs the
/// switch, a signed-in account and Personal Premium on this phone; the server
/// checks all three again on every photo.
///
/// Only changes when the set of ids really changes: both inputs are read
/// through `select` on plain values, because a new but equal Set would
/// otherwise count as a change for everything watching this.
final aiPhotoActiveRoutineIdsProvider = Provider<Set<int>>((ref) {
  final ids = ref.watch(
    aiPhotoControllerProvider.select(
      (settings) =>
          settings.isOn ? (settings.routineIds.toList()..sort()).join(',') : '',
    ),
  );
  final premium = ref.watch(
    premiumFeaturePolicyProvider.select(
      (policy) => policy.hasActiveLocalPremium,
    ),
  );
  if (!premium || ids.isEmpty) return const {};
  return {for (final id in ids.split(',')) int.parse(id)};
});
