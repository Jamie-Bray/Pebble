import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/ui/cloud_backup_screen.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';
import 'package:pebble_routines/features/sync/backup_status.dart';

void main() {
  test('pending receipt only claims uploading while a pass is running', () {
    for (final phase in BackupPhase.values) {
      final storage = CompletionStorage.fromBackupStatus(
        'pendingUpload',
        BackupStatus(phase: phase),
      );
      expect(
        storage == CompletionStorage.deviceBackupOn,
        phase == BackupPhase.backingUp,
        reason: phase.name,
      );
      expect(storage, isNot(CompletionStorage.backedUp));
    }
    expect(
      CompletionStorage.fromBackupStatus(
        'synced',
        const BackupStatus(phase: BackupPhase.upToDate),
      ),
      CompletionStorage.backedUp,
    );
    expect(
      CompletionStorage.fromBackupStatus(
        'synced',
        const BackupStatus(phase: BackupPhase.waiting, pendingCount: 1),
      ),
      CompletionStorage.waiting,
    );
  });

  test('open run observes backup and late caption updates', () async {
    final db = LocalDb.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [localDbProvider.overrideWithValue(db)],
    );
    final now = DateTime(2026, 10, 7);
    final run = RoutineRun(
      id: 'receipt',
      routineId: '1',
      routineTitle: 'Home',
      finishedAt: now,
      stepCompletionData: '{}',
      ownerUserId: null,
      syncStatus: 'pendingUpload',
      lastSyncedAt: null,
      syncMetadataJson: null,
      updatedAt: now,
    );
    await db.routineRunDao.insertOrUpdateRun(run);
    final synced = Completer<RoutineRun>();
    final sub = container.listen(routineRunProvider(run.id), (_, value) {
      if (value.valueOrNull?.syncStatus == 'synced') {
        synced.complete(value.requireValue!);
      }
    }, fireImmediately: true);
    try {
      expect(
        (await container.read(routineRunProvider(run.id).future))!.syncStatus,
        'pendingUpload',
      );
      await db.routineRunDao.insertOrUpdateRun(
        run.copyWith(
          syncStatus: 'synced',
          stepCompletionData: const Value('{"caption":"Door closed"}'),
        ),
      );
      final updated = await synced.future;
      expect(updated.stepCompletionData, contains('Door closed'));
    } finally {
      sub.close();
      container.dispose();
      await db.close();
    }
  });

  testWidgets('backup switch exposes its name and screen-reader action', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final semantics = tester.ensureSemantics();
    var enabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupStatusCard(
            status: const BackupStatus(phase: BackupPhase.upToDate),
            now: DateTime(2026, 10, 7),
            switchValue: enabled,
            onSwitchChanged: (value) => enabled = value,
          ),
        ),
      ),
    );
    final node = tester.getSemantics(
      find.byKey(const ValueKey('backup_switch')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        nodeId: node.id,
        type: SemanticsAction.tap,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pump();
    expect(enabled, isFalse);
    semantics.dispose();
  });
}
