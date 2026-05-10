import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_config.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:pebble_routines/features/routines/composer/providers/routine_composer_provider.dart';

import 'fake_routine_composer_draft_repository.dart';

void main() {
  group('RoutineComposerViewModel', () {
    test('loads a blank create draft with an initial empty step', () async {
      final repository = FakeRoutineComposerDraftRepository();
      final viewModel = RoutineComposerViewModel(
        repository,
        const RoutineComposerConfig.newDraft(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.mode.name, 'create');
      expect(viewModel.state.steps, hasLength(1));
      expect(viewModel.state.steps.single.text, isEmpty);

      viewModel.dispose();
    });

    test('debounces repeated text edits into a single draft save', () async {
      final repository = FakeRoutineComposerDraftRepository();
      final viewModel = RoutineComposerViewModel(
        repository,
        const RoutineComposerConfig.newDraft(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final stepId = viewModel.state.steps.single.id;

      viewModel.updateStepText(stepId, 'Lock');
      viewModel.updateStepText(stepId, 'Lock doors');
      viewModel.updateStepText(stepId, 'Lock doors and windows');

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(repository.saveDraftCallCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(repository.saveDraftCallCount, 1);
      expect(
        repository.savedSnapshots.single.steps.single.text,
        'Lock doors and windows',
      );

      viewModel.dispose();
    });

    test(
      'publishes untitled drafts using the first non-empty step as title',
      () async {
        final repository = FakeRoutineComposerDraftRepository();
        final viewModel = RoutineComposerViewModel(
          repository,
          const RoutineComposerConfig.newDraft(),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        final stepId = viewModel.state.steps.single.id;
        viewModel.updateStepText(stepId, 'Take medication');

        final routine = await viewModel.publish();

        expect(routine, isNotNull);
        expect(repository.publishDraftCallCount, 1);
        expect(repository.publishedRoutines.single.title, 'Take medication');

        viewModel.dispose();
      },
    );

    test('new composer resumes the latest create draft by default', () async {
      final repository = FakeRoutineComposerDraftRepository();
      final firstViewModel = RoutineComposerViewModel(
        repository,
        const RoutineComposerConfig.newDraft(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final firstDraftId = firstViewModel.state.draftId;
      firstViewModel.updateTitle('Old draft');
      firstViewModel.updateStepText(
        firstViewModel.state.steps.single.id,
        'Stale step',
      );
      await firstViewModel.flushDraft();
      firstViewModel.dispose();

      final secondViewModel = RoutineComposerViewModel(
        repository,
        const RoutineComposerConfig.newDraft(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(secondViewModel.state.draftId, firstDraftId);
      expect(secondViewModel.state.title, 'Old draft');
      expect(secondViewModel.state.steps.single.text, 'Stale step');

      secondViewModel.dispose();
    });

    test(
      'forced new drafts do not reuse previous create draft content',
      () async {
        final repository = FakeRoutineComposerDraftRepository();
        final firstViewModel = RoutineComposerViewModel(
          repository,
          const RoutineComposerConfig.newDraft(),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        final firstDraftId = firstViewModel.state.draftId;
        firstViewModel.updateTitle('Old draft');
        firstViewModel.updateStepText(
          firstViewModel.state.steps.single.id,
          'Stale step',
        );
        await firstViewModel.flushDraft();
        firstViewModel.dispose();

        final secondViewModel = RoutineComposerViewModel(
          repository,
          const RoutineComposerConfig.newDraft(forceNewDraft: true),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(secondViewModel.state.draftId, isNot(firstDraftId));
        expect(secondViewModel.state.title, isEmpty);
        expect(secondViewModel.state.steps, hasLength(1));
        expect(secondViewModel.state.steps.single.text, isEmpty);
        expect(repository.clearCreateDraftsCallCount, 1);

        secondViewModel.dispose();
      },
    );

    test('publishing a create draft clears it from draft storage', () async {
      final repository = FakeRoutineComposerDraftRepository();
      var createDraftInvalidations = 0;
      final viewModel = RoutineComposerViewModel(
        repository,
        const RoutineComposerConfig.newDraft(),
        onCreateDraftsChanged: () {
          createDraftInvalidations += 1;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      viewModel.updateStepText(viewModel.state.steps.single.id, 'Pack keys');

      final routine = await viewModel.publish();

      expect(routine, isNotNull);
      expect(await repository.latestCreateDraft(), isNull);
      expect(createDraftInvalidations, 1);

      viewModel.dispose();
    });

    test('discarding a create draft clears it from draft storage', () async {
      final repository = FakeRoutineComposerDraftRepository();
      var createDraftInvalidations = 0;
      final viewModel = RoutineComposerViewModel(
        repository,
        const RoutineComposerConfig.newDraft(),
        onCreateDraftsChanged: () {
          createDraftInvalidations += 1;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      viewModel.updateTitle('Maybe later');
      await viewModel.flushDraft();

      expect(await repository.latestCreateDraft(), isNotNull);

      await viewModel.discardDraft();

      expect(await repository.latestCreateDraft(), isNull);
      expect(createDraftInvalidations, 1);

      viewModel.dispose();
    });

    test(
      'legacy duplicate create drafts expose only the newest meaningful one',
      () async {
        final repository = FakeRoutineComposerDraftRepository();
        final oldDraft = await repository.createDraft(
          seedData: const RoutineComposerSeedData(
            title: 'Old draft',
            iconKey: 'sparkles',
            colorHex: null,
            steps: [
              RoutineComposerStepDraft(
                id: 'old-step',
                text: 'Old step',
                requiresPhoto: false,
                allowSkip: false,
                sortOrder: 0,
              ),
            ],
          ),
        );
        await repository.saveDraft(
          oldDraft.copyWith(updatedAt: DateTime(2026, 1, 1)),
        );
        final emptyDraft = await repository.createDraft();
        await repository.saveDraft(
          emptyDraft.copyWith(updatedAt: DateTime(2026, 1, 3)),
        );
        final newestDraft = await repository.createDraft(
          seedData: const RoutineComposerSeedData(
            title: 'Newest draft',
            iconKey: 'sparkles',
            colorHex: null,
            steps: [
              RoutineComposerStepDraft(
                id: 'new-step',
                text: 'New step',
                requiresPhoto: false,
                allowSkip: false,
                sortOrder: 0,
              ),
            ],
          ),
        );
        await repository.saveDraft(
          newestDraft.copyWith(updatedAt: DateTime(2026, 1, 2)),
        );

        final latest = await repository.latestCreateDraft();

        expect(latest?.draftId, newestDraft.draftId);
        expect(latest?.title, 'Newest draft');
        expect(await repository.watchDraft(oldDraft.draftId).first, isNull);
        expect(await repository.watchDraft(emptyDraft.draftId).first, isNull);
      },
    );

    test(
      'template customization prefill does not leak into blank creation',
      () async {
        final repository = FakeRoutineComposerDraftRepository();
        const seed = RoutineComposerSeedData(
          title: 'Leaving Home',
          iconKey: 'house',
          colorHex: null,
          steps: [
            RoutineComposerStepDraft(
              id: 'template-step',
              text: 'Lock the door',
              requiresPhoto: false,
              allowSkip: false,
              sortOrder: 0,
            ),
          ],
        );
        final templateViewModel = RoutineComposerViewModel(
          repository,
          const RoutineComposerConfig.customizeTemplate(seedData: seed),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(templateViewModel.state.title, 'Leaving Home');
        expect(templateViewModel.state.steps.single.text, 'Lock the door');
        final templateDraftId = templateViewModel.state.draftId;
        templateViewModel.dispose();

        final blankViewModel = RoutineComposerViewModel(
          repository,
          const RoutineComposerConfig.newDraft(),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(blankViewModel.state.draftId, isNot(templateDraftId));
        expect(blankViewModel.state.title, isEmpty);
        expect(blankViewModel.state.steps.single.text, isEmpty);

        blankViewModel.dispose();
      },
    );

    test(
      'edit mode keeps the source routine untouched until publish',
      () async {
        final repository = FakeRoutineComposerDraftRepository();
        final existingRoutine = Routine(
          id: 42,
          title: 'Evening Reset',
          stepsJson: '[]',
          createdAt: DateTime(2026, 4, 1),
          emoji: 'moon',
          colorHex: null,
          isPinned: false,
          pinnedAt: null,
          reminderDay: null,
          reminderTime: null,
          version: 1,
          updatedAt: DateTime(2026, 4, 1),
          cloudId: null,
          ownerUserId: null,
          syncStatus: 'localOnly',
          lastSyncedAt: null,
        );
        final seed = RoutineComposerSeedData(
          title: existingRoutine.title,
          iconKey: existingRoutine.emoji,
          colorHex: existingRoutine.colorHex,
          steps: const [
            RoutineComposerStepDraft(
              id: 'seed-step',
              text: 'Put phone away',
              requiresPhoto: false,
              allowSkip: false,
              sortOrder: 0,
            ),
          ],
        );
        final viewModel = RoutineComposerViewModel(
          repository,
          RoutineComposerConfig.edit(routine: existingRoutine, seedData: seed),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        viewModel.updateStepText('seed-step', 'Put phone on charger');
        await Future<void>.delayed(const Duration(milliseconds: 650));

        expect(repository.publishedRoutines, isEmpty);

        final routine = await viewModel.publish();

        expect(routine, isNotNull);
        expect(repository.publishedRoutines.single.id, existingRoutine.id);
        expect(
          repository.publishedRoutines.single.title,
          existingRoutine.title,
        );

        viewModel.dispose();
      },
    );

    test('publishing preserves guidance audio metadata', () async {
      final repository = FakeRoutineComposerDraftRepository();
      final viewModel = RoutineComposerViewModel(
        repository,
        const RoutineComposerConfig.newDraft(),
      );
      const audio = StepGuidanceAudio(
        localPath: 'routine_guidance_audio/clip.m4a',
        durationMs: 4200,
        mimeType: 'audio/mp4',
        byteSize: 1234,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final stepId = viewModel.state.steps.single.id;
      viewModel.updateStepText(stepId, 'Check the latch');
      viewModel.setGuidanceAudio(stepId, audio);

      final routine = await viewModel.publish();
      final decoded = jsonDecode(routine!.stepsJson) as List<dynamic>;
      final step = RoutineStep.fromJson(
        Map<String, dynamic>.from(decoded.single as Map),
      );

      expect(step.guidanceAudio, audio);

      viewModel.dispose();
    });

    test('edit mode preloads guidance audio metadata', () async {
      final repository = FakeRoutineComposerDraftRepository();
      const audio = StepGuidanceAudio(
        localPath: 'routine_guidance_audio/edit.m4a',
        durationMs: 3000,
        mimeType: 'audio/mp4',
        byteSize: 900,
      );
      final existingRoutine = Routine(
        id: 84,
        title: 'Audio routine',
        stepsJson: jsonEncode([
          const RoutineStep.check(
            label: 'Listen first',
            guidanceAudio: audio,
          ).toJson(),
        ]),
        createdAt: DateTime(2026, 4, 1),
        emoji: 'audio-lines',
        colorHex: null,
        isPinned: false,
        pinnedAt: null,
        reminderDay: null,
        reminderTime: null,
        version: 1,
        updatedAt: DateTime(2026, 4, 1),
        cloudId: null,
        ownerUserId: null,
        syncStatus: 'localOnly',
        lastSyncedAt: null,
      );

      final viewModel = RoutineComposerViewModel(
        repository,
        RoutineComposerConfig.edit(routine: existingRoutine),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(viewModel.state.steps.single.guidanceAudio, audio);

      viewModel.dispose();
    });
  });
}
