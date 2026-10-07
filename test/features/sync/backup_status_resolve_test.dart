import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/sync/backup_status.dart';

BackupStatus _resolve({
  PersonalCloudAccessStatus access = PersonalCloudAccessStatus.available,
  bool isRunning = false,
  int pendingCount = 0,
  int stuckCount = 0,
  DateTime? lastBackedUpAt,
  String? lastError,
  int failingCount = 0,
}) => resolveBackupStatus(
  access: access,
  isRunning: isRunning,
  pendingCount: pendingCount,
  stuckCount: stuckCount,
  lastBackedUpAt: lastBackedUpAt,
  lastError: lastError,
  failingCount: failingCount,
);

void main() {
  final at = DateTime(2026, 10, 7, 9);

  test('nothing waiting after a clean pass reads as backed up', () {
    final status = _resolve(lastBackedUpAt: at);
    expect(status.phase, BackupPhase.upToDate);
    expect(status.line(at.add(const Duration(minutes: 4))), contains('4 min'));
  });

  test('waiting changes never read as backed up, even just after a pass', () {
    final status = _resolve(pendingCount: 11, lastBackedUpAt: at);
    expect(status.phase, BackupPhase.waiting);
    expect(status.pendingCount, 11);
    expect(status.line(at), '11 changes waiting · retrying soon');
  });

  test('uploading reads as backing up', () {
    final status = _resolve(isRunning: true, pendingCount: 2);
    expect(status.phase, BackupPhase.backingUp);
    expect(status.line(at), 'Backing up 2 changes…');
  });

  test('a change that keeps failing needs attention', () {
    final status = _resolve(
      pendingCount: 3,
      stuckCount: 1,
      failingCount: 2,
      lastError: "Backup couldn't save your changes.",
    );
    expect(status.phase, BackupPhase.needsAttention);
    expect(status.failingCount, 2);
    expect(status.line(at), contains("1 change couldn't back up"));
  });

  test('repeated failures while offline just wait for the connection', () {
    final status = _resolve(
      pendingCount: 3,
      stuckCount: 3,
      lastError: "You're offline. Changes will back up later.",
    );
    expect(status.phase, BackupPhase.waiting);
    expect(status.offline, isTrue);
    expect(status.headline, 'Waiting for internet');
  });

  test('confirming access offline counts as offline', () {
    final status = _resolve(
      access: PersonalCloudAccessStatus.offlinePending,
      pendingCount: 1,
    );
    expect(status.phase, BackupPhase.waiting);
    expect(status.offline, isTrue);
  });

  test('access states map to their phases', () {
    expect(
      _resolve(access: PersonalCloudAccessStatus.offFree).phase,
      BackupPhase.notIncluded,
    );
    expect(
      _resolve(access: PersonalCloudAccessStatus.pausedSignedOut).phase,
      BackupPhase.signedOut,
    );
    expect(
      _resolve(access: PersonalCloudAccessStatus.consentRequired).phase,
      BackupPhase.off,
    );
    expect(
      _resolve(access: PersonalCloudAccessStatus.expiredGrace).phase,
      BackupPhase.paused,
    );
    expect(
      _resolve(access: PersonalCloudAccessStatus.accountSwitchBlocked).phase,
      BackupPhase.needsAttention,
    );
    expect(
      _resolve(access: PersonalCloudAccessStatus.syncing).phase,
      BackupPhase.checking,
    );
  });

  test('no backup time yet is not shown as a spinner on its own', () {
    expect(_resolve().phase, BackupPhase.upToDate);
  });
}
