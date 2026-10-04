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
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_player_screen.dart';
import 'package:pebble_routines/features/routines/execution/ui/step_check_off.dart';
import 'package:pebble_routines/core/ui/pebble_cairn.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:pebble_routines/features/settings/data/player_settings_controller.dart';
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
    double textScale = 1,
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
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const RoutinePlayerScreen(sessionId: 'session-1'),
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

    expect(find.text('Play voice tip'), findsNothing);
    expect(find.text('Voice tip'), findsNothing);
  });

  testWidgets('text step renders centered redesign surface', (tester) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Lock the door'),
      repository,
    );

    expect(find.text('Test routine · 1 of 1'), findsOneWidget);
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
    expect(find.text('Play voice tip'), findsOneWidget);
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
    expect(_completionHeader, findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('completion shows the cairn, the time and a receipt', (
    tester,
  ) async {
    var wentHome = false;
    var reviewedRoutine = false;
    final finishedAt = DateTime(2026, 10, 3, 8, 4);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineCompleteScreen(
            routineName: 'Evening close down',
            totalStepsCompleted: 4,
            totalPhotosSaved: 2,
            finishedAt: finishedAt,
            photos: [
              for (final id in ['a', 'b'])
                CompletionPhoto(id: id, load: () async => null),
            ],
            onBackToHome: () => wentHome = true,
            onReviewRoutine: () => reviewedRoutine = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_completionHeader, findsOneWidget);
    expect(find.text('ALL CHECKED'), findsOneWidget);
    expect(find.byType(PebbleCairn), findsOneWidget);
    expect(find.textContaining('Evening close down · '), findsOneWidget);
    final context = tester.element(find.byType(RoutineCompleteScreen));
    expect(
      find.bySemanticsLabel(formatCheckTime(context, finishedAt)),
      findsOneWidget,
    );
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('4 of 4'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.byType(PhotoThumb), findsNWidgets(2));
    expect(find.text('Saved on this device'), findsOneWidget);
    // One primary action.
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.text('Done'));
    expect(wentHome, isTrue);

    await tester.tap(find.text('See details'));
    expect(reviewedRoutine, isTrue);
  });

  testWidgets('completion with skipped steps stays honest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineCompleteScreen(
            routineName: 'Morning reset',
            totalStepsCompleted: 3,
            totalPhotosSaved: 0,
            totalSteps: 4,
            skippedSteps: 1,
            showPhotoSummary: false,
            storage: CompletionStorage.backedUp,
            onBackToHome: () {},
            onReviewRoutine: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 OF 4 CHECKED'), findsOneWidget);
    expect(find.text('ALL CHECKED'), findsNothing);
    expect(find.text('3 of 4 · 1 skipped'), findsOneWidget);
    expect(find.text('3 / 3'), findsNothing);
    expect(find.text('Photos'), findsNothing);
    expect(find.text('Backed up'), findsOneWidget);
    expect(
      find.bySemanticsLabel('3 of 4 steps checked, 1 skipped'),
      findsOneWidget,
    );
  });

  testWidgets('completion under Reduce Motion renders its final state', (
    tester,
  ) async {
    var landed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: RoutineCompleteScreen(
              routineName: 'Wind down',
              totalStepsCompleted: 4,
              totalPhotosSaved: 0,
              showPhotoSummary: false,
              onLanded: () => landed++,
              onBackToHome: () {},
              onReviewRoutine: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // No staggered entrance: the Done button is fully there at once.
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Done'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1);
    expect(landed, 1);
  });

  testWidgets('photo step at 2.0x text keeps the instruction readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Back door locked', requiresPhoto: true),
      repository,
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
    final instruction = find.text('Add one photo to complete this step');
    expect(instruction, findsOneWidget);
    // It wraps onto more lines rather than being sliced by a fixed box.
    expect(tester.getSize(instruction).height, greaterThan(17 * 2.0));
    expect(find.widgetWithText(FilledButton, 'Take photo'), findsOneWidget);
  });

  testWidgets('primary button opens the camera directly on a photo step', (
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
    expect(repository.session?.stepStates.single.proofAssets, hasLength(1));
  });

  testWidgets(
    'photo step turns the primary button into the camera, with no anchor',
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
        // A following step keeps this off the final step, so any completion
        // verb here would read "Complete step" rather than "Finish routine".
        session: _sessionForSteps(const [
          photoStep,
          RoutineStep.check(label: 'Next step'),
        ]),
      );

      expect(find.byType(AnimatedVisualAnchor), findsNothing);
      expect(find.text('Proof photo'), findsOneWidget);
      expect(find.text('Add one photo to complete this step'), findsOneWidget);
      expect(find.text('Add more'), findsNothing);
      expect(find.text('Add photo'), findsNothing);

      // The thumb never leaves the footer: capture is the primary button and
      // the gallery route sits beside it, so the card offers no Add tile.
      expect(find.text('Add'), findsNothing);
      expect(find.text('Choose from library'), findsNothing);
      expect(find.text('From library'), findsOneWidget);

      // Capture is offered instead of a dead "Complete step".
      expect(find.widgetWithText(FilledButton, 'Complete step'), findsNothing);
      final primary = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Take photo'),
      );
      expect(primary.onPressed, isNotNull);
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

    expect(find.text('From library'), findsNothing);
    expect(find.text('Add'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Take photo'), findsOneWidget);
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

    await tester.tap(find.text('From library'));
    await tester.pumpAndSettle();

    expect(photoPicker.sources, [ImageSource.gallery]);
    expect(repository.session?.stepStates.single.proofAssets, hasLength(1));
  });

  testWidgets('completing is offered once the required photo exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_camera_rationale': true});
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(returnedPath: '/tmp/camera.jpg');
    const photoStep = RoutineStep.check(
      label: 'Photo proof',
      requiresPhoto: true,
      allowGallery: true,
    );
    await pumpPlayer(
      tester,
      photoStep,
      repository,
      photoPicker: photoPicker,
      session: _sessionForSteps(const [
        photoStep,
        RoutineStep.check(label: 'Next step'),
      ]),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Take photo'));
    await tester.pumpAndSettle();

    // With the one-photo requirement met, completion becomes primary and the
    // optional Premium capture remains a compact action inside the card.
    final complete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Complete step'),
    );
    expect(complete.onPressed, isNotNull);
    expect(find.widgetWithText(TextButton, 'Add photo'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('primary action saves the check before any motion plays', (
    tester,
  ) async {
    final repository = _FakeRoutineSessionRepository();
    await pumpPlayer(
      tester,
      const RoutineStep.check(label: 'Do not wait'),
      repository,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Finish routine'));
    await tester.pump();

    // Commit first: the run is written on the tap, not after the animation.
    expect(repository.completedSession, isNotNull);
    expect(
      repository.completedSession!.stepStates.single.status,
      SessionStepStatus.completed,
    );
    await tester.pumpAndSettle();
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

    await tester.tap(find.widgetWithText(FilledButton, 'Take photo'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Camera access is turned off for Pebble'),
      findsOneWidget,
    );
    expect(find.text('OPEN SETTINGS'), findsOneWidget);
    expect(repository.session?.stepStates.single.proofAssets, isEmpty);

    // The capture gate must be released so the user can try again.
    final retry = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Take photo'),
    );
    expect(retry.onPressed, isNotNull);

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

  testWidgets('free tier reveals add-more upgrade only after its first photo', (
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

    // The single photo stands alone. Only now does a compact, locked route to
    // more photos appear; no empty Premium cells imply unfinished work.
    expect(find.text('1 photo added'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add more'), findsOneWidget);
    expect(find.text('Add photo'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('free tier has no Premium prompt before the first photo', (
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
      tier: UserTier.personalFree,
    );

    expect(find.widgetWithText(FilledButton, 'Take photo'), findsOneWidget);
    expect(find.text('Add more'), findsNothing);
    expect(find.textContaining('Premium'), findsNothing);
  });

  testWidgets('premium can keep adding optional photos after completion gate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_camera_rationale': true});
    final repository = _FakeRoutineSessionRepository();
    final photoPicker = _FakePhotoPicker(returnedPath: '/tmp/second.jpg');
    const step = RoutineStep.check(
      label: 'Photo proof',
      requiresPhoto: true,
      allowGallery: true,
    );
    await pumpPlayer(
      tester,
      step,
      repository,
      photoPicker: photoPicker,
      session: _sessionForStepWithProofs(step, [_proofAsset('first')]),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Add photo'));
    await tester.pumpAndSettle();

    expect(photoPicker.sources, [ImageSource.camera]);
    expect(repository.session?.stepStates.single.proofAssets, hasLength(2));
    expect(find.text('2 photos added'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Finish routine'), findsOneWidget);
  });

  testWidgets('crowded premium photo state fits a narrow scaled screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRoutineSessionRepository();
    const photoStep = RoutineStep.check(
      label: 'Photograph the finished setup',
      requiresPhoto: true,
      allowGallery: true,
      allowSkip: true,
      guidanceAudio: StepGuidanceAudio(
        localPath: 'routine_guidance_audio/setup.m4a',
        durationMs: 3000,
      ),
    );
    final session =
        _sessionForSteps(const [
          RoutineStep.check(label: 'Previous step'),
          photoStep,
          RoutineStep.check(label: 'Next step'),
        ]).copyWith(
          currentStepIndex: 1,
          stepStates: [
            RoutineSessionStepState.initial(
              0,
            ).copyWith(status: SessionStepStatus.completed),
            RoutineSessionStepState.initial(1).copyWith(
              proofAssets: [
                _proofAsset('proof-1'),
                _proofAsset('proof-2'),
                _proofAsset('proof-3'),
              ],
            ),
            RoutineSessionStepState.initial(2),
          ],
        );

    await pumpPlayer(
      tester,
      photoStep,
      repository,
      session: session,
      textScale: 1.3,
    );

    expect(find.text('Voice tip'), findsOneWidget);
    expect(find.text('3 photos added'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add photo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Complete step'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('From library'), findsOneWidget);
    expect(find.text('Skip step'), findsOneWidget);
  });

  testWidgets('proof photo controls expose useful semantic labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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

    expect(find.bySemanticsLabel('Open proof photo 1 of 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove proof photo 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Add another proof photo'), findsOneWidget);
    semantics.dispose();
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

  testWidgets('authored multi-photo counts never become completion gates', (
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

    // One photo satisfies the step regardless of the legacy authored count;
    // Premium capacity is optional and never presented as an owed total.
    expect(find.text('1 photo added'), findsOneWidget);
    expect(find.textContaining('required'), findsNothing);
    expect(find.textContaining('of 4'), findsNothing);
    final primary = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Finish routine'),
    );
    expect(primary.onPressed, isNotNull);
    expect(find.widgetWithText(TextButton, 'Add photo'), findsOneWidget);
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

    expect(find.text('4 photos added'), findsOneWidget);
    expect(find.text('Add more'), findsNothing);
    expect(find.text('Add photo'), findsNothing);
    expect(find.text('Choose from library'), findsNothing);
  });

  group('step check-off (Moment 1)', () {
    const threeSteps = [
      RoutineStep.check(label: 'Stove off'),
      RoutineStep.check(label: 'Hair tools unplugged', allowSkip: true),
      RoutineStep.check(label: 'Front door locked'),
    ];

    List<MethodCall> recordPlatformCalls(WidgetTester tester) {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return calls;
    }

    List<String> hapticsIn(List<MethodCall> calls) => [
      for (final call in calls)
        if (call.method == 'HapticFeedback.vibrate') '${call.arguments}',
    ];

    testWidgets('a fast double tap checks exactly one step', (tester) async {
      final repository = _FakeRoutineSessionRepository();
      await pumpPlayer(
        tester,
        threeSteps.first,
        repository,
        session: _sessionForSteps(threeSteps),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pump(const Duration(milliseconds: 90));

      final session = repository.session!;
      expect(session.currentStepIndex, 1);
      expect(session.stepStates[0].status, SessionStepStatus.completed);
      expect(session.stepStates[1].status, SessionStepStatus.pending);

      // A deliberate tap once the guard is over checks the next step at
      // once, jumping the first step's motion to its end (never queued).
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pump();
      expect(repository.session!.stepStates[1].status,
          SessionStepStatus.completed);
      expect(repository.session!.currentStepIndex, 2);
      await tester.pumpAndSettle();
      expect(find.text('Front door locked'), findsOneWidget);
    });

    testWidgets('the check is saved on the tap, with the time it shows', (
      tester,
    ) async {
      final repository = _FakeRoutineSessionRepository();
      await pumpPlayer(
        tester,
        threeSteps.first,
        repository,
        session: _sessionForSteps(threeSteps),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pump();
      // Saved before a single frame of motion has played.
      final saved = repository.session!.stepStates[0];
      expect(saved.status, SessionStepStatus.completed);

      // Mid-motion: the check is drawing and the time chip is rising.
      await tester.pump(const Duration(milliseconds: 200));
      final anchor = tester.widget<AnimatedVisualAnchor>(
        find.byType(AnimatedVisualAnchor),
      );
      expect(anchor.check, greaterThan(0));
      expect(anchor.check, lessThan(1));
      final context = tester.element(find.byType(CheckTimeChip));
      final chip = tester.widget<CheckTimeChip>(find.byType(CheckTimeChip));
      expect(chip.label, formatCheckTime(context, saved.completedAt!));

      // Settled: the step now lives in the trail with its time.
      await tester.pumpAndSettle();
      expect(find.byType(CheckTimeChip), findsNothing);
      expect(find.text('Stove off'), findsOneWidget);
      expect(find.text(chip.label), findsOneWidget);
      expect(find.text('Hair tools unplugged'), findsOneWidget);
    });

    testWidgets('skip records an honest skip with no stroke or buzz', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'stepCompleteHaptic': true});
      final calls = recordPlatformCalls(tester);
      final repository = _FakeRoutineSessionRepository();
      final session = _sessionForSteps(threeSteps).copyWith(
        currentStepIndex: 1,
        stepStates: [
          RoutineSessionStepState.initial(0).copyWith(
            status: SessionStepStatus.completed,
            completedAt: DateTime(2026, 4, 18, 9, 1),
          ),
          RoutineSessionStepState.initial(1),
          RoutineSessionStepState.initial(2),
        ],
      );
      await pumpPlayer(tester, threeSteps[1], repository, session: session);
      calls.clear();

      await tester.tap(find.text('Skip step'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(repository.session!.stepStates[1].status,
          SessionStepStatus.skipped);
      final anchor = tester.widget<AnimatedVisualAnchor>(
        find.byType(AnimatedVisualAnchor),
      );
      expect(anchor.check, 0);
      expect(anchor.done, 0);
      await tester.pumpAndSettle();
      expect(hapticsIn(calls), isEmpty);
      // The trail shows the checked step with its time and the skip as
      // "Skipped", never as done.
      expect(find.text('Stove off'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Front door locked'), findsOneWidget);
    });

    testWidgets('Reduce Motion: no stroke, quick cross-fade, haptics stay', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'stepCompleteHaptic': true});
      final calls = recordPlatformCalls(tester);
      final repository = _FakeRoutineSessionRepository();
      repository.session = _sessionForSteps(threeSteps);
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            routineSessionRepositoryProvider.overrideWithValue(repository),
            routineSessionProofStorageProvider.overrideWithValue(
              const _FakeProofStorage(),
            ),
            guidanceAudioStorageProvider.overrideWithValue(
              const _FakeGuidanceAudioStorage(),
            ),
            subscriptionProvider.overrideWithValue(UserTier.personalPremium),
            premiumFeaturePolicyProvider.overrideWithValue(
              premiumFeaturePolicyForTier(UserTier.personalPremium),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const RoutinePlayerScreen(sessionId: 'session-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      calls.clear();

      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pump();
      // The check is there in full at once: no stroke animation.
      final anchor = tester.widget<AnimatedVisualAnchor>(
        find.byType(AnimatedVisualAnchor),
      );
      expect(anchor.check, 1);

      // The whole cross-fade is over in 120 ms.
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.byType(CheckTimeChip), findsNothing);
      expect(find.text('Hair tools unplugged'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(hapticsIn(calls), [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.selectionClick',
      ]);
      await tester.pumpAndSettle();
    });

    testWidgets('each check is announced to screen readers', (tester) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<
        dynamic
      >(SystemChannels.accessibility, (message) async {
        final map = message as Map<dynamic, dynamic>;
        if (map['type'] == 'announce') {
          announcements.add((map['data'] as Map)['message'] as String);
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      final repository = _FakeRoutineSessionRepository();
      await pumpPlayer(
        tester,
        threeSteps.first,
        repository,
        session: _sessionForSteps(threeSteps),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pump();
      final context = tester.element(find.byType(RoutinePlayerScreen));
      final time = formatCheckTime(
        context,
        repository.session!.stepStates[0].completedAt!,
      );
      expect(announcements, ['Stove off, checked at $time.']);
      await tester.pumpAndSettle();
    });

    testWidgets('the footer keeps its place between steps', (tester) async {
      final repository = _FakeRoutineSessionRepository();
      await pumpPlayer(
        tester,
        threeSteps.first,
        repository,
        session: _sessionForSteps(threeSteps),
      );
      final before = tester.getTopLeft(find.byType(FilledButton)).dy;
      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pumpAndSettle();
      expect(find.text('Previous'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(FilledButton)).dy, before);
    });

    const photoSteps = [
      RoutineStep.check(
        label: 'Photo proof',
        requiresPhoto: true,
        allowGallery: true,
      ),
      RoutineStep.check(label: 'Next step'),
    ];

    testWidgets('a missing required photo: primary takes it, no check-off', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_camera_rationale': true,
        'stepCompleteHaptic': true,
      });
      final calls = recordPlatformCalls(tester);
      final repository = _FakeRoutineSessionRepository();
      final photoPicker = _FakePhotoPicker(returnedPath: '/tmp/camera.jpg');
      await pumpPlayer(
        tester,
        photoSteps.first,
        repository,
        photoPicker: photoPicker,
        session: _sessionForSteps(photoSteps),
      );
      calls.clear();

      await tester.tap(find.widgetWithText(FilledButton, 'Take photo'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(photoPicker.sources, [ImageSource.camera]);
      final session = repository.session!;
      expect(session.currentStepIndex, 0);
      expect(session.stepStates[0].status, SessionStepStatus.pending);
      expect(session.stepStates[0].completedAt, isNull);
      expect(session.stepStates[0].proofAssets, hasLength(1));
      // No stroke, no time chip, no buzz: the step isn't done yet.
      expect(find.byType(CheckTimeChip), findsNothing);
      expect(hapticsIn(calls), isEmpty);

      await tester.pumpAndSettle();
      expect(find.text('Photo proof'), findsOneWidget);
      expect(find.text('Next step'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Take photo'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Complete step'), findsOneWidget);
    });

    testWidgets('after the photo, primary checks off with the tap time', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'has_seen_camera_rationale': true});
      final repository = _FakeRoutineSessionRepository();
      final photoPicker = _FakePhotoPicker(returnedPath: '/tmp/camera.jpg');
      await pumpPlayer(
        tester,
        photoSteps.first,
        repository,
        photoPicker: photoPicker,
        session: _sessionForSteps(photoSteps),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Take photo'));
      await tester.pumpAndSettle();
      // Past the input guard: this is a separate, deliberate tap.
      await tester.tap(find.widgetWithText(FilledButton, 'Complete step'));
      await tester.pump();

      // Commit first: saved on the tap, with its proof.
      final saved = repository.session!.stepStates[0];
      expect(saved.status, SessionStepStatus.completed);
      expect(saved.completedAt, isNotNull);
      expect(saved.proofAssets, hasLength(1));
      expect(photoPicker.sources, [ImageSource.camera]);

      // The chip shows exactly the saved time.
      await tester.pump(const Duration(milliseconds: 200));
      final context = tester.element(find.byType(CheckTimeChip));
      final chip = tester.widget<CheckTimeChip>(find.byType(CheckTimeChip));
      expect(chip.label, formatCheckTime(context, saved.completedAt!));

      // Settled: the photo step sits in the trail with its time.
      await tester.pumpAndSettle();
      expect(find.byType(CheckTimeChip), findsNothing);
      final trail = find.byType(StepTrail);
      expect(
        find.descendant(of: trail, matching: find.text('Photo proof')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: trail, matching: find.text(chip.label)),
        findsOneWidget,
      );
      expect(find.text('Next step'), findsOneWidget);
      expect(repository.session!.currentStepIndex, 1);
    });

    testWidgets('gallery pick sits in the footer, under the primary', (
      tester,
    ) async {
      final repository = _FakeRoutineSessionRepository();
      await pumpPlayer(
        tester,
        photoSteps.first,
        repository,
        tier: UserTier.personalFree,
        session: _sessionForSteps(photoSteps),
      );

      final gallery = find.text('From library');
      expect(gallery, findsOneWidget);
      expect(
        find.ancestor(of: gallery, matching: find.byType(PebbleButton)),
        findsOneWidget,
      );
      final primary = find.widgetWithText(FilledButton, 'Take photo');
      expect(
        tester.getTopLeft(gallery).dy,
        greaterThan(tester.getBottomLeft(primary).dy),
      );
      // Not inside the proof card.
      expect(
        tester.getTopLeft(gallery).dy,
        greaterThan(tester.getBottomLeft(find.text('Proof photo')).dy),
      );
      expect(find.text('Choose from library'), findsNothing);
    });

    test('new installs get the check buzz; existing choices are kept', () async {
      SharedPreferences.setMockInitialValues({});
      final fresh = await SharedPreferences.getInstance();
      await PlayerSettingsController.applyNewInstallDefaults(fresh);
      expect(PlayerSettingsController(fresh).stepCompleteHaptic, isTrue);

      SharedPreferences.setMockInitialValues({'stepCompleteHaptic': false});
      final existing = await SharedPreferences.getInstance();
      await PlayerSettingsController.applyNewInstallDefaults(existing);
      expect(PlayerSettingsController(existing).stepCompleteHaptic, isFalse);
    });
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

final Finder _completionHeader = find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == RoutineCompleteScreen.headerSemanticsLabel,
);
