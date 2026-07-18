import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_player_screen.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/premium_policy_test_utils.dart';

const _unlockedRoutinePolicy = RoutineLimitPolicy(
  hasPremiumRoutineAccess: true,
  isInGrace: false,
);
const _pendingCameraCapturePrefsKey = 'routine_player_pending_camera_capture';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPlayer(
    WidgetTester tester,
    RoutineStep step,
    _FakeRoutineSessionRepository repository, {
    UserTier tier = UserTier.personalPremium,
    RoutinePlayerPhotoPicker? photoPicker,
    RoutineSessionProofStorage proofStorage = const _FakeProofStorage(),
    RoutineSession? session,
    bool settle = true,
  }) async {
    repository.session = session ?? _sessionForStep(step);
    final prefs = await SharedPreferences.getInstance();
    final overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      routineSessionRepositoryProvider.overrideWithValue(repository),
      routineSessionProofStorageProvider.overrideWithValue(proofStorage),
      guidanceAudioStorageProvider.overrideWithValue(
        const _FakeGuidanceAudioStorage(),
      ),
      subscriptionProvider.overrideWithValue(tier),
      premiumFeaturePolicyProvider.overrideWithValue(
        premiumFeaturePolicyForTier(tier),
      ),
      currentThemeDataProvider.overrideWithValue(
        AppTheme.fromId(ThemeId.nordicNight),
      ),
      if (photoPicker != null)
        routinePlayerPhotoPickerProvider.overrideWithValue(photoPicker),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: RoutinePlayerScreen(sessionId: 'session-1'),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('text-only steps show no guidance audio control', (tester) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Lock the door'),
      repository,
    );

    expect(find.text('Play guidance'), findsNothing);
    expect(find.text('Voice tip'), findsNothing);
  });

  testWidgets('text step renders centered redesign surface', (tester) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Lock the door'),
      repository,
    );

    expect(find.text('TEST ROUTINE'), findsOneWidget);
    expect(find.text('Step 1 of 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Text Step'), findsNothing);
    expect(find.text('Lock the door'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Finish routine'), findsOneWidget);
    expect(find.byType(AnimatedVisualAnchor), findsOneWidget);
  });

  testWidgets('steps with guidance audio show a play control', (tester) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(
        label: 'Check the latch',
        guidanceAudio: StepGuidanceAudio(
          localPath: 'routine_guidance_audio/latch.m4a',
          durationMs: 3000,
          mimeType: 'audio/mp4',
          byteSize: 1200,
        ),
      ),
      repository,
    );

    expect(find.text('Voice tip'), findsOneWidget);
    expect(find.text('A short reminder for this step'), findsOneWidget);
    expect(find.text('Play guidance'), findsOneWidget);
  });

  testWidgets('guidance audio does not block completion', (tester) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(
        label: 'Listen and complete',
        guidanceAudio: StepGuidanceAudio(
          localPath: 'routine_guidance_audio/listen.m4a',
          durationMs: 2500,
          mimeType: 'audio/mp4',
          byteSize: 1000,
        ),
      ),
      repository,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Finish routine'));
    await tester.pumpAndSettle();

    expect(repository.completedSession, isNotNull);
    expect(find.text('Routine complete'), findsOneWidget);
  });

  testWidgets('completion screen summarizes routine and wires actions', (
    tester,
  ) async {
    var wentHome = false;
    var reviewedRoutine = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RoutineCompleteScreen(
          routineName: 'Evening close down',
          totalStepsCompleted: 4,
          totalPhotosSaved: 2,
          onBackToHome: () => wentHome = true,
          onReviewRoutine: () => reviewedRoutine = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Routine complete'), findsOneWidget);
    expect(find.text('Evening close down'), findsOneWidget);
    expect(find.text('SUMMARY'), findsOneWidget);
    expect(find.text('Steps Completed'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Evidence Saved'), findsOneWidget);
    expect(find.text('2 Photos'), findsOneWidget);

    await tester.tap(find.text('Back to Home'));
    expect(wentHome, isTrue);

    await tester.tap(find.text('Review Routine'));
    expect(reviewedRoutine, isTrue);
  });

  testWidgets('add tile opens camera directly without the source sheet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_camera_rationale': true});
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(returnedPath: '/tmp/camera.jpg');
    await pumpPlayer(
      tester,
      const RoutineStep.check(
        label: 'Photo proof',
        requiresPhoto: true,
        allowGallery: true,
      ),
      repository,
      photoPicker: photoPicker,
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(photoPicker.sources, [ImageSource.camera]);
    expect(repository.session?.stepStates.single.proofAssets, hasLength(1));
  });

  testWidgets(
    'photo step shows the proof card, gated complete, and no anchor',
    (tester) async {
      final repository = _FakeRoutineSessionRepository();
      const photoStep = RoutineStep.check(
        label: 'Photo proof',
        requiresPhoto: true,
        allowGallery: true,
      );
      await pumpPlayer(
        tester,
        photoStep,
        repository,
        // A following step keeps this off the final step so the primary button
        // reads "Complete step" (the mockup's step-1-of-many scenario).
        session: _sessionForSteps(const [
          photoStep,
          RoutineStep.check(label: 'Next step'),
        ]),
      );

      expect(find.byType(AnimatedVisualAnchor), findsNothing);
      expect(find.text('Proof photo'), findsOneWidget);
      expect(find.text('Required to complete this step'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Choose from library'), findsOneWidget);

      // Complete stays disabled until a photo exists.
      final complete = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Complete step'),
      );
      expect(complete.onPressed, isNull);
    },
  );

  testWidgets('gallery link is hidden when gallery is not allowed', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(
        label: 'Camera only',
        requiresPhoto: true,
        allowGallery: false,
      ),
      repository,
    );

    expect(find.text('Choose from library'), findsNothing);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('gallery link opens the gallery picker', (tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_gallery_rationale': true,
    });
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(returnedPath: '/tmp/gallery.jpg');
    await pumpPlayer(
      tester,
      const RoutineStep.check(
        label: 'Photo proof',
        requiresPhoto: true,
        allowGallery: true,
      ),
      repository,
      photoPicker: photoPicker,
    );

    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    expect(photoPicker.sources, [ImageSource.gallery]);
    expect(repository.session?.stepStates.single.proofAssets, hasLength(1));
  });

  testWidgets('primary action waits for anchor animation before completing', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Wait for it'),
      repository,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Finish routine'));
    await tester.pump();

    expect(repository.completedSession, isNull);

    await tester.pump(const Duration(milliseconds: 399));
    expect(repository.completedSession, isNull);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.completedSession, isNotNull);
  });

  testWidgets('anchor resets after advancing to the next text step', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    repository.session = _sessionForSteps(const [
      RoutineStep.check(label: 'Step one'),
      RoutineStep.check(label: 'Step two'),
    ]);

    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Ignored'),
      repository,
      session: repository.session,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Step two'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsNothing);
    expect(find.byType(AnimatedVisualAnchor), findsOneWidget);
  });

  testWidgets(
    'primary action skips anchor wait when transitions are disabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({'enableTransitions': false});
      final repository = _FakeRoutineSessionRepository();
      await pumpPlayer(
        tester,
        const RoutineStep.check(label: 'No wait'),
        repository,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Finish routine'));
      await tester.pump();

      expect(repository.completedSession, isNotNull);
    },
  );

  testWidgets('showVisualAnchor false hides anchor but keeps content/actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'showVisualAnchor': false});
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Still centered'),
      repository,
    );

    expect(find.byType(AnimatedVisualAnchor), findsNothing);
    expect(find.text('Still centered'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Finish routine'), findsOneWidget);
  });

  testWidgets('denied camera permission shows a settings hint', (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_camera_rationale': true});
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(
      returnedPath: '/tmp/unused.jpg',
      pickError: PlatformException(code: 'camera_access_denied'),
    );
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Photo proof', requiresPhoto: true),
      repository,
      photoPicker: photoPicker,
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Camera access is turned off for Pebble'),
      findsOneWidget,
    );
    expect(find.text('OPEN SETTINGS'), findsOneWidget);
    expect(repository.session?.stepStates.single.proofAssets, isEmpty);

    // The capture gate must be released so the user can try again.
    expect(find.text('Add'), findsOneWidget);

    // Let the notification auto-dismiss so no timers are left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('lost camera photo is re-attached when the player restores', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(
      _pendingCameraCapturePrefs(capturedPhotoCount: 0),
    );
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(
      returnedPath: '/tmp/unused.jpg',
      lostPath: '/tmp/recovered.jpg',
    );
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Photo proof', requiresPhoto: true),
      repository,
      photoPicker: photoPicker,
    );

    expect(find.text('Proof photo'), findsOneWidget);
    expect(
      repository
          .session
          ?.stepStates
          .single
          .proofAssets
          .single
          .localRelativePath,
      '/tmp/recovered.jpg',
    );
  });

  testWidgets('lost camera photo is ignored when pending capture mismatches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(
      _pendingCameraCapturePrefs(stepIndex: 1),
    );
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(
      returnedPath: '/tmp/unused.jpg',
      lostPath: '/tmp/recovered.jpg',
    );
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Photo proof', requiresPhoto: true),
      repository,
      photoPicker: photoPicker,
    );

    expect(find.text('Proof photo'), findsOneWidget);
    expect(repository.session?.stepStates.single.proofAssets, isEmpty);
  });

  testWidgets('failed lost camera attach is handled and attaches nothing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(
      _pendingCameraCapturePrefs(capturedPhotoCount: 0),
    );
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(
      returnedPath: '/tmp/unused.jpg',
      lostPath: '/tmp/recovered.jpg',
    );

    // settle:false on purpose: a failed attach raises an auto-dismissing
    // notification whose animation never lets pumpAndSettle finish. Bounded
    // manual pumps drain the recovery's microtasks without that hang. The temp
    // is cleared unconditionally in code (unawaited _deletePickerTemp); here we
    // verify the failure is handled gracefully and nothing is attached.
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Photo proof', requiresPhoto: true),
      repository,
      photoPicker: photoPicker,
      proofStorage: const _FailingProofStorage(),
      settle: false,
    );
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(repository.session?.stepStates.single.proofAssets, isEmpty);

    // Unmount so the notification overlay/timer is disposed cleanly and no
    // pending timer leaks into the next test.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('free tier shows a quiet locked Premium tile at the cap', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    const step = RoutineStep.check(
      label: 'Photo proof',
      requiresPhoto: true,
      allowGallery: true,
    );
    await pumpPlayer(
      tester,
      step,
      repository,
      tier: UserTier.personalFree,
      session: _sessionForStepWithProofs(step, [_proofAsset('free-proof')]),
    );

    // At the free cap: locked signpost present, Add tile gone, and a quiet
    // subtitle names the gate.
    expect(find.text('Add more'), findsOneWidget);
    expect(find.text('More photos with Premium'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(find.text('Choose from library'), findsNothing);
  });

  testWidgets('tapping a proof thumbnail opens the step photo viewer', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    const step = RoutineStep.check(
      label: 'Photo proof',
      requiresPhoto: true,
      allowGallery: true,
    );
    await pumpPlayer(
      tester,
      step,
      repository,
      session: _sessionForStepWithProofs(step, [_proofAsset('proof-1')]),
    );

    await tester.tapAt(tester.getCenter(find.byIcon(LucideIcons.imageOff)));
    await tester.pumpAndSettle();

    expect(find.byType(PebblePhotoGalleryViewer), findsOneWidget);
    expect(find.text('Photo proof - Step 1 of 1'), findsOneWidget);
  });

  testWidgets('multi-photo requirements explain the remaining gate', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    const step = RoutineStep.check(
      label: 'Photo proof',
      requiresPhoto: true,
      photoCount: 2,
      allowGallery: true,
    );
    await pumpPlayer(
      tester,
      step,
      repository,
      session: _sessionForStepWithProofs(step, [_proofAsset('proof-1')]),
    );

    expect(find.text('1 more photo required'), findsOneWidget);
    final complete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Finish routine'),
    );
    expect(complete.onPressed, isNull);
  });

  testWidgets('premium at the cap shows a calm full subtitle, no upsell', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    const step = RoutineStep.check(
      label: 'Photo proof',
      requiresPhoto: true,
      allowGallery: true,
    );
    await pumpPlayer(
      tester,
      step,
      repository,
      session: _sessionForStepWithProofs(
        step,
        List.generate(4, (index) => _proofAsset('premium-proof-$index')),
      ),
    );

    expect(find.text('All 4 added'), findsOneWidget);
    expect(find.text('Add more'), findsNothing);
    expect(find.text('Add'), findsNothing);
    expect(find.text('Choose from library'), findsNothing);
  });

  test('photo attach repairs any stale in-flight lifecycle save', () async {
    final repository = _BlockingSaveRoutineSessionRepository(
      _sessionForStep(
        const RoutineStep.check(label: 'Take a photo', requiresPhoto: true),
      ),
    );
    final proofStorage = _CountingProofStorage();
    final controller = RoutinePlayerController(
      sessionId: 'session-1',
      repository: repository,
      proofStorage: proofStorage,
      maxProofPhotosPerStep: 1,
      routineLimitPolicy: _unlockedRoutinePolicy,
    );

    await Future<void>.delayed(Duration.zero);

    final progressSave = controller.persistCurrentProgress();
    await Future<void>.delayed(Duration.zero);
    expect(repository.pendingSaveCount, 1);

    final attach = controller.attachProof('/tmp/proof.jpg');
    await Future<void>.delayed(Duration.zero);
    expect(proofStorage.persistCount, 1);

    await attach;
    expect(proofStorage.persistCount, 1);
    expect(repository.session?.stepStates.single.proofAssets, hasLength(1));

    repository.releaseNextSave();
    await progressSave;

    expect(repository.session?.stepStates.single.proofAssets, hasLength(1));
  });

  test('double tapping complete does not queue into the next step', () async {
    final repository = _BlockingSaveRoutineSessionRepository(
      _sessionForSteps(const [
        RoutineStep.check(label: 'Step 1'),
        RoutineStep.check(label: 'Step 2'),
      ]),
    );
    final controller = RoutinePlayerController(
      sessionId: 'session-1',
      repository: repository,
      proofStorage: const _FakeProofStorage(),
      maxProofPhotosPerStep: 1,
      routineLimitPolicy: _unlockedRoutinePolicy,
    );

    await Future<void>.delayed(Duration.zero);

    final firstComplete = controller.completeCurrentStep();
    await Future<void>.delayed(Duration.zero);

    expect(repository.pendingSaveCount, 1);
    expect(controller.state.currentStepIndex, 1);
    expect(controller.state.activeOperation, RoutinePlayerOperation.savingStep);

    final secondComplete = await controller.completeCurrentStep();

    expect(secondComplete, isNull);
    expect(repository.pendingSaveCount, 1);

    repository.releaseNextSave();
    await firstComplete;

    final saved = repository.session!;
    expect(saved.currentStepIndex, 1);
    expect(saved.stepStates[0].status, SessionStepStatus.completed);
    expect(saved.stepStates[1].status, SessionStepStatus.pending);
  });

  test('foreground mutations no-op while saving a photo', () async {
    final repository = _FakeRoutineSessionRepository();
    repository.session = _sessionForSteps(const [
      RoutineStep.check(label: 'Photo step', requiresPhoto: true),
      RoutineStep.check(label: 'Next step'),
    ]);
    final controller = RoutinePlayerController(
      sessionId: 'session-1',
      repository: repository,
      proofStorage: const _FakeProofStorage(),
      maxProofPhotosPerStep: 1,
      routineLimitPolicy: _unlockedRoutinePolicy,
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.beginPhotoCapture(), isTrue);
    expect(
      controller.state.activeOperation,
      RoutinePlayerOperation.savingPhoto,
    );

    final completed = await controller.completeCurrentStep();
    await controller.previousStep();

    expect(completed, isNull);
    expect(controller.state.currentStepIndex, 0);
    expect(repository.session?.currentStepIndex, 0);

    controller.cancelPhotoCapture();
    expect(controller.state.activeOperation, RoutinePlayerOperation.none);
  });
}

RoutineSession _sessionForStep(RoutineStep step) {
  return _sessionForSteps([step]);
}

RoutineSession _sessionForStepWithProofs(
  RoutineStep step,
  List<RoutineSessionProofAsset> proofs,
) {
  final session = _sessionForStep(step);
  return session.copyWith(
    stepStates: [
      RoutineSessionStepState.initial(0).copyWith(proofAssets: proofs),
    ],
  );
}

RoutineSession _sessionForSteps(List<RoutineStep> steps) {
  return RoutineSession(
    sessionId: 'session-1',
    routineId: 1,
    routineTitleSnapshot: 'Test routine',
    workspaceId: null,
    ownerUserId: null,
    storageScope: SessionStorageScope.localOnly,
    startedAt: DateTime(2026, 4, 18, 9),
    updatedAt: DateTime(2026, 4, 18, 9),
    status: RoutineSessionStatus.active,
    currentStepIndex: 0,
    totalStepCount: steps.length,
    baseRoutineVersion: 1,
    routineSnapshotSteps: steps,
    stepStates: List.generate(steps.length, RoutineSessionStepState.initial),
    syncMetadata: null,
    completedAt: null,
    discardedAt: null,
  );
}

RoutineSessionProofAsset _proofAsset(String proofId) {
  return RoutineSessionProofAsset(
    proofId: proofId,
    localRelativePath: '/tmp/$proofId.jpg',
    remoteObjectKey: null,
    uploadStatus: ProofUploadStatus.localOnly,
    capturedAt: DateTime(2026, 4, 18),
  );
}

Map<String, Object> _pendingCameraCapturePrefs({
  String sessionId = 'session-1',
  int stepIndex = 0,
  int capturedPhotoCount = 0,
}) {
  return {
    _pendingCameraCapturePrefsKey: jsonEncode({
      'sessionId': sessionId,
      'stepIndex': stepIndex,
      'capturedPhotoCount': capturedPhotoCount,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    }),
  };
}

class _FakePhotoPicker implements RoutinePlayerPhotoPicker {
  _FakePhotoPicker({required this.returnedPath, this.lostPath, this.pickError});

  final String returnedPath;
  final String? lostPath;
  final Exception? pickError;
  final List<ImageSource> sources = <ImageSource>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
    double? maxWidth,
  }) async {
    sources.add(source);
    final error = pickError;
    if (error != null) {
      throw error;
    }
    return XFile(returnedPath);
  }

  @override
  Future<XFile?> retrieveLostPhoto() async =>
      lostPath == null ? null : XFile(lostPath!);
}

class _FakeRoutineSessionRepository implements RoutineSessionRepository {
  RoutineSession? session;
  RoutineSession? completedSession;

  @override
  Future<RoutineRun> completeSessionAndWriteRun(
    RoutineSession sessionSnapshot,
  ) async {
    completedSession = sessionSnapshot;
    return RoutineRun(
      id: 'run-1',
      routineId: sessionSnapshot.routineId.toString(),
      routineTitle: sessionSnapshot.routineTitleSnapshot,
      finishedAt: DateTime(2026, 4, 18, 9, 5),
      stepCompletionData: null,
      ownerUserId: null,
      syncStatus: 'localOnly',
      lastSyncedAt: null,
      syncMetadataJson: null,
      updatedAt: DateTime(2026, 4, 18, 9, 5),
    );
  }

  @override
  Future<void> discardSession(String sessionId) async {}

  @override
  Future<RoutineSession?> getActiveSessionForRoutine(int routineId) async {
    return session;
  }

  @override
  Future<RoutineSession?> getSessionById(String sessionId) async {
    return session;
  }

  @override
  Future<List<RoutineSessionResumeSummary>>
  listActiveSessionsForHomeResume() async {
    return const [];
  }

  @override
  Future<RoutineSession> saveSessionSnapshot(RoutineSession session) async {
    this.session = session;
    return session;
  }

  @override
  Future<RoutineSession> startOrResumeSession({
    required Routine routine,
    required SessionRoutingContext routingContext,
  }) async {
    return session!;
  }

  @override
  Stream<List<RoutineSessionResumeSummary>> watchActiveSessionsForHomeResume() {
    return const Stream.empty();
  }

  @override
  Stream<RoutineSession?> watchSession(String sessionId) {
    return Stream.value(session);
  }
}

class _BlockingSaveRoutineSessionRepository
    implements RoutineSessionRepository {
  _BlockingSaveRoutineSessionRepository(this.session);

  RoutineSession? session;
  final List<Completer<void>> _pendingSaves = <Completer<void>>[];
  bool _blockNextSave = true;

  int get pendingSaveCount => _pendingSaves.length;

  void releaseNextSave() {
    _pendingSaves.removeAt(0).complete();
  }

  @override
  Future<RoutineRun> completeSessionAndWriteRun(
    RoutineSession sessionSnapshot,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> discardSession(String sessionId) async {}

  @override
  Future<RoutineSession?> getActiveSessionForRoutine(int routineId) async {
    return session;
  }

  @override
  Future<RoutineSession?> getSessionById(String sessionId) async {
    return session;
  }

  @override
  Future<List<RoutineSessionResumeSummary>>
  listActiveSessionsForHomeResume() async {
    return const <RoutineSessionResumeSummary>[];
  }

  @override
  Future<RoutineSession> saveSessionSnapshot(RoutineSession session) async {
    if (_blockNextSave) {
      _blockNextSave = false;
      final completer = Completer<void>();
      _pendingSaves.add(completer);
      await completer.future;
    }
    this.session = session;
    return session;
  }

  @override
  Future<RoutineSession> startOrResumeSession({
    required Routine routine,
    required SessionRoutingContext routingContext,
  }) async {
    return session!;
  }

  @override
  Stream<List<RoutineSessionResumeSummary>> watchActiveSessionsForHomeResume() {
    return const Stream<List<RoutineSessionResumeSummary>>.empty();
  }

  @override
  Stream<RoutineSession?> watchSession(String sessionId) {
    return Stream<RoutineSession?>.value(session);
  }
}

class _FakeGuidanceAudioStorage implements GuidanceAudioStorage {
  const _FakeGuidanceAudioStorage();

  @override
  Future<StepGuidanceAudio> createMetadataForRecordedFile({
    required String absolutePath,
    required Duration duration,
    String mimeType = GuidanceAudioStorage.defaultMimeType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteStoredAudio(String localPath) async {
    // No-op
  }

  @override
  Future<void> cleanupOrphanedAudio(Set<String> activeLocalPaths) async {
    // No-op
  }

  @override
  Future<String> prepareRecordingPath() {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveStoredPath(String localPath) async {
    return localPath;
  }
}

class _FakeProofStorage implements RoutineSessionProofStorage {
  const _FakeProofStorage();

  @override
  Future<void> deleteSessionProofs(String sessionId) async {}

  @override
  Future<void> deleteStoredProof(String storedPath) async {}

  @override
  Future<void> deleteProofAsset(RoutineSessionProofAsset asset) async {}

  @override
  Future<void> enforceRetentionPolicy({required bool isPremium}) async {}

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    return RoutineSessionProofAsset(
      proofId: 'proof',
      localRelativePath: sourcePath,
      remoteObjectKey: null,
      uploadStatus: ProofUploadStatus.localOnly,
      capturedAt: DateTime(2026, 4, 18),
    );
  }

  @override
  Future<File?> resolveProofAssetFile(RoutineSessionProofAsset asset) async {
    return null;
  }

  @override
  Future<File?> resolveStoredFile(String storedPath) async {
    return null;
  }

  @override
  Future<String> resolveStoredPath(String storedPath) async {
    return storedPath;
  }

  @override
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  }) async {
    return asset;
  }
}

class _FailingProofStorage extends _FakeProofStorage {
  const _FailingProofStorage();

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) {
    throw StateError('persist failed');
  }
}

class _CountingProofStorage extends _FakeProofStorage {
  int persistCount = 0;

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    persistCount += 1;
    return super.persistCapturedProof(
      sessionId: sessionId,
      sourcePath: sourcePath,
    );
  }
}
