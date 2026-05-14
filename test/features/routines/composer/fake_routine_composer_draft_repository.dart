import 'dart:async';
import 'dart:convert';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_draft_snapshot.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_mode.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:uuid/uuid.dart';

class FakeRoutineComposerDraftRepository
    implements RoutineComposerDraftRepository {
  final _uuid = const Uuid();
  final _draftsByLookup = <String, RoutineComposerDraftSnapshot>{};
  final _draftsById = <String, RoutineComposerDraftSnapshot>{};
  final List<RoutineComposerDraftSnapshot> savedSnapshots = [];
  final List<String> discardedDraftIds = [];
  final List<Routine> publishedRoutines = [];

  int clearCreateDraftsCallCount = 0;
  final List<int> clearedEditDraftRoutineIds = [];
  int saveDraftCallCount = 0;
  int publishDraftCallCount = 0;

  @override
  Future<RoutineComposerDraftSnapshot> createDraft({
    RoutineComposerSeedData? seedData,
  }) async {
    final now = DateTime.now();
    final snapshot = RoutineComposerDraftSnapshot(
      draftId: _uuid.v4(),
      mode: RoutineComposerMode.create,
      sourceRoutineId: null,
      title: seedData?.title ?? '',
      iconKey: seedData?.iconKey ?? RoutineIconCatalog.defaultKey,
      colorHex: seedData?.colorHex,
      steps: seedData?.steps ?? [_blankStep(0)],
      createdAt: now,
      updatedAt: now,
    );
    _draftsById[snapshot.draftId] = snapshot;
    return snapshot;
  }

  @override
  Future<RoutineComposerDraftSnapshot> createFreshDraft({
    RoutineComposerSeedData? seedData,
  }) async {
    await clearCreateDrafts();
    return createDraft(seedData: seedData);
  }

  @override
  Future<void> clearCreateDrafts() async {
    clearCreateDraftsCallCount += 1;
    final createDraftIds = _draftsById.values
        .where(_isCreateDraft)
        .map((draft) => draft.draftId)
        .toList(growable: false);
    for (final draftId in createDraftIds) {
      _draftsById.remove(draftId);
    }
    _draftsByLookup.remove('create:new');
  }

  @override
  Future<void> clearEditDraftsForRoutine(int routineId) async {
    clearedEditDraftRoutineIds.add(routineId);
    final lookupKey = '${RoutineComposerMode.edit.storageValue}:$routineId';
    final existing = _draftsByLookup.remove(lookupKey);
    if (existing != null) {
      _draftsById.remove(existing.draftId);
      return;
    }

    final draftIds = _draftsById.values
        .where(
          (draft) =>
              draft.mode == RoutineComposerMode.edit &&
              draft.sourceRoutineId == routineId,
        )
        .map((draft) => draft.draftId)
        .toList(growable: false);
    for (final draftId in draftIds) {
      _draftsById.remove(draftId);
    }
  }

  @override
  Future<RoutineComposerDraftSnapshot> loadOrCreateDraft({
    required RoutineComposerMode mode,
    int? sourceRoutineId,
    RoutineComposerSeedData? seedData,
  }) async {
    final lookupKey = '${mode.storageValue}:${sourceRoutineId ?? 'new'}';
    final existing = _draftsByLookup[lookupKey];
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final snapshot = RoutineComposerDraftSnapshot(
      draftId: _uuid.v4(),
      mode: mode,
      sourceRoutineId: sourceRoutineId,
      title: seedData?.title ?? '',
      iconKey: seedData?.iconKey ?? RoutineIconCatalog.defaultKey,
      colorHex: seedData?.colorHex,
      steps: seedData?.steps ?? [_blankStep(0)],
      createdAt: now,
      updatedAt: now,
    );
    _draftsByLookup[lookupKey] = snapshot;
    _draftsById[snapshot.draftId] = snapshot;
    return snapshot;
  }

  @override
  Future<RoutineComposerDraftSnapshot?> latestCreateDraft() async {
    final createDrafts =
        _draftsById.values.where(_isCreateDraft).toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    RoutineComposerDraftSnapshot? latestMeaningful;
    final staleDraftIds = <String>[];

    for (final draft in createDrafts) {
      if (!_hasMeaningfulContent(draft)) {
        staleDraftIds.add(draft.draftId);
        continue;
      }
      if (latestMeaningful == null) {
        latestMeaningful = draft;
      } else {
        staleDraftIds.add(draft.draftId);
      }
    }

    for (final draftId in staleDraftIds) {
      _draftsById.remove(draftId);
    }
    if (latestMeaningful == null) {
      _draftsByLookup.remove('create:new');
    } else {
      _draftsByLookup['create:new'] = latestMeaningful;
    }
    return latestMeaningful;
  }

  @override
  Stream<RoutineComposerDraftSnapshot?> watchDraft(String draftId) {
    return Stream.value(_draftsById[draftId]);
  }

  @override
  Future<void> saveDraft(RoutineComposerDraftSnapshot snapshot) async {
    saveDraftCallCount += 1;
    savedSnapshots.add(snapshot);
    _draftsById[snapshot.draftId] = snapshot;
    _draftsByLookup['${snapshot.mode.storageValue}:${snapshot.sourceRoutineId ?? 'new'}'] =
        snapshot;
  }

  @override
  Future<Routine> publishDraft(String draftId) async {
    publishDraftCallCount += 1;
    final snapshot = _draftsById[draftId]!;
    final nonEmptySteps = snapshot.steps
        .where((step) => step.text.trim().isNotEmpty)
        .toList(growable: false);
    final title = snapshot.title.trim().isNotEmpty
        ? snapshot.title.trim()
        : nonEmptySteps.first.text.trim();
    final routine = Routine(
      id: snapshot.sourceRoutineId ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      stepsJson: jsonEncode(
        nonEmptySteps
            .map(
              (step) => RoutineStep.check(
                label: step.text.trim(),
                requiresPhoto: step.requiresPhoto,
                allowSkip: step.allowSkip,
                photoCount: step.requiresPhoto ? 1 : 0,
                photoPrompt: step.requiresPhoto ? 'Take a photo' : null,
                guidanceAudio: step.guidanceAudio,
              ).toJson(),
            )
            .toList(),
      ),
      createdAt: DateTime.now(),
      emoji: snapshot.iconKey,
      colorHex: snapshot.colorHex,
      isPinned: false,
      pinnedAt: null,
      reminderDay: null,
      reminderTime: null,
      version: 1,
      updatedAt: DateTime.now(),
      cloudId: null,
      ownerUserId: null,
      syncStatus: 'localOnly',
      lastSyncedAt: null,
    );
    publishedRoutines.add(routine);
    if (_isCreateDraft(snapshot)) {
      await clearCreateDrafts();
    } else {
      _draftsById.remove(draftId);
      _draftsByLookup.remove(
        '${snapshot.mode.storageValue}:${snapshot.sourceRoutineId ?? 'new'}',
      );
    }
    return routine;
  }

  @override
  Future<void> discardDraft(String draftId) async {
    discardedDraftIds.add(draftId);
    final snapshot = _draftsById[draftId];
    if (snapshot == null) return;
    if (_isCreateDraft(snapshot)) {
      await clearCreateDrafts();
    } else {
      _draftsById.remove(draftId);
      _draftsByLookup.remove(
        '${snapshot.mode.storageValue}:${snapshot.sourceRoutineId ?? 'new'}',
      );
    }
  }

  RoutineComposerStepDraft _blankStep(int sortOrder) {
    return RoutineComposerStepDraft(
      id: _uuid.v4(),
      text: '',
      requiresPhoto: false,
      allowSkip: false,
      sortOrder: sortOrder,
    );
  }

  bool _hasMeaningfulContent(RoutineComposerDraftSnapshot draft) {
    return draft.title.trim().isNotEmpty ||
        draft.steps.any((step) => step.text.trim().isNotEmpty);
  }

  bool _isCreateDraft(RoutineComposerDraftSnapshot draft) {
    return draft.mode == RoutineComposerMode.create &&
        draft.sourceRoutineId == null;
  }
}
