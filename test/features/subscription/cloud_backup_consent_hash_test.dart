import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_backup_consent_provider.dart';

void main() {
  test('Supabase consent gate uses the current in-app consent hash', () {
    final migration = File(
      'supabase/migrations/011_align_cloud_backup_consent_hash.sql',
    ).readAsStringSync();

    expect(
      cloudBackupConsentTextHash,
      '447b66766fb90e5225c8eec970f296939ecd3568ebdb7287b0b62af8d7796744',
    );
    expect(migration, contains(cloudBackupConsentTextHash));
  });
}
