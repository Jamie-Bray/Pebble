import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_player_screen.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/premium_policy_test_utils.dart';

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
    RoutineSession? session,
  }) async {
    repository.session = session ?? _sessionForStep(step);
    final prefs = await SharedPreferences.getInstance();
    final overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      routineSessionRepositoryProvider.overrideWithValue(repository),
      routineSessionProofStorageProvider.overrideWithValue(
        const _FakeProofStorage(),
      ),
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
    await tester.pumpAndSettle();
  }

  testWidgets('text-only steps show no guidance audio control', (tester) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Lock the door'),
      repository,
    );

    expect(find.text('Play guidance'), findsNothing);
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

  testWidgets('take photo opens camera directly without the source sheet', (
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

    await tester.tap(find.widgetWithText(FilledButton, 'Take photo'));
    await tester.pumpAndSettle();

    expect(photoPicker.sources, [ImageSource.camera]);
    expect(find.text('Add photo'), findsNothing);
    expect(find.text('Choose from library'), findsNothing);
    expect(repository.session?.stepStates.single.proofAssets, hasLength(1));
  });

  testWidgets('photo step renders camera and gallery actions without anchor', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(
        label: 'Photo proof',
        requiresPhoto: true,
        allowGallery: true,
      ),
      repository,
    );

    expect(find.byIcon(LucideIcons.camera), findsNothing);
    expect(find.text('Photo Needed'), findsNothing);
    expect(find.byType(AnimatedVisualAnchor), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Take photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('gallery action is hidden when gallery is not allowed', (
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

    expect(find.text('Choose from Gallery'), findsNothing);
  });

  testWidgets('gallery action opens the gallery picker', (tester) async {
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

    await tester.tap(find.text('Choose from Gallery'));
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

  testWidgets('free photo limit shows a softer Plus upsell', (tester) async {
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

    expect(
      find.text(
        '1 photo saved. Pebble Free includes one proof photo per step.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add more with Pebble Premium'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsNothing);
  });

  testWidgets('premium photo limit uses non-upsell copy', (tester) async {
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

    expect(find.text('Maximum photos added for this step.'), findsOneWidget);
    expect(find.text('Add more with Pebble Premium'), findsNothing);
    expect(find.text('Choose from Gallery'), findsNothing);
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

class _FakePhotoPicker implements RoutinePlayerPhotoPicker {
  _FakePhotoPicker({required this.returnedPath});

  final String returnedPath;
  final List<ImageSource> sources = <ImageSource>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
    double? maxWidth,
  }) async {
    sources.add(source);
    return XFile(returnedPath);
  }
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
