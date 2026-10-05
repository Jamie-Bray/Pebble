import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_ui.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

import '../../support/premium_policy_test_utils.dart';

const _userId = '11111111-1111-1111-1111-111111111111';

class _FakeAiService extends AiPhotoService {
  _FakeAiService() : super(null);

  final consents = <String>[];
  int withdrawals = 0;
  Object? consentError;
  bool withdrawFails = false;

  @override
  Future<void> recordConsent({required String routineKey}) async {
    final error = consentError;
    if (error != null) throw error;
    consents.add(routineKey);
  }

  @override
  Future<void> withdrawConsent() async {
    if (withdrawFails) throw const AiPhotoException('offline');
    withdrawals += 1;
  }
}

class _FakeGuidanceAudioStorage implements GuidanceAudioStorage {
  @override
  Future<String> prepareRecordingPath() async => '';
  @override
  Future<String> resolveStoredPath(String localPath) async => '';
  @override
  Future<void> deleteStoredAudio(String localPath) async {}
  @override
  Future<void> cleanupOrphanedAudio(Set<String> activeLocalPaths) async {}
  @override
  Future<StepGuidanceAudio> createMetadataForRecordedFile({
    required String absolutePath,
    required Duration duration,
    String mimeType = 'audio/wav',
  }) async => StepGuidanceAudio(localPath: absolutePath, durationMs: 0);
}

class _FakeProofStorage implements RoutineSessionProofStorage {
  int _count = 0;

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    _count += 1;
    return RoutineSessionProofAsset(
      proofId: 'proof-$_count',
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

const _unlocked = RoutineLimitPolicy(
  hasPremiumRoutineAccess: true,
  isInGrace: false,
);

Routine _routine(int id, String title, List<RoutineStep> steps) => Routine(
  id: id,
  title: title,
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

const _photo = RoutineStep.check(label: 'Front door', requiresPhoto: true);
const _plain = RoutineStep.check(label: 'Keys in bag');

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('wording and versions', () {
    test('the app and the server expect the same consent version', () {
      final server = File(
        'supabase/functions/_shared/ai_photo.ts',
      ).readAsStringSync();
      expect(
        server,
        contains("AI_PHOTO_CONSENT_VERSION = '$aiPhotoConsentVersion'"),
      );
    });

    test(
      'the consent sheet names the provider, what it keeps and the limits',
      () {
        final body = aiPhotoConsentBody.join(' ');
        expect(
          aiPhotoConsentTitle('Leaving the house'),
          'Use AI on "Leaving the house"?',
        );
        expect(body, contains('Anthropic, an AI company in the USA'));
        expect(body, contains(aiPhotoRetentionSentence));
        expect(body, contains('deletes it within 30 days'));
        expect(body, contains("doesn't use it to train its AI"));
        expect(body, contains('Nothing else is sent.'));
        expect(body, contains('The description can be wrong.'));
        expect(body, contains('you can turn it off any time'));
        expect(aiPhotoConsentCheckLabel, contains('Anthropic'));
        // The app is for ages 13 and over; no age wording belongs here.
        expect(
          '$body $aiPhotoConsentCheckLabel $aiPhotoOnDetail',
          isNot(contains('18')),
        );
      },
    );

    test('the provider is named in one file only', () {
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('ai_photo_constants.dart'))
          .where((file) => file.readAsStringSync().contains('Anthropic'))
          .map((file) => file.path)
          .toList();
      expect(offenders, isEmpty);
    });
  });

  group('which photo steps use AI', () {
    test('photo steps only', () {
      expect(aiPhotoStepIndexes(const [_plain, _photo, _plain, _photo]), {
        1,
        3,
      });
      expect(aiPhotoStepIndexes(const [_plain]), isEmpty);
    });

    test('the first five photo steps, in order, when there are more', () {
      final steps = [for (var i = 0; i < 8; i++) _photo, _plain];
      expect(aiPhotoStepIndexes(steps), {0, 1, 2, 3, 4});
      expect(aiPhotoStepIndexes([_plain, ...steps]), {1, 2, 3, 4, 5});
      expect(photoStepCount(steps), 8);
    });

    test('the settings row says so plainly', () {
      final many = _routine(1, 'Lock up', [for (var i = 0; i < 7; i++) _photo]);
      final few = _routine(2, 'Bag', const [_photo, _plain]);
      final onForMany = AiPhotoSettings(
        routineId: 1,
        routineTitle: 'Lock up',
        consentVersion: aiPhotoConsentVersion,
        consentedAt: DateTime(2026, 10, 5),
      );
      String subtitle(
        Routine routine, {
        AiPhotoSettings? settings,
        bool premium = true,
        bool server = true,
      }) => aiPhotoRowSubtitle(
        settings: settings ?? onForMany,
        routine: routine,
        hasPremium: premium,
        serverEnabled: server,
      );
      expect(subtitle(many), 'On for the first 5 of 7 photo steps');
      expect(subtitle(few), 'On for "Lock up"');
      expect(subtitle(few, settings: AiPhotoSettings.off), 'Off');
      expect(subtitle(many, server: false), 'Unavailable right now');
      expect(
        subtitle(few, premium: false),
        'Describe your photos, with Premium',
      );
    });
  });

  group('switching on and off', () {
    late SharedPreferences prefs;
    late _FakeAiService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = _FakeAiService();
    });

    AiPhotoController controller({String? userId = _userId}) =>
        AiPhotoController(
          prefs: prefs,
          service: service,
          userId: userId,
          clock: () => DateTime.utc(2026, 10, 5, 8, 2),
        );

    test('off by default', () {
      final c = controller();
      expect(c.state.isOn, isFalse);
      expect(c.state.isOnFor(1), isFalse);
    });

    test(
      'consent is recorded on the server, then on the phone with version and time',
      () async {
        final c = controller();
        await c.turnOn(
          routineId: 1,
          routineTitle: 'Lock up',
          routineKey: 'local:1',
        );

        expect(service.consents, ['local:1']);
        expect(c.state.isOnFor(1), isTrue);
        expect(c.state.consentVersion, aiPhotoConsentVersion);
        expect(c.state.consentedAt, DateTime.utc(2026, 10, 5, 8, 2));

        // Survives a restart.
        final restarted = controller();
        expect(restarted.state.isOnFor(1), isTrue);
        expect(restarted.state.consentedAt, DateTime.utc(2026, 10, 5, 8, 2));
      },
    );

    test('if the server cannot record consent, AI stays off', () async {
      service.consentError = const AiPhotoException('offline');
      final c = controller();
      await expectLater(
        c.turnOn(routineId: 1, routineTitle: 'Lock up', routineKey: 'local:1'),
        throwsA(isA<AiPhotoException>()),
      );
      expect(c.state.isOn, isFalse);
      expect(controller().state.isOn, isFalse);
    });

    test('one routine at a time: turning it on for another moves it', () async {
      final c = controller();
      await c.turnOn(
        routineId: 1,
        routineTitle: 'Lock up',
        routineKey: 'local:1',
      );
      await c.setEmailDescriptions(true);
      await c.turnOn(routineId: 2, routineTitle: 'Bag', routineKey: 'local:2');

      expect(c.state.isOnFor(1), isFalse);
      expect(c.state.isOnFor(2), isTrue);
      expect(c.state.routineTitle, 'Bag');
      expect(service.consents, ['local:1', 'local:2']);
      // The email choice belonged to the other routine and is asked again.
      expect(c.state.emailDescriptions, isNull);
    });

    test('turning off stops at once and records the withdrawal', () async {
      final c = controller();
      await c.turnOn(
        routineId: 1,
        routineTitle: 'Lock up',
        routineKey: 'local:1',
      );
      await c.turnOff();
      expect(c.state.isOn, isFalse);
      expect(service.withdrawals, 1);
      expect(c.state.withdrawalPending, isFalse);
    });

    test(
      'a withdrawal that could not reach the server is sent on the next start',
      () async {
        final c = controller();
        await c.turnOn(
          routineId: 1,
          routineTitle: 'Lock up',
          routineKey: 'local:1',
        );
        service.withdrawFails = true;
        await c.turnOff();
        expect(
          c.state.isOn,
          isFalse,
          reason: 'sending stops whatever the server says',
        );
        expect(c.state.withdrawalPending, isTrue);

        service.withdrawFails = false;
        final restarted = controller();
        await _tick();
        await _tick();
        expect(service.withdrawals, 1);
        expect(restarted.state.withdrawalPending, isFalse);
      },
    );

    test('a consent to older wording counts as off', () async {
      await prefs.setString(
        'pebble.ai_photo.$_userId',
        jsonEncode(
          const AiPhotoSettings(
            routineId: 1,
            consentVersion: '2020-01-01',
          ).toJson(),
        ),
      );
      expect(controller().state.isOn, isFalse);
    });

    test('signed out, or another account, has nothing switched on', () async {
      await controller().turnOn(
        routineId: 1,
        routineTitle: 'Lock up',
        routineKey: 'local:1',
      );
      expect(controller(userId: null).state.isOn, isFalse);
      expect(controller(userId: 'someone-else').state.isOn, isFalse);
    });

    test('email descriptions: no answer until the person gives one', () async {
      final c = controller();
      await c.setEmailDescriptions(true);
      expect(
        c.state.emailDescriptions,
        isNull,
        reason: 'nothing to set while AI is off',
      );
      await c.turnOn(
        routineId: 1,
        routineTitle: 'Lock up',
        routineKey: 'local:1',
      );
      expect(c.state.emailDescriptions, isNull);
      await c.setEmailDescriptions(false);
      expect(c.state.emailDescriptions, isFalse);
      await c.setEmailDescriptions(true);
      expect(controller().state.emailDescriptions, isTrue);
    });

    test(
      'Premium gate: nothing is described without Personal Premium',
      () async {
        await controller().turnOn(
          routineId: 1,
          routineTitle: 'Lock up',
          routineKey: 'local:1',
        );
        int? activeFor(UserTier tier) {
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              aiPhotoServiceProvider.overrideWithValue(service),
              authSessionProvider.overrideWithValue(
                const AuthSessionSummary(
                  isSignedIn: true,
                  userId: _userId,
                  email: 'a@b.c',
                  provider: 'google',
                ),
              ),
              premiumFeaturePolicyProvider.overrideWithValue(
                premiumFeaturePolicyForTier(tier),
              ),
            ],
          );
          addTearDown(container.dispose);
          return container.read(aiPhotoActiveRoutineIdProvider);
        }

        expect(activeFor(UserTier.personalPremium), 1);
        expect(activeFor(UserTier.personalFree), isNull);
      },
    );
  });

  group('describing a photo during a routine', () {
    late LocalDb database;
    late ProviderContainer container;
    late RoutineSessionRepository repository;
    late RoutineSession session;

    Future<void> start(List<RoutineStep> steps) async {
      final routine = _routine(1, 'Lock up', steps);
      await database.routineDao.insertOrUpdateRoutine(routine);
      session = await repository.startOrResumeSession(
        routine: routine,
        routingContext: const SessionRoutingContext(
          storageScope: SessionStorageScope.localOnly,
        ),
      );
    }

    setUp(() {
      database = LocalDb.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          routineSessionProofStorageProvider.overrideWithValue(
            _FakeProofStorage(),
          ),
          guidanceAudioStorageProvider.overrideWithValue(
            _FakeGuidanceAudioStorage(),
          ),
          subscriptionAccountControllerProvider.overrideWith(
            (ref) => SubscriptionAccountController(database, loadOnInit: false),
          ),
        ],
      );
      repository = container.read(routineSessionRepositoryProvider);
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    Future<RoutinePlayerController> player({
      required AiProofDescriber? describe,
      int? aiRoutineId = 1,
    }) async {
      final controller = RoutinePlayerController(
        sessionId: session.sessionId,
        repository: repository,
        proofStorage: _FakeProofStorage(),
        maxProofPhotosPerStep: 4,
        routineLimitPolicy: _unlocked,
        aiRoutineId: aiRoutineId,
        describeProof: describe,
      );
      addTearDown(controller.dispose);
      await _tick();
      await _tick();
      expect(controller.state.screenPhase, RoutinePlayerScreenPhase.ready);
      return controller;
    }

    Future<RoutineSessionProofAsset> savedProof(String proofId) async {
      final saved = await repository.getSessionById(session.sessionId);
      return saved!.stepStates
          .expand((s) => s.proofAssets)
          .firstWhere((a) => a.proofId == proofId);
    }

    test(
      'the step is complete as soon as the photo is saved; the description arrives later',
      () async {
        await start(const [_photo, _plain]);
        final answer = Completer<String?>();
        final asked = <String>[];
        final controller = await player(
          describe: (asset) {
            asked.add(asset.proofId);
            return answer.future;
          },
        );

        expect(
          await controller.attachProof('/tmp/a.jpg'),
          RoutinePlayerProofAttachResult.attached,
        );
        expect(asked, ['proof-1']);
        final asset = controller.state.proofAssets.single;
        expect(controller.state.aiDescriptionFor(asset)!.isPending, isTrue);

        // Nothing waits on the description.
        expect(controller.state.hasEnoughPhotos, isTrue);
        expect(controller.state.isPrimaryEnabled, isTrue);
        expect(controller.state.isForegroundBusy, isFalse);
        await controller.completeCurrentStep();
        expect(controller.state.currentStepIndex, 1);
        expect(
          controller.state.session!.stepStates[0].status,
          SessionStepStatus.completed,
        );

        answer.complete('A white door with the handle pointing up.');
        await _tick();
        await _tick();
        await pumpEventQueue();

        expect(
          controller.state.aiDescriptionFor(asset)!.text,
          'A white door with the handle pointing up.',
        );
        expect(
          (await savedProof('proof-1')).aiDescription,
          'A white door with the handle pointing up.',
        );
        // The step it belonged to is exactly as the person left it.
        expect(
          controller.state.session!.stepStates[0].status,
          SessionStepStatus.completed,
        );
        expect(controller.state.currentStepIndex, 1);
      },
    );

    test(
      'a failure shows the quiet line once, never retries and never blocks or undoes the step',
      () async {
        await start(const [_photo, _plain]);
        var calls = 0;
        final controller = await player(
          describe: (_) async {
            calls += 1;
            throw const SocketException('offline');
          },
        );

        await controller.attachProof('/tmp/a.jpg');
        await pumpEventQueue();
        final asset = controller.state.proofAssets.single;
        expect(controller.state.aiDescriptionFor(asset)!.failed, isTrue);
        expect(
          controller.state.errorMessage,
          isNull,
          reason: 'not an error the person has to deal with',
        );
        expect(controller.state.isPrimaryEnabled, isTrue);

        await controller.completeCurrentStep();
        final run = await controller.completeCurrentStep();
        await pumpEventQueue();
        expect(
          run,
          isNotNull,
          reason: 'the routine finishes without a description',
        );
        expect(calls, 1, reason: 'no retry loop');
        expect((await savedProof('proof-1')).aiDescription, isNull);
      },
    );

    test(
      'a description that lands after the routine finished is saved onto the run',
      () async {
        await start(const [_photo]);
        final answer = Completer<String?>();
        final controller = await player(describe: (_) => answer.future);

        await controller.attachProof('/tmp/a.jpg');
        final run = await controller.completeCurrentStep();
        expect(run, isNotNull);
        expect(run!.stepCompletionData, isNot(contains('aiDescription')));

        answer.complete('A blue bag on a wooden chair.');
        await pumpEventQueue();

        final stored = await database.routineRunDao.getRunById(run.id);
        final data = jsonDecode(stored!.stepCompletionData!) as Map;
        final step = (data['steps'] as List).single as Map;
        final asset = (step['proofAssets'] as List).single as Map;
        expect(asset['aiDescription'], 'A blue bag on a wooden chair.');
        // And it is read back as part of the photo, as History and restore do.
        expect(
          RoutineSessionProofAsset.fromJson(
            Map<String, dynamic>.from(asset),
          ).aiDescription,
          'A blue bag on a wooden chair.',
        );
      },
    );

    test(
      'a description that lands before finishing travels into the run',
      () async {
        await start(const [_photo]);
        final controller = await player(
          describe: (_) async => 'Four dials with the marker at the top.',
        );
        await controller.attachProof('/tmp/a.jpg');
        await pumpEventQueue();
        final run = await controller.completeCurrentStep();
        expect(
          run!.stepCompletionData,
          contains('Four dials with the marker at the top.'),
        );
      },
    );

    test(
      'nothing is sent when AI is off, on for another routine, or past the fifth photo step',
      () async {
        await start([for (var i = 0; i < 6; i++) _photo, _plain]);
        var calls = 0;
        Future<String?> describe(RoutineSessionProofAsset _) async {
          calls += 1;
          return 'A door.';
        }

        final off = await player(describe: describe, aiRoutineId: null);
        await off.attachProof('/tmp/a.jpg');
        await pumpEventQueue();
        expect(calls, 0);
        expect(
          off.state.aiDescriptionFor(off.state.proofAssets.single),
          isNull,
        );

        final other = await player(describe: describe, aiRoutineId: 99);
        await other.attachProof('/tmp/b.jpg');
        await pumpEventQueue();
        expect(calls, 0);

        final on = await player(describe: describe);
        for (var step = 0; step < 6; step++) {
          expect(on.state.currentStepIndex, step);
          if (step > 0) await on.attachProof('/tmp/c$step.jpg');
          await pumpEventQueue();
          await on.completeCurrentStep();
        }
        // Step 1 already had its photos from the runs above (taken with AI
        // off), steps 2 to 5 were described, step 6 is past the cap.
        expect(calls, 4);
      },
    );

    test(
      'removing the photo removes its description, and a late answer is dropped',
      () async {
        await start(const [_photo, _plain]);
        final answer = Completer<String?>();
        final controller = await player(describe: (_) => answer.future);
        await controller.attachProof('/tmp/a.jpg');
        await controller.removeProof('proof-1');
        answer.complete('A white door.');
        await pumpEventQueue();
        final saved = await repository.getSessionById(session.sessionId);
        expect(saved!.stepStates.expand((s) => s.proofAssets), isEmpty);
      },
    );

    test(
      'descriptions for the completion email: AI steps only, in order, at most five',
      () async {
        await start([for (var i = 0; i < 3; i++) _photo]);
        var n = 0;
        final slow = Completer<String?>();
        final controller = await player(
          describe: (_) => ++n == 3 ? slow.future : Future.value('Photo $n.'),
        );
        for (var step = 0; step < 3; step++) {
          await controller.attachProof('/tmp/a$step.jpg');
          await controller.attachProof('/tmp/b$step.jpg');
          await pumpEventQueue();
          if (step < 2) await controller.completeCurrentStep();
        }
        // One is still on its way: the email waits a moment for it.
        final pending = controller.aiDescriptionsForEmail();
        slow.complete('Photo 3.');
        expect(await pending, [
          'Photo 1.',
          'Photo 2.',
          'Photo 3.',
          'Photo 4.',
          'Photo 5.',
        ]);

        // If it never arrives, the email goes without it.
        final never = Completer<String?>();
        await start(const [_photo]);
        final stuck = await player(describe: (_) => never.future);
        await stuck.attachProof('/tmp/z.jpg');
        expect(
          await stuck.aiDescriptionsForEmail(
            timeout: const Duration(milliseconds: 20),
          ),
          isEmpty,
        );
      },
    );
  });

  group('saved with the photo', () {
    final asset = RoutineSessionProofAsset(
      proofId: 'p1',
      localRelativePath: 'proofs/s/p1.webp',
      remoteObjectKey: 'users/u/run/r/p1.webp',
      uploadStatus: ProofUploadStatus.uploaded,
      capturedAt: DateTime.utc(2026, 10, 5, 8, 2),
    );

    test(
      'rows saved or backed up without a description read and write unchanged',
      () {
        final json = asset.toJson();
        expect(json.containsKey('aiDescription'), isFalse);
        expect(RoutineSessionProofAsset.fromJson(json).aiDescription, isNull);
        expect(RoutineSessionProofAsset.fromJson(json).toJson(), json);
      },
    );

    test('a description survives the backup and restore round trip', () {
      final described = asset.copyWith(
        aiDescription: 'A white door with the handle up.',
      );
      // Upload marks the asset as backed up without losing the description.
      final uploaded = described.copyWith(
        uploadStatus: ProofUploadStatus.uploaded,
      );
      final session = RoutineSessionStepState(
        stepIndex: 0,
        status: SessionStepStatus.completed,
        completedAt: DateTime.utc(2026, 10, 5, 8, 2),
        proofAssets: [uploaded],
      );
      final restored = RoutineSessionStepState.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
      );
      expect(
        restored.proofAssets.single.aiDescription,
        'A white door with the handle up.',
      );
      expect(
        RoutineSessionProofAsset.fromJson({
          ...asset.toJson(),
          'aiDescription': '  ',
        }).aiDescription,
        isNull,
      );
    });
  });

  group('completion email', () {
    Map<String, dynamic> body({List<String> descriptions = const []}) =>
        completionRequestBody(
          routineKey: 'local:1',
          routineTitle: 'Lock up',
          runId: 'run-1',
          sessionId: 'session-1',
          completedAt: DateTime.utc(2026, 10, 5, 8, 2),
          completedSteps: 4,
          totalSteps: 4,
          descriptions: descriptions,
        );

    test('descriptions are sent only when there are some to add', () {
      expect(body().containsKey('descriptions'), isFalse);
      expect(body(descriptions: ['A white door.'])['descriptions'], [
        'A white door.',
      ]);
    });

    test('nothing about a photo is in the request', () {
      final keys = body(descriptions: ['A white door.']).keys.toSet();
      expect(
        keys.where(
          (key) =>
              key.toLowerCase().contains('photo') ||
              key.toLowerCase().contains('image'),
        ),
        isEmpty,
      );
    });
  });

  group('sheets', () {
    Future<void> open(
      WidgetTester tester,
      Future<void> Function(BuildContext) show,
    ) async {
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'consent: Turn on is disabled until the box is checked; closing is not consent',
      (tester) async {
        bool? result;
        await open(tester, (context) async {
          result = await showAiPhotoConsentSheet(
            context,
            routineName: 'Leaving the house',
          );
        });

        expect(find.text('Use AI on "Leaving the house"?'), findsOneWidget);
        expect(find.text(aiPhotoConsentCheckLabel), findsOneWidget);
        expect(find.text(aiPhotoHowItWorksLabel), findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse,
        );
        FilledButton turnOn() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Turn on'),
        );
        expect(turnOn().onPressed, isNull);

        await tester.ensureVisible(find.text(aiPhotoConsentCheckLabel));
        await tester.tap(find.text(aiPhotoConsentCheckLabel));
        await tester.pumpAndSettle();
        expect(turnOn().onPressed, isNotNull);

        await tester.ensureVisible(find.text('Not now'));
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      },
    );

    testWidgets('consent: checking the box then Turn on returns true', (
      tester,
    ) async {
      bool? result;
      await open(tester, (context) async {
        result = await showAiPhotoConsentSheet(
          context,
          routineName: 'Bag',
          photoSteps: 7,
        );
      });
      expect(
        find.textContaining('This routine has 7 photo steps'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text(aiPhotoConsentCheckLabel));
      await tester.tap(find.text(aiPhotoConsentCheckLabel));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Turn on'));
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets(
      'email question: two equal buttons, neither preselected, no answer if closed',
      (tester) async {
        bool? result = false;
        var answered = false;
        await open(tester, (context) async {
          result = await showAiPhotoEmailQuestionSheet(
            context,
            contactEmail: 'sam@example.com',
          );
          answered = true;
        });

        expect(
          find.text('Add the descriptions to the completion email?'),
          findsOneWidget,
        );
        expect(find.textContaining('sam@example.com'), findsOneWidget);
        expect(
          find.textContaining('The photos are never emailed.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Add descriptions'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, "Don't add"),
          findsOneWidget,
        );
        expect(
          find.byType(FilledButton),
          findsNothing,
          reason: 'no highlighted default',
        );
        expect(find.byType(Checkbox), findsNothing);
        expect(find.byType(Switch), findsNothing);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(answered, isTrue);
        expect(result, isNull);
      },
    );

    testWidgets('email question: Add descriptions returns true', (
      tester,
    ) async {
      bool? result;
      await open(tester, (context) async {
        result = await showAiPhotoEmailQuestionSheet(
          context,
          contactEmail: 'sam@example.com',
        );
      });
      await tester.tap(find.text('Add descriptions'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets(
      'a description is labelled as AI and read out as one sentence',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AiDescriptionText('A white door with the handle up.'),
            ),
          ),
        );
        expect(find.text('AI DESCRIPTION'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'AI description: A white door with the handle up.',
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });

  test('resize bounds keep the longest side at 1,000 px', () {
    expect(aiPhotoResizeBounds(800, 1067), (minWidth: 1, minHeight: 1000));
    expect(aiPhotoResizeBounds(1422, 800), (minWidth: 1000, minHeight: 1));
    // The compressor scales by min(width / minWidth, height / minHeight).
    double scale(int w, int h) {
      final b = aiPhotoResizeBounds(w, h);
      final s = [
        w / b.minWidth,
        h / b.minHeight,
      ].reduce((a, c) => a < c ? a : c);
      return s < 1 ? 1 : s;
    }

    expect(800 / scale(800, 1733), closeTo(461.6, 0.1));
    expect(1733 / scale(800, 1733), closeTo(1000, 0.01));
    expect(scale(640, 480), 1, reason: 'small photos are not enlarged');
  });
}
