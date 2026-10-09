// AI photo captions must reach the photo, the saved session and the run even
// when the player's providers change while a photo is being described (the
// app comes back from the camera and refreshes sign-in and Premium).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

import '../../../support/premium_policy_test_utils.dart';

const _userId = '11111111-1111-1111-1111-111111111111';
const _photo = RoutineStep.check(label: 'Front door', requiresPhoto: true);
const _plain = RoutineStep.check(label: 'Keys in bag');

class _FakeProofStorage implements RoutineSessionProofStorage {
  int _count = 0;

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    _count += 1;
    return RoutineSessionProofAsset(
      proofId: 'proof-$_count-0000-0000',
      localRelativePath: 'proofs/$sessionId/proof-$_count.webp',
      remoteObjectKey: null,
      uploadStatus: ProofUploadStatus.localOnly,
      capturedAt: DateTime(2026, 10, 5, 8, 2),
    );
  }

  @override
  Future<File?> resolveStoredFile(String storedPath) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) async {}
}

class _FakeGuidanceAudioStorage implements GuidanceAudioStorage {
  @override
  Future<void> cleanupOrphanedAudio(Set<String> activeLocalPaths) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) async {}
}

Routine _routine(List<RoutineStep> steps) => Routine(
  id: 1,
  title: 'Lock up',
  stepsJson: jsonEncode(steps.map((step) => step.toJson()).toList()),
  createdAt: DateTime(2026, 1, 1),
  emoji: null,
  colorHex: null,
  isPinned: false,
  pinnedAt: null,
  reminderDay: null,
  reminderTime: null,
  version: 1,
  updatedAt: DateTime(2026, 1, 1),
  cloudId: null,
  ownerUserId: null,
  syncStatus: 'localOnly',
  lastSyncedAt: null,
);

/// Each bump rebuilds the auth summary and the Premium policy with equal
/// but new values, as an app resume does.
final _resumeTick = StateProvider<int>((ref) => 0);
final _premium = StateProvider<bool>((ref) => true);

class _Call {
  _Call(this.asset, this.key);
  final RoutineSessionProofAsset asset;
  final String key;
  final answer = Completer<String?>();
}

void main() {
  // Hidden for launch; these tests cover the feature for when it returns.
  aiPhotoFeatureVisible = true;

  late LocalDb database;
  late ProviderContainer container;
  late RoutineSessionRepository repository;
  late List<_Call> calls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pebble.ai_photo.$_userId': jsonEncode({
        'routineIds': [1],
        'consentVersion': aiPhotoConsentVersion,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    database = LocalDb.forTesting(NativeDatabase.memory());
    calls = [];
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(database),
        guidanceAudioStorageProvider.overrideWithValue(
          _FakeGuidanceAudioStorage(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        aiPhotoServiceProvider.overrideWithValue(AiPhotoService(null)),
        routineSessionProofStorageProvider.overrideWithValue(
          _FakeProofStorage(),
        ),
        subscriptionAccountControllerProvider.overrideWith(
          (ref) => SubscriptionAccountController(database, loadOnInit: false),
        ),
        authSessionProvider.overrideWith((ref) {
          ref.watch(_resumeTick);
          return const AuthSessionSummary(
            isSignedIn: true,
            userId: _userId,
            email: 'a@b.c',
            provider: 'google',
          );
        }),
        premiumFeaturePolicyProvider.overrideWith((ref) {
          ref.watch(_resumeTick);
          return premiumFeaturePolicyForTier(
            ref.watch(_premium)
                ? UserTier.personalPremium
                : UserTier.personalFree,
          );
        }),
        aiProofDescriberProvider.overrideWithValue((
          asset,
          stepLabel,
          photoDetail,
          key,
        ) {
          final call = _Call(asset, key);
          calls.add(call);
          return call.answer.future;
        }),
      ],
    );
    repository = container.read(routineSessionRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<RoutineSession> start(List<RoutineStep> steps) async {
    final routine = _routine(steps);
    await database.routineDao.insertOrUpdateRoutine(routine);
    return repository.startOrResumeSession(
      routine: routine,
      routingContext: const SessionRoutingContext(
        storageScope: SessionStorageScope.localOnly,
      ),
    );
  }

  Future<ProviderSubscription<RoutinePlayerUiState>> openPlayer(
    String sessionId,
  ) async {
    final subscription = container.listen(
      routinePlayerProvider(sessionId),
      (_, _) {},
    );
    await pumpEventQueue();
    expect(subscription.read().screenPhase, RoutinePlayerScreenPhase.ready);
    return subscription;
  }

  Future<String?> storedDescription(String sessionId) async {
    final stored = await repository.getSessionById(sessionId);
    return stored!.stepStates.expand((s) => s.proofAssets).single.aiDescription;
  }

  String? runDescription(RoutineRun run) {
    final data = jsonDecode(run.stepCompletionData!) as Map;
    for (final step in data['steps'] as List) {
      for (final asset in (step as Map)['proofAssets'] as List) {
        final text = (asset as Map)['aiDescription'];
        if (text is String) return text;
      }
    }
    return null;
  }

  test('a resume while a photo is described keeps the same player, and the '
      'caption reaches the screen, the session row and the run', () async {
    final session = await start(const [_photo, _plain]);
    final player = await openPlayer(session.sessionId);
    final controller = container.read(
      routinePlayerProvider(session.sessionId).notifier,
    );

    await controller.attachProof('/tmp/a.jpg');
    expect(calls, hasLength(1));
    final asset = player.read().proofAssets.single;
    expect(player.read().aiDescriptionFor(asset)!.isPending, isTrue);

    // The app comes back from the camera: sign-in and Premium refresh.
    container.read(_resumeTick.notifier).state++;
    await pumpEventQueue();
    container.read(_resumeTick.notifier).state++;
    await pumpEventQueue();
    expect(
      identical(
        container.read(routinePlayerProvider(session.sessionId).notifier),
        controller,
      ),
      isTrue,
      reason: 'the run keeps one controller',
    );

    // The person moves on and finishes before the caption arrives.
    await controller.completeCurrentStep();
    final run = await controller.completeCurrentStep();
    expect(run, isNotNull);
    expect(player.read().screenPhase, RoutinePlayerScreenPhase.completion);

    calls.single.answer.complete('A white door with the handle up.');
    await pumpEventQueue();

    expect(
      player.read().aiDescriptionFor(asset)!.text,
      'A white door with the handle up.',
    );
    expect(
      await storedDescription(session.sessionId),
      'A white door with the handle up.',
    );
    final storedRun = await database.routineRunDao.getRunById(run!.id);
    expect(runDescription(storedRun!), 'A white door with the handle up.');
  });

  test(
    'even a rebuilt player keeps a caption that arrived meanwhile, and a stale '
    'snapshot never wipes it',
    () async {
      final session = await start(const [_photo, _plain]);
      var player = await openPlayer(session.sessionId);
      await container
          .read(routinePlayerProvider(session.sessionId).notifier)
          .attachProof('/tmp/a.jpg');
      final stale = player.read().session!;

      // Force the worst case: the controller is thrown away mid-describe.
      player.close();
      container.invalidate(routinePlayerProvider(session.sessionId));
      await pumpEventQueue();
      calls.single.answer.complete('A blue bag on a chair.');
      await pumpEventQueue();

      // A snapshot from before the caption is saved over the row.
      await repository.saveSessionSnapshot(stale);
      expect(
        await storedDescription(session.sessionId),
        'A blue bag on a chair.',
      );

      player = await openPlayer(session.sessionId);
      final controller = container.read(
        routinePlayerProvider(session.sessionId).notifier,
      );
      final asset = player.read().proofAssets.single;
      expect(
        player.read().aiDescriptionFor(asset)!.text,
        'A blue bag on a chair.',
      );
      await controller.completeCurrentStep();
      final run = await controller.completeCurrentStep();
      expect(runDescription(run!), 'A blue bag on a chair.');
    },
  );

  test(
    'Premium changing mid-run updates the player without rebuilding it',
    () async {
      final session = await start(const [_photo, _plain]);
      final player = await openPlayer(session.sessionId);
      final controller = container.read(
        routinePlayerProvider(session.sessionId).notifier,
      );
      expect(player.read().maxProofPhotosPerStep, 4);
      expect(player.read().aiRoutineActive, isTrue);

      container.read(_premium.notifier).state = false;
      await pumpEventQueue();
      expect(
        identical(
          container.read(routinePlayerProvider(session.sessionId).notifier),
          controller,
        ),
        isTrue,
      );
      expect(player.read().maxProofPhotosPerStep, 1);
      expect(player.read().aiRoutineActive, isFalse);
    },
  );

  test('a failed description can be tried again, under a new key', () async {
    final session = await start(const [_photo]);
    final player = await openPlayer(session.sessionId);
    final controller = container.read(
      routinePlayerProvider(session.sessionId).notifier,
    );
    await controller.attachProof('/tmp/a.jpg');
    final asset = player.read().proofAssets.single;
    calls.single.answer.complete(null);
    await pumpEventQueue();
    final failed = player.read().aiDescriptionFor(asset)!;
    expect(failed.failed, isTrue);
    expect(failed.canRetry, isTrue);
    expect(calls, hasLength(1), reason: 'never retried on its own');

    controller.retryAiDescription(asset.proofId);
    expect(player.read().aiDescriptionFor(asset)!.isPending, isTrue);
    expect(calls, hasLength(2));
    expect(calls.first.key, asset.proofId);
    expect(calls.last.key, isNot(asset.proofId));
    expect(calls.last.key, startsWith('${asset.proofId}-r2'));
    expect(RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(calls.last.key), isTrue);

    calls.last.answer.complete('Four dials with the marker at the top.');
    await pumpEventQueue();
    expect(
      player.read().aiDescriptionFor(asset)!.text,
      'Four dials with the marker at the top.',
    );
    expect(
      await storedDescription(session.sessionId),
      'Four dials with the marker at the top.',
    );
  });

  test('a refusal says why and offers no retry', () async {
    final session = await start(const [_photo]);
    final player = await openPlayer(session.sessionId);
    final controller = container.read(
      routinePlayerProvider(session.sessionId).notifier,
    );
    await controller.attachProof('/tmp/a.jpg');
    final asset = player.read().proofAssets.single;
    calls.single.answer.completeError(
      const AiPhotoDescribeException(
        aiPhotoUnavailableMessage,
        reason: 'featureOff',
      ),
    );
    await pumpEventQueue();
    final failed = player.read().aiDescriptionFor(asset)!;
    expect(failed.failureMessage, aiPhotoUnavailableMessage);
    expect(failed.canRetry, isFalse);
    controller.retryAiDescription(asset.proofId);
    expect(calls, hasLength(1));
  });

  test('server reasons that a retry cannot fix get their own line', () {
    expect(aiPhotoRefusalMessage('featureOff'), aiPhotoUnavailableMessage);
    expect(aiPhotoRefusalMessage('budgetExhausted'), aiPhotoUnavailableMessage);
    expect(aiPhotoRefusalMessage('noActiveEntitlement'), isNotNull);
    expect(aiPhotoRefusalMessage('noConsent'), isNotNull);
    expect(aiPhotoRefusalMessage('duplicate'), isNull);
    expect(aiPhotoRefusalMessage('couldNotDescribe'), isNull);
    expect(aiPhotoRefusalMessage('failed'), isNull);
  });

  test('opening a finished run shows its completion, never an error', () async {
    final session = await start(const [_photo]);
    final player = await openPlayer(session.sessionId);
    final controller = container.read(
      routinePlayerProvider(session.sessionId).notifier,
    );
    await controller.attachProof('/tmp/a.jpg');
    final run = await controller.completeCurrentStep();
    player.close();
    container.invalidate(routinePlayerProvider(session.sessionId));
    await pumpEventQueue();

    final reopened = container.listen(
      routinePlayerProvider(session.sessionId),
      (_, _) {},
    );
    await pumpEventQueue();
    expect(reopened.read().screenPhase, RoutinePlayerScreenPhase.completion);
    expect(reopened.read().errorMessage, isNull);
    expect(reopened.read().completionSummary!.run.id, run!.id);
  });

  test('a stale active snapshot cannot reopen a finished run', () async {
    final session = await start(const [_plain]);
    final player = await openPlayer(session.sessionId);
    final stale = player.read().session!;
    await container
        .read(routinePlayerProvider(session.sessionId).notifier)
        .completeCurrentStep();
    final saved = await repository.saveSessionSnapshot(stale);
    expect(saved.status, RoutineSessionStatus.completed);
    expect(
      (await repository.getSessionById(session.sessionId))!.status,
      RoutineSessionStatus.completed,
    );
  });

  test('starting the same routine twice at once gives one session', () async {
    final routine = _routine(const [_photo, _plain]);
    await database.routineDao.insertOrUpdateRoutine(routine);
    const context = SessionRoutingContext(
      storageScope: SessionStorageScope.localOnly,
    );
    final sessions = await Future.wait([
      for (var i = 0; i < 3; i++)
        repository.startOrResumeSession(
          routine: routine,
          routingContext: context,
        ),
    ]);
    expect(sessions.map((s) => s.sessionId).toSet(), hasLength(1));
  });

  test('an unchanged sign-in is equal, so nothing downstream rebuilds', () {
    const a = AuthSessionSummary(
      isSignedIn: true,
      userId: _userId,
      email: 'a@b.c',
      provider: 'google',
    );
    const b = AuthSessionSummary(
      isSignedIn: true,
      userId: _userId,
      email: 'a@b.c',
      provider: 'google',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    var notified = 0;
    container.listen(aiPhotoActiveRoutineIdsProvider, (_, _) => notified++);
    container.read(_resumeTick.notifier).state++;
    container.read(aiPhotoActiveRoutineIdsProvider);
    expect(notified, 0);
    expect(container.read(aiPhotoActiveRoutineIdsProvider), {1});
  });
}
