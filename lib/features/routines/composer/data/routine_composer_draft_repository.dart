import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/local/routine_composer_draft_dao.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_draft_snapshot.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_mode.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:uuid/uuid.dart';

abstract class RoutineComposerDraftRepository {
  Future<RoutineComposerDraftSnapshot> createDraft({
    RoutineComposerSeedData? seedData,
  });

  Future<RoutineComposerDraftSnapshot> createFreshDraft({
    RoutineComposerSeedData? seedData,
  });

  Future<void> clearCreateDrafts();

  Future<void> clearEditDraftsForRoutine(int routineId);

  Future<RoutineComposerDraftSnapshot> loadOrCreateDraft({
    required RoutineComposerMode mode,
    int? sourceRoutineId,
    RoutineComposerSeedData? seedData,
  });

  Future<RoutineComposerDraftSnapshot?> latestCreateDraft();

  Stream<RoutineComposerDraftSnapshot?> watchDraft(String draftId);

  Future<void> saveDraft(RoutineComposerDraftSnapshot snapshot);

  Future<Routine> publishDraft(String draftId);

  Future<void> discardDraft(String draftId);
}

class RoutineComposerDraftRepositoryImpl
    implements RoutineComposerDraftRepository {
  RoutineComposerDraftRepositoryImpl(this._dao, this._routineRepository);

  final RoutineComposerDraftDao _dao;
  final RoutineRepository _routineRepository;
  final Uuid _uuid = const Uuid();

  @override
  Future<RoutineComposerDraftSnapshot> createDraft({
    RoutineComposerSeedData? seedData,
  }) async {
    final snapshot = _buildSnapshot(
      mode: RoutineComposerMode.create,
      sourceRoutineId: null,
      seedData: seedData,
    );
    await saveDraft(snapshot);
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
  Future<void> clearCreateDrafts() => _dao.deleteCreateDrafts();

  @override
  Future<void> clearEditDraftsForRoutine(int routineId) {
    return _dao.deleteEditDraftsForRoutine(routineId);
  }

  @override
  Future<RoutineComposerDraftSnapshot> loadOrCreateDraft({
    required RoutineComposerMode mode,
    int? sourceRoutineId,
    RoutineComposerSeedData? seedData,
  }) async {
    final existing = await _dao.getLatestDraft(
      mode: mode.storageValue,
      sourceRoutineId: sourceRoutineId,
    );
    if (existing != null) {
      return _mapRow(existing);
    }

    final snapshot = _buildSnapshot(
      mode: mode,
      sourceRoutineId: sourceRoutineId,
      seedData: seedData,
    );
    await saveDraft(snapshot);
    return snapshot;
  }

  @override
  Future<RoutineComposerDraftSnapshot?> latestCreateDraft() async {
    final rows = await _dao.getCreateDrafts();
    if (rows.isEmpty) return null;

    RoutineComposerDraftSnapshot? latestMeaningful;
    final staleDraftIds = <String>[];

    for (final row in rows) {
      final snapshot = _mapRow(row);
      if (!_hasMeaningfulContent(snapshot)) {
        staleDraftIds.add(snapshot.draftId);
        continue;
      }
      if (latestMeaningful == null) {
        latestMeaningful = snapshot;
      } else {
        staleDraftIds.add(snapshot.draftId);
      }
    }

    for (final draftId in staleDraftIds) {
      await _dao.deleteDraft(draftId);
    }

    return latestMeaningful;
  }

  RoutineComposerDraftSnapshot _buildSnapshot({
    required RoutineComposerMode mode,
    required int? sourceRoutineId,
    RoutineComposerSeedData? seedData,
  }) {
    final now = DateTime.now();
    return RoutineComposerDraftSnapshot(
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
  }

  @override
  Stream<RoutineComposerDraftSnapshot?> watchDraft(String draftId) {
    return _dao
        .watchDraft(draftId)
        .map((row) => row == null ? null : _mapRow(row));
  }

  @override
  Future<void> saveDraft(RoutineComposerDraftSnapshot snapshot) {
    final normalizedSteps = _normalizeStepOrder(snapshot.steps);
    final normalizedTitle = snapshot.title.trim().isEmpty
        ? null
        : snapshot.title;
    final updatedSnapshot = snapshot.copyWith(
      title: normalizedTitle ?? '',
      steps: normalizedSteps,
      updatedAt: DateTime.now(),
    );
    return _dao.upsertDraft(
      RoutineComposerDraftsCompanion(
        draftId: Value(updatedSnapshot.draftId),
        mode: Value(updatedSnapshot.mode.storageValue),
        sourceRoutineId: Value(updatedSnapshot.sourceRoutineId),
        title: Value(normalizedTitle),
        iconKey: Value(updatedSnapshot.iconKey),
        colorHex: Value(updatedSnapshot.colorHex),
        stepsJson: Value(
          RoutineComposerStepDraft.listToJsonString(updatedSnapshot.steps),
        ),
        createdAt: Value(updatedSnapshot.createdAt),
        updatedAt: Value(updatedSnapshot.updatedAt),
      ),
    );
  }

  @override
  Future<Routine> publishDraft(String draftId) async {
    final row = await _dao.getDraftById(draftId);
    if (row == null) {
      throw StateError('Draft not found');
    }

    final snapshot = _mapRow(row);
    final nonEmptySteps = snapshot.steps
        .where((step) => step.text.trim().isNotEmpty)
        .toList(growable: false);
    if (nonEmptySteps.isEmpty) {
      throw StateError('At least one step is required to publish a routine.');
    }

    final routineSteps = nonEmptySteps
        .map(
          (step) => RoutineStep.check(
            label: step.text.trim(),
            requiresPhoto: step.requiresPhoto,
            photoCount: step.requiresPhoto ? 1 : 0,
            photoPrompt: step.requiresPhoto ? 'Take a photo' : null,
            allowSkip: step.allowSkip,
            guidanceAudio: step.guidanceAudio,
          ),
        )
        .toList(growable: false);

    final inferredTitle = snapshot.title.trim().isNotEmpty
        ? snapshot.title.trim()
        : nonEmptySteps.first.text.trim();
    final now = DateTime.now();

    final existing =
        snapshot.mode == RoutineComposerMode.edit &&
            snapshot.sourceRoutineId != null
        ? await _routineRepository.getRoutineById(snapshot.sourceRoutineId!)
        : null;

    final publishedRoutine = Routine(
      id: existing?.id ?? now.millisecondsSinceEpoch,
      title: inferredTitle,
      stepsJson: jsonEncode(routineSteps.map((step) => step.toJson()).toList()),
      createdAt: existing?.createdAt ?? now,
      emoji:
          snapshot.iconKey ?? existing?.emoji ?? RoutineIconCatalog.defaultKey,
      colorHex: snapshot.colorHex ?? existing?.colorHex,
      isPinned: existing?.isPinned ?? false,
      pinnedAt: existing?.pinnedAt,
      reminderDay: existing?.reminderDay,
      reminderTime: existing?.reminderTime,
      version: (existing?.version ?? 0) + 1,
      updatedAt: now,
      cloudId: existing?.cloudId,
      ownerUserId: existing?.ownerUserId,
      syncStatus: existing?.syncStatus ?? 'localOnly',
      lastSyncedAt: existing?.lastSyncedAt,
    );

    await _routineRepository.saveRoutine(publishedRoutine);
    if (_isCreateDraft(snapshot)) {
      await clearCreateDrafts();
    } else {
      await _dao.deleteDraft(draftId);
    }
    return publishedRoutine;
  }

  @override
  Future<void> discardDraft(String draftId) async {
    final row = await _dao.getDraftById(draftId);
    if (row == null) return;
    final snapshot = _mapRow(row);
    if (_isCreateDraft(snapshot)) {
      await clearCreateDrafts();
      return;
    }
    await _dao.deleteDraft(draftId);
  }

  RoutineComposerDraftSnapshot _mapRow(RoutineComposerDraftRow row) {
    return RoutineComposerDraftSnapshot(
      draftId: row.draftId,
      mode: RoutineComposerModeX.fromStorage(row.mode),
      sourceRoutineId: row.sourceRoutineId,
      title: row.title ?? '',
      iconKey: row.iconKey,
      colorHex: row.colorHex,
      steps: _normalizeStepOrder(
        RoutineComposerStepDraft.listFromJsonString(row.stepsJson),
      ),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  List<RoutineComposerStepDraft> _normalizeStepOrder(
    List<RoutineComposerStepDraft> steps,
  ) {
    return [
      for (var index = 0; index < steps.length; index += 1)
        steps[index].copyWith(sortOrder: index),
    ];
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

  bool _hasMeaningfulContent(RoutineComposerDraftSnapshot snapshot) {
    return snapshot.title.trim().isNotEmpty ||
        snapshot.steps.any((step) => step.text.trim().isNotEmpty);
  }

  bool _isCreateDraft(RoutineComposerDraftSnapshot snapshot) {
    return snapshot.mode == RoutineComposerMode.create &&
        snapshot.sourceRoutineId == null;
  }
}

final routineComposerDraftRepositoryProvider =
    Provider<RoutineComposerDraftRepository>((ref) {
      final db = ref.read(localDbProvider);
      final routineRepository = ref.read(routineRepositoryProvider);
      return RoutineComposerDraftRepositoryImpl(
        db.routineComposerDraftDao,
        routineRepository,
      );
    });

final latestCreateRoutineDraftProvider =
    FutureProvider<RoutineComposerDraftSnapshot?>((ref) {
      return ref
          .read(routineComposerDraftRepositoryProvider)
          .latestCreateDraft();
    });
