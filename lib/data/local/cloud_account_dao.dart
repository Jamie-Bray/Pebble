import 'package:drift/drift.dart';

import 'package:pebble_routines/core/database/local_db.dart';

part 'cloud_account_dao.g.dart';

@DriftAccessor(tables: [CloudAccountStates])
class CloudAccountDao extends DatabaseAccessor<LocalDb>
    with _$CloudAccountDaoMixin {
  CloudAccountDao(super.db);

  Future<CloudAccountStateRow?> getState() {
    return (select(
      cloudAccountStates,
    )..where((tbl) => tbl.singletonId.equals(1))).getSingleOrNull();
  }

  Stream<CloudAccountStateRow?> watchState() {
    return (select(
      cloudAccountStates,
    )..where((tbl) => tbl.singletonId.equals(1))).watchSingleOrNull();
  }

  Future<void> upsertState(CloudAccountStateRow row) {
    return into(cloudAccountStates).insertOnConflictUpdate(row);
  }
}
