import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pebble_routines/data/local/routine_dao.dart';
import 'package:pebble_routines/data/local/cloud_account_dao.dart';
import 'package:pebble_routines/data/local/routine_run_dao.dart';
import 'package:pebble_routines/data/local/routine_session_dao.dart';
import 'package:pebble_routines/data/local/routine_reminder_dao.dart';
import 'package:pebble_routines/data/local/routine_composer_draft_dao.dart';
import 'package:pebble_routines/data/local/sync_outbox_dao.dart';

part 'local_db.g.dart';

// Pebble's app database is mobile/desktop-only. Flutter web is intentionally
// unsupported until a Drift web storage backend is added.
@DataClassName('Routine')
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()(); // primary key
  TextColumn get title => text()();
  TextColumn get stepsJson => text()(); // serialized steps as JSON
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get emoji => text().nullable()();
  IntColumn get colorHex => integer().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get pinnedAt => dateTime().nullable()();
  // Reminder fields
  IntColumn get reminderDay => integer().nullable()(); // 1=Mon ... 7=Sun
  TextColumn get reminderTime => text().nullable()(); // e.g. "10:00 AM"
  // New: optimistic concurrency/versioning and last update timestamp
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get cloudId => text().nullable()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

@DataClassName('RoutineRun')
class RoutineRuns extends Table {
  TextColumn get id => text()(); // uuid, primary key
  TextColumn get routineId => text()();
  TextColumn get routineTitle => text()(); // denormalized
  DateTimeColumn get finishedAt => dateTime()();
  TextColumn get stepCompletionData =>
      text().nullable()(); // JSON string of step timestamps and metadata
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncMetadataJson => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoutineReminder')
class RoutineReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer()();
  IntColumn get dayOfWeek => integer()(); // 1=Monday ... 7=Sunday
  TextColumn get time => text()(); // e.g. "9:00 AM"
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get cloudId => text().nullable()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

@DataClassName('RoutineSessionRow')
class RoutineSessions extends Table {
  TextColumn get sessionId => text()();
  IntColumn get routineId => integer()();
  TextColumn get routineTitleSnapshot => text()();
  TextColumn get workspaceId => text().nullable()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get storageScope => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get status => text()();
  IntColumn get currentStepIndex => integer()();
  IntColumn get totalStepCount => integer()();
  IntColumn get baseRoutineVersion => integer().nullable()();
  TextColumn get stepStatesJson => text()();
  TextColumn get routineSnapshotJson => text()();
  TextColumn get syncMetadataJson => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get discardedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

@DataClassName('RoutineComposerDraftRow')
class RoutineComposerDrafts extends Table {
  TextColumn get draftId => text()();
  TextColumn get mode => text()();
  IntColumn get sourceRoutineId => integer().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  IntColumn get colorHex => integer().nullable()();
  TextColumn get stepsJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {draftId};
}

@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastErrorSummary => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CloudAccountStateRow')
class CloudAccountStates extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(1))();
  TextColumn get entitlementTier =>
      text().withDefault(const Constant('personalFree'))();
  TextColumn get pendingTier => text().nullable()();
  TextColumn get bootstrapStatus =>
      text().withDefault(const Constant('idle'))();
  TextColumn get userId => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get authProvider => text().nullable()();
  DateTimeColumn get lastBootstrapAt => dateTime().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastSyncError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {singletonId};
}

/// The app's single source of truth: an on-device SQLite database.
@DriftDatabase(
  tables: [
    Routines,
    RoutineRuns,
    RoutineReminders,
    RoutineSessions,
    RoutineComposerDrafts,
    SyncOutbox,
    CloudAccountStates,
  ],
  daos: [
    RoutineDao,
    RoutineRunDao,
    RoutineReminderDao,
    RoutineSessionDao,
    RoutineComposerDraftDao,
    SyncOutboxDao,
    CloudAccountDao,
  ],
)
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  LocalDb.forTesting(super.executor);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        try {
          await m.addColumn(routines, routines.emoji);
        } catch (_) {}
        try {
          await m.addColumn(routines, routines.colorHex);
        } catch (_) {}
      }
      if (from < 3) {
        try {
          await m.addColumn(
            routines,
            routines.isPinned as GeneratedColumn<Object>,
          );
        } catch (_) {}
        try {
          await m.addColumn(
            routines,
            routines.pinnedAt as GeneratedColumn<Object>,
          );
        } catch (_) {}
      }
      if (from < 5) {
        try {
          await m.addColumn(
            routineRuns,
            routineRuns.stepCompletionData as GeneratedColumn<Object>,
          );
        } catch (_) {}
      }
      if (from < 6) {
        // Ensure stepCompletionData column exists (force migration)
        try {
          await m.addColumn(
            routineRuns,
            routineRuns.stepCompletionData as GeneratedColumn<Object>,
          );
        } catch (_) {
          // Column might already exist, that's okay
        }
      }
      if (from < 7) {
        // Add version and updatedAt to routines
        try {
          await m.addColumn(
            routines,
            routines.version as GeneratedColumn<Object>,
          );
        } catch (_) {}
        // SQLite ALTER TABLE only allows constant defaults, so add updated_at manually.
        await customStatement(
          'ALTER TABLE routines ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        ).catchError((_) {});
        await customStatement(
          "UPDATE routines SET updated_at = CAST(strftime('%s','now') AS INTEGER) WHERE updated_at = 0",
        );
      }
      if (from < 8) {
        // Add reminderDay and reminderTime
        try {
          await m.addColumn(
            routines,
            routines.reminderDay as GeneratedColumn<Object>,
          );
        } catch (_) {}
        try {
          await m.addColumn(
            routines,
            routines.reminderTime as GeneratedColumn<Object>,
          );
        } catch (_) {}
      }
      if (from < 9) {
        // Create routine_reminders table
        await m.createTable(routineReminders);
      }
      if (from < 10) {
        await m.createTable(routineSessions);
      }
      if (from < 11) {
        try {
          await m.addColumn(routines, routines.cloudId);
        } catch (_) {}
        try {
          await m.addColumn(routines, routines.ownerUserId);
        } catch (_) {}
        try {
          await m.addColumn(routines, routines.syncStatus);
        } catch (_) {}
        try {
          await m.addColumn(routines, routines.lastSyncedAt);
        } catch (_) {}

        try {
          await m.addColumn(routineRuns, routineRuns.ownerUserId);
        } catch (_) {}
        try {
          await m.addColumn(routineRuns, routineRuns.syncStatus);
        } catch (_) {}
        try {
          await m.addColumn(routineRuns, routineRuns.lastSyncedAt);
        } catch (_) {}
        try {
          await m.addColumn(routineRuns, routineRuns.syncMetadataJson);
        } catch (_) {}
        await customStatement(
          'ALTER TABLE routine_runs ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        ).catchError((_) {});
        await customStatement(
          "UPDATE routine_runs SET updated_at = CAST(strftime('%s','now') AS INTEGER) WHERE updated_at = 0",
        );

        await customStatement(
          'ALTER TABLE routine_reminders ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        ).catchError((_) {});
        await customStatement(
          "UPDATE routine_reminders SET updated_at = CAST(strftime('%s','now') AS INTEGER) WHERE updated_at = 0",
        );
        try {
          await m.addColumn(routineReminders, routineReminders.cloudId);
        } catch (_) {}
        try {
          await m.addColumn(routineReminders, routineReminders.ownerUserId);
        } catch (_) {}
        try {
          await m.addColumn(routineReminders, routineReminders.syncStatus);
        } catch (_) {}
        try {
          await m.addColumn(routineReminders, routineReminders.lastSyncedAt);
        } catch (_) {}

        try {
          await m.createTable(syncOutbox);
        } catch (_) {}
        try {
          await m.createTable(cloudAccountStates);
        } catch (_) {}
      }
      if (from < 12) {
        try {
          await m.createTable(routineComposerDrafts);
        } catch (_) {}
      }
    },
    // Defensive: ensure columns exist even if prior migrations were skipped
    beforeOpen: (details) async {
      Future<bool> columnExists(String table, String column) async {
        final rows = await customSelect('PRAGMA table_info($table)').get();
        for (final row in rows) {
          final name = row.data['name'] as String?;
          if (name == column) return true;
        }
        return false;
      }

      // Ensure required columns exist on existing installs
      if (!await columnExists('routines', 'version')) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
        );
      }
      if (!await columnExists('routines', 'updated_at')) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          "UPDATE routines SET updated_at = CAST(strftime('%s','now') AS INTEGER) WHERE updated_at = 0",
        );
      }
      if (!await columnExists('routines', 'reminder_day')) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN reminder_day INTEGER NULL',
        );
      }
      if (!await columnExists('routines', 'reminder_time')) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN reminder_time TEXT NULL',
        );
      }
      if (!await columnExists('routines', 'cloud_id')) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN cloud_id TEXT NULL',
        );
      }
      if (!await columnExists('routines', 'owner_user_id')) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN owner_user_id TEXT NULL',
        );
      }
      if (!await columnExists('routines', 'sync_status')) {
        await customStatement(
          "ALTER TABLE routines ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'localOnly'",
        );
      }
      if (!await columnExists('routines', 'last_synced_at')) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN last_synced_at TEXT NULL',
        );
      }

      if (!await columnExists('routine_runs', 'owner_user_id')) {
        await customStatement(
          'ALTER TABLE routine_runs ADD COLUMN owner_user_id TEXT NULL',
        );
      }
      if (!await columnExists('routine_runs', 'sync_status')) {
        await customStatement(
          "ALTER TABLE routine_runs ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'localOnly'",
        );
      }
      if (!await columnExists('routine_runs', 'last_synced_at')) {
        await customStatement(
          'ALTER TABLE routine_runs ADD COLUMN last_synced_at TEXT NULL',
        );
      }
      if (!await columnExists('routine_runs', 'sync_metadata_json')) {
        await customStatement(
          'ALTER TABLE routine_runs ADD COLUMN sync_metadata_json TEXT NULL',
        );
      }
      if (!await columnExists('routine_runs', 'updated_at')) {
        await customStatement(
          'ALTER TABLE routine_runs ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          "UPDATE routine_runs SET updated_at = CAST(strftime('%s','now') AS INTEGER) WHERE updated_at = 0",
        );
      }

      if (!await columnExists('routine_reminders', 'updated_at')) {
        await customStatement(
          'ALTER TABLE routine_reminders ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          "UPDATE routine_reminders SET updated_at = CAST(strftime('%s','now') AS INTEGER) WHERE updated_at = 0",
        );
      }
      if (!await columnExists('routine_reminders', 'cloud_id')) {
        await customStatement(
          'ALTER TABLE routine_reminders ADD COLUMN cloud_id TEXT NULL',
        );
      }
      if (!await columnExists('routine_reminders', 'owner_user_id')) {
        await customStatement(
          'ALTER TABLE routine_reminders ADD COLUMN owner_user_id TEXT NULL',
        );
      }
      if (!await columnExists('routine_reminders', 'sync_status')) {
        await customStatement(
          "ALTER TABLE routine_reminders ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'localOnly'",
        );
      }
      if (!await columnExists('routine_reminders', 'last_synced_at')) {
        await customStatement(
          'ALTER TABLE routine_reminders ADD COLUMN last_synced_at TEXT NULL',
        );
      }

      final sessionTableExists = await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'routine_sessions'",
      ).get();
      if (sessionTableExists.isEmpty) {
        await customStatement('''
          CREATE TABLE routine_sessions (
            session_id TEXT NOT NULL PRIMARY KEY,
            routine_id INTEGER NOT NULL,
            routine_title_snapshot TEXT NOT NULL,
            workspace_id TEXT NULL,
            owner_user_id TEXT NULL,
            storage_scope TEXT NOT NULL,
            started_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            status TEXT NOT NULL,
            current_step_index INTEGER NOT NULL,
            total_step_count INTEGER NOT NULL,
            base_routine_version INTEGER NULL,
            step_states_json TEXT NOT NULL,
            routine_snapshot_json TEXT NOT NULL,
            sync_metadata_json TEXT NULL,
            completed_at TEXT NULL,
            discarded_at TEXT NULL
          )
        ''');
      }

      final outboxTableExists = await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sync_outbox'",
      ).get();
      if (outboxTableExists.isEmpty) {
        await customStatement('''
          CREATE TABLE sync_outbox (
            id TEXT NOT NULL PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload_json TEXT NULL,
            attempt_count INTEGER NOT NULL DEFAULT 0,
            last_error_summary TEXT NULL,
            next_attempt_at TEXT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      }

      final accountStateTableExists = await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'cloud_account_states'",
      ).get();
      if (accountStateTableExists.isEmpty) {
        await customStatement('''
          CREATE TABLE cloud_account_states (
            singleton_id INTEGER NOT NULL PRIMARY KEY DEFAULT 1,
            entitlement_tier TEXT NOT NULL DEFAULT 'personalFree',
            pending_tier TEXT NULL,
            bootstrap_status TEXT NOT NULL DEFAULT 'idle',
            user_id TEXT NULL,
            email TEXT NULL,
            auth_provider TEXT NULL,
            last_bootstrap_at TEXT NULL,
            last_sync_at TEXT NULL,
            last_sync_error TEXT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      }

      final composerDraftTableExists = await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'routine_composer_drafts'",
      ).get();
      if (composerDraftTableExists.isEmpty) {
        await customStatement('''
          CREATE TABLE routine_composer_drafts (
            draft_id TEXT NOT NULL PRIMARY KEY,
            mode TEXT NOT NULL,
            source_routine_id INTEGER NULL,
            title TEXT NULL,
            icon_key TEXT NULL,
            color_hex INTEGER NULL,
            steps_json TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      }

      await customStatement(
        'CREATE INDEX IF NOT EXISTS routine_sessions_status_updated_idx ON routine_sessions (status, updated_at DESC)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS routine_sessions_routine_id_idx ON routine_sessions (routine_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS routines_cloud_id_idx ON routines (cloud_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS routine_reminders_cloud_id_idx ON routine_reminders (cloud_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS routine_composer_drafts_source_idx ON routine_composer_drafts (mode, source_routine_id, updated_at DESC)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS sync_outbox_next_attempt_idx ON sync_outbox (next_attempt_at, updated_at)',
      );
      await customStatement(
        "CREATE UNIQUE INDEX IF NOT EXISTS routine_sessions_active_routine_idx ON routine_sessions (routine_id) WHERE status = 'active'",
      );
    },
  );

  // Optional: add migration strategies here
}

/// Opens the database file in the device’s documents directory.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pebble_routines.sqlite'));
    return NativeDatabase(file);
  });
}
