// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $RoutinesTable extends Routines with TableInfo<$RoutinesTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<int> colorHex = GeneratedColumn<int>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pinnedAt = GeneratedColumn<DateTime>(
    'pinned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderDayMeta = const VerificationMeta(
    'reminderDay',
  );
  @override
  late final GeneratedColumn<int> reminderDay = GeneratedColumn<int>(
    'reminder_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderTimeMeta = const VerificationMeta(
    'reminderTime',
  );
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
    'reminder_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    stepsJson,
    createdAt,
    emoji,
    colorHex,
    isPinned,
    pinnedAt,
    reminderDay,
    reminderTime,
    version,
    updatedAt,
    cloudId,
    ownerUserId,
    syncStatus,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<Routine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    }
    if (data.containsKey('reminder_day')) {
      context.handle(
        _reminderDayMeta,
        reminderDay.isAcceptableOrUnknown(
          data['reminder_day']!,
          _reminderDayMeta,
        ),
      );
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
        _reminderTimeMeta,
        reminderTime.isAcceptableOrUnknown(
          data['reminder_time']!,
          _reminderTimeMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_hex'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pinned_at'],
      ),
      reminderDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_day'],
      ),
      reminderTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_time'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final int id;
  final String title;
  final String stepsJson;
  final DateTime createdAt;
  final String? emoji;
  final int? colorHex;
  final bool isPinned;
  final DateTime? pinnedAt;
  final int? reminderDay;
  final String? reminderTime;
  final int version;
  final DateTime updatedAt;
  final String? cloudId;
  final String? ownerUserId;
  final String syncStatus;
  final DateTime? lastSyncedAt;
  const Routine({
    required this.id,
    required this.title,
    required this.stepsJson,
    required this.createdAt,
    this.emoji,
    this.colorHex,
    required this.isPinned,
    this.pinnedAt,
    this.reminderDay,
    this.reminderTime,
    required this.version,
    required this.updatedAt,
    this.cloudId,
    this.ownerUserId,
    required this.syncStatus,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['steps_json'] = Variable<String>(stepsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || emoji != null) {
      map['emoji'] = Variable<String>(emoji);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<int>(colorHex);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    if (!nullToAbsent || pinnedAt != null) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt);
    }
    if (!nullToAbsent || reminderDay != null) {
      map['reminder_day'] = Variable<int>(reminderDay);
    }
    if (!nullToAbsent || reminderTime != null) {
      map['reminder_time'] = Variable<String>(reminderTime);
    }
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
    }
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      title: Value(title),
      stepsJson: Value(stepsJson),
      createdAt: Value(createdAt),
      emoji: emoji == null && nullToAbsent
          ? const Value.absent()
          : Value(emoji),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      isPinned: Value(isPinned),
      pinnedAt: pinnedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedAt),
      reminderDay: reminderDay == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderDay),
      reminderTime: reminderTime == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderTime),
      version: Value(version),
      updatedAt: Value(updatedAt),
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      syncStatus: Value(syncStatus),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Routine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      emoji: serializer.fromJson<String?>(json['emoji']),
      colorHex: serializer.fromJson<int?>(json['colorHex']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      pinnedAt: serializer.fromJson<DateTime?>(json['pinnedAt']),
      reminderDay: serializer.fromJson<int?>(json['reminderDay']),
      reminderTime: serializer.fromJson<String?>(json['reminderTime']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'emoji': serializer.toJson<String?>(emoji),
      'colorHex': serializer.toJson<int?>(colorHex),
      'isPinned': serializer.toJson<bool>(isPinned),
      'pinnedAt': serializer.toJson<DateTime?>(pinnedAt),
      'reminderDay': serializer.toJson<int?>(reminderDay),
      'reminderTime': serializer.toJson<String?>(reminderTime),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cloudId': serializer.toJson<String?>(cloudId),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  Routine copyWith({
    int? id,
    String? title,
    String? stepsJson,
    DateTime? createdAt,
    Value<String?> emoji = const Value.absent(),
    Value<int?> colorHex = const Value.absent(),
    bool? isPinned,
    Value<DateTime?> pinnedAt = const Value.absent(),
    Value<int?> reminderDay = const Value.absent(),
    Value<String?> reminderTime = const Value.absent(),
    int? version,
    DateTime? updatedAt,
    Value<String?> cloudId = const Value.absent(),
    Value<String?> ownerUserId = const Value.absent(),
    String? syncStatus,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => Routine(
    id: id ?? this.id,
    title: title ?? this.title,
    stepsJson: stepsJson ?? this.stepsJson,
    createdAt: createdAt ?? this.createdAt,
    emoji: emoji.present ? emoji.value : this.emoji,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    isPinned: isPinned ?? this.isPinned,
    pinnedAt: pinnedAt.present ? pinnedAt.value : this.pinnedAt,
    reminderDay: reminderDay.present ? reminderDay.value : this.reminderDay,
    reminderTime: reminderTime.present ? reminderTime.value : this.reminderTime,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    syncStatus: syncStatus ?? this.syncStatus,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
      reminderDay: data.reminderDay.present
          ? data.reminderDay.value
          : this.reminderDay,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('emoji: $emoji, ')
          ..write('colorHex: $colorHex, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('reminderDay: $reminderDay, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cloudId: $cloudId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    stepsJson,
    createdAt,
    emoji,
    colorHex,
    isPinned,
    pinnedAt,
    reminderDay,
    reminderTime,
    version,
    updatedAt,
    cloudId,
    ownerUserId,
    syncStatus,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.title == this.title &&
          other.stepsJson == this.stepsJson &&
          other.createdAt == this.createdAt &&
          other.emoji == this.emoji &&
          other.colorHex == this.colorHex &&
          other.isPinned == this.isPinned &&
          other.pinnedAt == this.pinnedAt &&
          other.reminderDay == this.reminderDay &&
          other.reminderTime == this.reminderTime &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.cloudId == this.cloudId &&
          other.ownerUserId == this.ownerUserId &&
          other.syncStatus == this.syncStatus &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> stepsJson;
  final Value<DateTime> createdAt;
  final Value<String?> emoji;
  final Value<int?> colorHex;
  final Value<bool> isPinned;
  final Value<DateTime?> pinnedAt;
  final Value<int?> reminderDay;
  final Value<String?> reminderTime;
  final Value<int> version;
  final Value<DateTime> updatedAt;
  final Value<String?> cloudId;
  final Value<String?> ownerUserId;
  final Value<String> syncStatus;
  final Value<DateTime?> lastSyncedAt;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.emoji = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.reminderDay = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  RoutinesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String stepsJson,
    required DateTime createdAt,
    this.emoji = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.reminderDay = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  }) : title = Value(title),
       stepsJson = Value(stepsJson),
       createdAt = Value(createdAt);
  static Insertable<Routine> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? stepsJson,
    Expression<DateTime>? createdAt,
    Expression<String>? emoji,
    Expression<int>? colorHex,
    Expression<bool>? isPinned,
    Expression<DateTime>? pinnedAt,
    Expression<int>? reminderDay,
    Expression<String>? reminderTime,
    Expression<int>? version,
    Expression<DateTime>? updatedAt,
    Expression<String>? cloudId,
    Expression<String>? ownerUserId,
    Expression<String>? syncStatus,
    Expression<DateTime>? lastSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (emoji != null) 'emoji': emoji,
      if (colorHex != null) 'color_hex': colorHex,
      if (isPinned != null) 'is_pinned': isPinned,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (reminderDay != null) 'reminder_day': reminderDay,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cloudId != null) 'cloud_id': cloudId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    });
  }

  RoutinesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? stepsJson,
    Value<DateTime>? createdAt,
    Value<String?>? emoji,
    Value<int?>? colorHex,
    Value<bool>? isPinned,
    Value<DateTime?>? pinnedAt,
    Value<int?>? reminderDay,
    Value<String?>? reminderTime,
    Value<int>? version,
    Value<DateTime>? updatedAt,
    Value<String?>? cloudId,
    Value<String?>? ownerUserId,
    Value<String>? syncStatus,
    Value<DateTime?>? lastSyncedAt,
  }) {
    return RoutinesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      stepsJson: stepsJson ?? this.stepsJson,
      createdAt: createdAt ?? this.createdAt,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      reminderDay: reminderDay ?? this.reminderDay,
      reminderTime: reminderTime ?? this.reminderTime,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      cloudId: cloudId ?? this.cloudId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<int>(colorHex.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt.value);
    }
    if (reminderDay.present) {
      map['reminder_day'] = Variable<int>(reminderDay.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('emoji: $emoji, ')
          ..write('colorHex: $colorHex, ')
          ..write('isPinned: $isPinned, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('reminderDay: $reminderDay, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cloudId: $cloudId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }
}

class $RoutineRunsTable extends RoutineRuns
    with TableInfo<$RoutineRunsTable, RoutineRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineTitleMeta = const VerificationMeta(
    'routineTitle',
  );
  @override
  late final GeneratedColumn<String> routineTitle = GeneratedColumn<String>(
    'routine_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepCompletionDataMeta =
      const VerificationMeta('stepCompletionData');
  @override
  late final GeneratedColumn<String> stepCompletionData =
      GeneratedColumn<String>(
        'step_completion_data',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncMetadataJsonMeta = const VerificationMeta(
    'syncMetadataJson',
  );
  @override
  late final GeneratedColumn<String> syncMetadataJson = GeneratedColumn<String>(
    'sync_metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    routineTitle,
    finishedAt,
    stepCompletionData,
    ownerUserId,
    syncStatus,
    lastSyncedAt,
    syncMetadataJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('routine_title')) {
      context.handle(
        _routineTitleMeta,
        routineTitle.isAcceptableOrUnknown(
          data['routine_title']!,
          _routineTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_routineTitleMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_finishedAtMeta);
    }
    if (data.containsKey('step_completion_data')) {
      context.handle(
        _stepCompletionDataMeta,
        stepCompletionData.isAcceptableOrUnknown(
          data['step_completion_data']!,
          _stepCompletionDataMeta,
        ),
      );
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_metadata_json')) {
      context.handle(
        _syncMetadataJsonMeta,
        syncMetadataJson.isAcceptableOrUnknown(
          data['sync_metadata_json']!,
          _syncMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      )!,
      routineTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_title'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      )!,
      stepCompletionData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}step_completion_data'],
      ),
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      syncMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_metadata_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RoutineRunsTable createAlias(String alias) {
    return $RoutineRunsTable(attachedDatabase, alias);
  }
}

class RoutineRun extends DataClass implements Insertable<RoutineRun> {
  final String id;
  final String routineId;
  final String routineTitle;
  final DateTime finishedAt;
  final String? stepCompletionData;
  final String? ownerUserId;
  final String syncStatus;
  final DateTime? lastSyncedAt;
  final String? syncMetadataJson;
  final DateTime updatedAt;
  const RoutineRun({
    required this.id,
    required this.routineId,
    required this.routineTitle,
    required this.finishedAt,
    this.stepCompletionData,
    this.ownerUserId,
    required this.syncStatus,
    this.lastSyncedAt,
    this.syncMetadataJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_id'] = Variable<String>(routineId);
    map['routine_title'] = Variable<String>(routineTitle);
    map['finished_at'] = Variable<DateTime>(finishedAt);
    if (!nullToAbsent || stepCompletionData != null) {
      map['step_completion_data'] = Variable<String>(stepCompletionData);
    }
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || syncMetadataJson != null) {
      map['sync_metadata_json'] = Variable<String>(syncMetadataJson);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RoutineRunsCompanion toCompanion(bool nullToAbsent) {
    return RoutineRunsCompanion(
      id: Value(id),
      routineId: Value(routineId),
      routineTitle: Value(routineTitle),
      finishedAt: Value(finishedAt),
      stepCompletionData: stepCompletionData == null && nullToAbsent
          ? const Value.absent()
          : Value(stepCompletionData),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      syncStatus: Value(syncStatus),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      syncMetadataJson: syncMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(syncMetadataJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory RoutineRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineRun(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String>(json['routineId']),
      routineTitle: serializer.fromJson<String>(json['routineTitle']),
      finishedAt: serializer.fromJson<DateTime>(json['finishedAt']),
      stepCompletionData: serializer.fromJson<String?>(
        json['stepCompletionData'],
      ),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      syncMetadataJson: serializer.fromJson<String?>(json['syncMetadataJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String>(routineId),
      'routineTitle': serializer.toJson<String>(routineTitle),
      'finishedAt': serializer.toJson<DateTime>(finishedAt),
      'stepCompletionData': serializer.toJson<String?>(stepCompletionData),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'syncMetadataJson': serializer.toJson<String?>(syncMetadataJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RoutineRun copyWith({
    String? id,
    String? routineId,
    String? routineTitle,
    DateTime? finishedAt,
    Value<String?> stepCompletionData = const Value.absent(),
    Value<String?> ownerUserId = const Value.absent(),
    String? syncStatus,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<String?> syncMetadataJson = const Value.absent(),
    DateTime? updatedAt,
  }) => RoutineRun(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    routineTitle: routineTitle ?? this.routineTitle,
    finishedAt: finishedAt ?? this.finishedAt,
    stepCompletionData: stepCompletionData.present
        ? stepCompletionData.value
        : this.stepCompletionData,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    syncStatus: syncStatus ?? this.syncStatus,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    syncMetadataJson: syncMetadataJson.present
        ? syncMetadataJson.value
        : this.syncMetadataJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RoutineRun copyWithCompanion(RoutineRunsCompanion data) {
    return RoutineRun(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      routineTitle: data.routineTitle.present
          ? data.routineTitle.value
          : this.routineTitle,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      stepCompletionData: data.stepCompletionData.present
          ? data.stepCompletionData.value
          : this.stepCompletionData,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      syncMetadataJson: data.syncMetadataJson.present
          ? data.syncMetadataJson.value
          : this.syncMetadataJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineRun(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('routineTitle: $routineTitle, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('stepCompletionData: $stepCompletionData, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncMetadataJson: $syncMetadataJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    routineTitle,
    finishedAt,
    stepCompletionData,
    ownerUserId,
    syncStatus,
    lastSyncedAt,
    syncMetadataJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineRun &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.routineTitle == this.routineTitle &&
          other.finishedAt == this.finishedAt &&
          other.stepCompletionData == this.stepCompletionData &&
          other.ownerUserId == this.ownerUserId &&
          other.syncStatus == this.syncStatus &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.syncMetadataJson == this.syncMetadataJson &&
          other.updatedAt == this.updatedAt);
}

class RoutineRunsCompanion extends UpdateCompanion<RoutineRun> {
  final Value<String> id;
  final Value<String> routineId;
  final Value<String> routineTitle;
  final Value<DateTime> finishedAt;
  final Value<String?> stepCompletionData;
  final Value<String?> ownerUserId;
  final Value<String> syncStatus;
  final Value<DateTime?> lastSyncedAt;
  final Value<String?> syncMetadataJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RoutineRunsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.routineTitle = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.stepCompletionData = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.syncMetadataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineRunsCompanion.insert({
    required String id,
    required String routineId,
    required String routineTitle,
    required DateTime finishedAt,
    this.stepCompletionData = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.syncMetadataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routineId = Value(routineId),
       routineTitle = Value(routineTitle),
       finishedAt = Value(finishedAt);
  static Insertable<RoutineRun> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? routineTitle,
    Expression<DateTime>? finishedAt,
    Expression<String>? stepCompletionData,
    Expression<String>? ownerUserId,
    Expression<String>? syncStatus,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? syncMetadataJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (routineTitle != null) 'routine_title': routineTitle,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (stepCompletionData != null)
        'step_completion_data': stepCompletionData,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (syncMetadataJson != null) 'sync_metadata_json': syncMetadataJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? routineId,
    Value<String>? routineTitle,
    Value<DateTime>? finishedAt,
    Value<String?>? stepCompletionData,
    Value<String?>? ownerUserId,
    Value<String>? syncStatus,
    Value<DateTime?>? lastSyncedAt,
    Value<String?>? syncMetadataJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RoutineRunsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      routineTitle: routineTitle ?? this.routineTitle,
      finishedAt: finishedAt ?? this.finishedAt,
      stepCompletionData: stepCompletionData ?? this.stepCompletionData,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncMetadataJson: syncMetadataJson ?? this.syncMetadataJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (routineTitle.present) {
      map['routine_title'] = Variable<String>(routineTitle.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (stepCompletionData.present) {
      map['step_completion_data'] = Variable<String>(stepCompletionData.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (syncMetadataJson.present) {
      map['sync_metadata_json'] = Variable<String>(syncMetadataJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineRunsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('routineTitle: $routineTitle, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('stepCompletionData: $stepCompletionData, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncMetadataJson: $syncMetadataJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineRemindersTable extends RoutineReminders
    with TableInfo<$RoutineRemindersTable, RoutineReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
    'day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    dayOfWeek,
    time,
    isEnabled,
    createdAt,
    updatedAt,
    cloudId,
    ownerUserId,
    syncStatus,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}routine_id'],
      )!,
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_week'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $RoutineRemindersTable createAlias(String alias) {
    return $RoutineRemindersTable(attachedDatabase, alias);
  }
}

class RoutineReminder extends DataClass implements Insertable<RoutineReminder> {
  final int id;
  final int routineId;
  final int dayOfWeek;
  final String time;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? cloudId;
  final String? ownerUserId;
  final String syncStatus;
  final DateTime? lastSyncedAt;
  const RoutineReminder({
    required this.id,
    required this.routineId,
    required this.dayOfWeek,
    required this.time,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.cloudId,
    this.ownerUserId,
    required this.syncStatus,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['routine_id'] = Variable<int>(routineId);
    map['day_of_week'] = Variable<int>(dayOfWeek);
    map['time'] = Variable<String>(time);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
    }
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  RoutineRemindersCompanion toCompanion(bool nullToAbsent) {
    return RoutineRemindersCompanion(
      id: Value(id),
      routineId: Value(routineId),
      dayOfWeek: Value(dayOfWeek),
      time: Value(time),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      syncStatus: Value(syncStatus),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory RoutineReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineReminder(
      id: serializer.fromJson<int>(json['id']),
      routineId: serializer.fromJson<int>(json['routineId']),
      dayOfWeek: serializer.fromJson<int>(json['dayOfWeek']),
      time: serializer.fromJson<String>(json['time']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineId': serializer.toJson<int>(routineId),
      'dayOfWeek': serializer.toJson<int>(dayOfWeek),
      'time': serializer.toJson<String>(time),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cloudId': serializer.toJson<String?>(cloudId),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  RoutineReminder copyWith({
    int? id,
    int? routineId,
    int? dayOfWeek,
    String? time,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> cloudId = const Value.absent(),
    Value<String?> ownerUserId = const Value.absent(),
    String? syncStatus,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => RoutineReminder(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    time: time ?? this.time,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    syncStatus: syncStatus ?? this.syncStatus,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  RoutineReminder copyWithCompanion(RoutineRemindersCompanion data) {
    return RoutineReminder(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      time: data.time.present ? data.time.value : this.time,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineReminder(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('time: $time, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cloudId: $cloudId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    dayOfWeek,
    time,
    isEnabled,
    createdAt,
    updatedAt,
    cloudId,
    ownerUserId,
    syncStatus,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineReminder &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.time == this.time &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cloudId == this.cloudId &&
          other.ownerUserId == this.ownerUserId &&
          other.syncStatus == this.syncStatus &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class RoutineRemindersCompanion extends UpdateCompanion<RoutineReminder> {
  final Value<int> id;
  final Value<int> routineId;
  final Value<int> dayOfWeek;
  final Value<String> time;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> cloudId;
  final Value<String?> ownerUserId;
  final Value<String> syncStatus;
  final Value<DateTime?> lastSyncedAt;
  const RoutineRemindersCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.time = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  RoutineRemindersCompanion.insert({
    this.id = const Value.absent(),
    required int routineId,
    required int dayOfWeek,
    required String time,
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  }) : routineId = Value(routineId),
       dayOfWeek = Value(dayOfWeek),
       time = Value(time);
  static Insertable<RoutineReminder> custom({
    Expression<int>? id,
    Expression<int>? routineId,
    Expression<int>? dayOfWeek,
    Expression<String>? time,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? cloudId,
    Expression<String>? ownerUserId,
    Expression<String>? syncStatus,
    Expression<DateTime>? lastSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (time != null) 'time': time,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cloudId != null) 'cloud_id': cloudId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    });
  }

  RoutineRemindersCompanion copyWith({
    Value<int>? id,
    Value<int>? routineId,
    Value<int>? dayOfWeek,
    Value<String>? time,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? cloudId,
    Value<String?>? ownerUserId,
    Value<String>? syncStatus,
    Value<DateTime?>? lastSyncedAt,
  }) {
    return RoutineRemindersCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cloudId: cloudId ?? this.cloudId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineRemindersCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('time: $time, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cloudId: $cloudId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }
}

class $RoutineSessionsTable extends RoutineSessions
    with TableInfo<$RoutineSessionsTable, RoutineSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineTitleSnapshotMeta =
      const VerificationMeta('routineTitleSnapshot');
  @override
  late final GeneratedColumn<String> routineTitleSnapshot =
      GeneratedColumn<String>(
        'routine_title_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storageScopeMeta = const VerificationMeta(
    'storageScope',
  );
  @override
  late final GeneratedColumn<String> storageScope = GeneratedColumn<String>(
    'storage_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentStepIndexMeta = const VerificationMeta(
    'currentStepIndex',
  );
  @override
  late final GeneratedColumn<int> currentStepIndex = GeneratedColumn<int>(
    'current_step_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalStepCountMeta = const VerificationMeta(
    'totalStepCount',
  );
  @override
  late final GeneratedColumn<int> totalStepCount = GeneratedColumn<int>(
    'total_step_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseRoutineVersionMeta =
      const VerificationMeta('baseRoutineVersion');
  @override
  late final GeneratedColumn<int> baseRoutineVersion = GeneratedColumn<int>(
    'base_routine_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepStatesJsonMeta = const VerificationMeta(
    'stepStatesJson',
  );
  @override
  late final GeneratedColumn<String> stepStatesJson = GeneratedColumn<String>(
    'step_states_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineSnapshotJsonMeta =
      const VerificationMeta('routineSnapshotJson');
  @override
  late final GeneratedColumn<String> routineSnapshotJson =
      GeneratedColumn<String>(
        'routine_snapshot_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncMetadataJsonMeta = const VerificationMeta(
    'syncMetadataJson',
  );
  @override
  late final GeneratedColumn<String> syncMetadataJson = GeneratedColumn<String>(
    'sync_metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discardedAtMeta = const VerificationMeta(
    'discardedAt',
  );
  @override
  late final GeneratedColumn<DateTime> discardedAt = GeneratedColumn<DateTime>(
    'discarded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    routineId,
    routineTitleSnapshot,
    workspaceId,
    ownerUserId,
    storageScope,
    startedAt,
    updatedAt,
    status,
    currentStepIndex,
    totalStepCount,
    baseRoutineVersion,
    stepStatesJson,
    routineSnapshotJson,
    syncMetadataJson,
    completedAt,
    discardedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('routine_title_snapshot')) {
      context.handle(
        _routineTitleSnapshotMeta,
        routineTitleSnapshot.isAcceptableOrUnknown(
          data['routine_title_snapshot']!,
          _routineTitleSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_routineTitleSnapshotMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('storage_scope')) {
      context.handle(
        _storageScopeMeta,
        storageScope.isAcceptableOrUnknown(
          data['storage_scope']!,
          _storageScopeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageScopeMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('current_step_index')) {
      context.handle(
        _currentStepIndexMeta,
        currentStepIndex.isAcceptableOrUnknown(
          data['current_step_index']!,
          _currentStepIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentStepIndexMeta);
    }
    if (data.containsKey('total_step_count')) {
      context.handle(
        _totalStepCountMeta,
        totalStepCount.isAcceptableOrUnknown(
          data['total_step_count']!,
          _totalStepCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalStepCountMeta);
    }
    if (data.containsKey('base_routine_version')) {
      context.handle(
        _baseRoutineVersionMeta,
        baseRoutineVersion.isAcceptableOrUnknown(
          data['base_routine_version']!,
          _baseRoutineVersionMeta,
        ),
      );
    }
    if (data.containsKey('step_states_json')) {
      context.handle(
        _stepStatesJsonMeta,
        stepStatesJson.isAcceptableOrUnknown(
          data['step_states_json']!,
          _stepStatesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stepStatesJsonMeta);
    }
    if (data.containsKey('routine_snapshot_json')) {
      context.handle(
        _routineSnapshotJsonMeta,
        routineSnapshotJson.isAcceptableOrUnknown(
          data['routine_snapshot_json']!,
          _routineSnapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_routineSnapshotJsonMeta);
    }
    if (data.containsKey('sync_metadata_json')) {
      context.handle(
        _syncMetadataJsonMeta,
        syncMetadataJson.isAcceptableOrUnknown(
          data['sync_metadata_json']!,
          _syncMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('discarded_at')) {
      context.handle(
        _discardedAtMeta,
        discardedAt.isAcceptableOrUnknown(
          data['discarded_at']!,
          _discardedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  RoutineSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineSessionRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}routine_id'],
      )!,
      routineTitleSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_title_snapshot'],
      )!,
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      ),
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      storageScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_scope'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      currentStepIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_step_index'],
      )!,
      totalStepCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_step_count'],
      )!,
      baseRoutineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_routine_version'],
      ),
      stepStatesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}step_states_json'],
      )!,
      routineSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_snapshot_json'],
      )!,
      syncMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_metadata_json'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      discardedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}discarded_at'],
      ),
    );
  }

  @override
  $RoutineSessionsTable createAlias(String alias) {
    return $RoutineSessionsTable(attachedDatabase, alias);
  }
}

class RoutineSessionRow extends DataClass
    implements Insertable<RoutineSessionRow> {
  final String sessionId;
  final int routineId;
  final String routineTitleSnapshot;
  final String? workspaceId;
  final String? ownerUserId;
  final String storageScope;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String status;
  final int currentStepIndex;
  final int totalStepCount;
  final int? baseRoutineVersion;
  final String stepStatesJson;
  final String routineSnapshotJson;
  final String? syncMetadataJson;
  final DateTime? completedAt;
  final DateTime? discardedAt;
  const RoutineSessionRow({
    required this.sessionId,
    required this.routineId,
    required this.routineTitleSnapshot,
    this.workspaceId,
    this.ownerUserId,
    required this.storageScope,
    required this.startedAt,
    required this.updatedAt,
    required this.status,
    required this.currentStepIndex,
    required this.totalStepCount,
    this.baseRoutineVersion,
    required this.stepStatesJson,
    required this.routineSnapshotJson,
    this.syncMetadataJson,
    this.completedAt,
    this.discardedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['routine_id'] = Variable<int>(routineId);
    map['routine_title_snapshot'] = Variable<String>(routineTitleSnapshot);
    if (!nullToAbsent || workspaceId != null) {
      map['workspace_id'] = Variable<String>(workspaceId);
    }
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['storage_scope'] = Variable<String>(storageScope);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['status'] = Variable<String>(status);
    map['current_step_index'] = Variable<int>(currentStepIndex);
    map['total_step_count'] = Variable<int>(totalStepCount);
    if (!nullToAbsent || baseRoutineVersion != null) {
      map['base_routine_version'] = Variable<int>(baseRoutineVersion);
    }
    map['step_states_json'] = Variable<String>(stepStatesJson);
    map['routine_snapshot_json'] = Variable<String>(routineSnapshotJson);
    if (!nullToAbsent || syncMetadataJson != null) {
      map['sync_metadata_json'] = Variable<String>(syncMetadataJson);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || discardedAt != null) {
      map['discarded_at'] = Variable<DateTime>(discardedAt);
    }
    return map;
  }

  RoutineSessionsCompanion toCompanion(bool nullToAbsent) {
    return RoutineSessionsCompanion(
      sessionId: Value(sessionId),
      routineId: Value(routineId),
      routineTitleSnapshot: Value(routineTitleSnapshot),
      workspaceId: workspaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(workspaceId),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      storageScope: Value(storageScope),
      startedAt: Value(startedAt),
      updatedAt: Value(updatedAt),
      status: Value(status),
      currentStepIndex: Value(currentStepIndex),
      totalStepCount: Value(totalStepCount),
      baseRoutineVersion: baseRoutineVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRoutineVersion),
      stepStatesJson: Value(stepStatesJson),
      routineSnapshotJson: Value(routineSnapshotJson),
      syncMetadataJson: syncMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(syncMetadataJson),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      discardedAt: discardedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(discardedAt),
    );
  }

  factory RoutineSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineSessionRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      routineId: serializer.fromJson<int>(json['routineId']),
      routineTitleSnapshot: serializer.fromJson<String>(
        json['routineTitleSnapshot'],
      ),
      workspaceId: serializer.fromJson<String?>(json['workspaceId']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      storageScope: serializer.fromJson<String>(json['storageScope']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      status: serializer.fromJson<String>(json['status']),
      currentStepIndex: serializer.fromJson<int>(json['currentStepIndex']),
      totalStepCount: serializer.fromJson<int>(json['totalStepCount']),
      baseRoutineVersion: serializer.fromJson<int?>(json['baseRoutineVersion']),
      stepStatesJson: serializer.fromJson<String>(json['stepStatesJson']),
      routineSnapshotJson: serializer.fromJson<String>(
        json['routineSnapshotJson'],
      ),
      syncMetadataJson: serializer.fromJson<String?>(json['syncMetadataJson']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      discardedAt: serializer.fromJson<DateTime?>(json['discardedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'routineId': serializer.toJson<int>(routineId),
      'routineTitleSnapshot': serializer.toJson<String>(routineTitleSnapshot),
      'workspaceId': serializer.toJson<String?>(workspaceId),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'storageScope': serializer.toJson<String>(storageScope),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'status': serializer.toJson<String>(status),
      'currentStepIndex': serializer.toJson<int>(currentStepIndex),
      'totalStepCount': serializer.toJson<int>(totalStepCount),
      'baseRoutineVersion': serializer.toJson<int?>(baseRoutineVersion),
      'stepStatesJson': serializer.toJson<String>(stepStatesJson),
      'routineSnapshotJson': serializer.toJson<String>(routineSnapshotJson),
      'syncMetadataJson': serializer.toJson<String?>(syncMetadataJson),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'discardedAt': serializer.toJson<DateTime?>(discardedAt),
    };
  }

  RoutineSessionRow copyWith({
    String? sessionId,
    int? routineId,
    String? routineTitleSnapshot,
    Value<String?> workspaceId = const Value.absent(),
    Value<String?> ownerUserId = const Value.absent(),
    String? storageScope,
    DateTime? startedAt,
    DateTime? updatedAt,
    String? status,
    int? currentStepIndex,
    int? totalStepCount,
    Value<int?> baseRoutineVersion = const Value.absent(),
    String? stepStatesJson,
    String? routineSnapshotJson,
    Value<String?> syncMetadataJson = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> discardedAt = const Value.absent(),
  }) => RoutineSessionRow(
    sessionId: sessionId ?? this.sessionId,
    routineId: routineId ?? this.routineId,
    routineTitleSnapshot: routineTitleSnapshot ?? this.routineTitleSnapshot,
    workspaceId: workspaceId.present ? workspaceId.value : this.workspaceId,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    storageScope: storageScope ?? this.storageScope,
    startedAt: startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    totalStepCount: totalStepCount ?? this.totalStepCount,
    baseRoutineVersion: baseRoutineVersion.present
        ? baseRoutineVersion.value
        : this.baseRoutineVersion,
    stepStatesJson: stepStatesJson ?? this.stepStatesJson,
    routineSnapshotJson: routineSnapshotJson ?? this.routineSnapshotJson,
    syncMetadataJson: syncMetadataJson.present
        ? syncMetadataJson.value
        : this.syncMetadataJson,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    discardedAt: discardedAt.present ? discardedAt.value : this.discardedAt,
  );
  RoutineSessionRow copyWithCompanion(RoutineSessionsCompanion data) {
    return RoutineSessionRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      routineTitleSnapshot: data.routineTitleSnapshot.present
          ? data.routineTitleSnapshot.value
          : this.routineTitleSnapshot,
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      storageScope: data.storageScope.present
          ? data.storageScope.value
          : this.storageScope,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      currentStepIndex: data.currentStepIndex.present
          ? data.currentStepIndex.value
          : this.currentStepIndex,
      totalStepCount: data.totalStepCount.present
          ? data.totalStepCount.value
          : this.totalStepCount,
      baseRoutineVersion: data.baseRoutineVersion.present
          ? data.baseRoutineVersion.value
          : this.baseRoutineVersion,
      stepStatesJson: data.stepStatesJson.present
          ? data.stepStatesJson.value
          : this.stepStatesJson,
      routineSnapshotJson: data.routineSnapshotJson.present
          ? data.routineSnapshotJson.value
          : this.routineSnapshotJson,
      syncMetadataJson: data.syncMetadataJson.present
          ? data.syncMetadataJson.value
          : this.syncMetadataJson,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      discardedAt: data.discardedAt.present
          ? data.discardedAt.value
          : this.discardedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineSessionRow(')
          ..write('sessionId: $sessionId, ')
          ..write('routineId: $routineId, ')
          ..write('routineTitleSnapshot: $routineTitleSnapshot, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('storageScope: $storageScope, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('currentStepIndex: $currentStepIndex, ')
          ..write('totalStepCount: $totalStepCount, ')
          ..write('baseRoutineVersion: $baseRoutineVersion, ')
          ..write('stepStatesJson: $stepStatesJson, ')
          ..write('routineSnapshotJson: $routineSnapshotJson, ')
          ..write('syncMetadataJson: $syncMetadataJson, ')
          ..write('completedAt: $completedAt, ')
          ..write('discardedAt: $discardedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    routineId,
    routineTitleSnapshot,
    workspaceId,
    ownerUserId,
    storageScope,
    startedAt,
    updatedAt,
    status,
    currentStepIndex,
    totalStepCount,
    baseRoutineVersion,
    stepStatesJson,
    routineSnapshotJson,
    syncMetadataJson,
    completedAt,
    discardedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineSessionRow &&
          other.sessionId == this.sessionId &&
          other.routineId == this.routineId &&
          other.routineTitleSnapshot == this.routineTitleSnapshot &&
          other.workspaceId == this.workspaceId &&
          other.ownerUserId == this.ownerUserId &&
          other.storageScope == this.storageScope &&
          other.startedAt == this.startedAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.currentStepIndex == this.currentStepIndex &&
          other.totalStepCount == this.totalStepCount &&
          other.baseRoutineVersion == this.baseRoutineVersion &&
          other.stepStatesJson == this.stepStatesJson &&
          other.routineSnapshotJson == this.routineSnapshotJson &&
          other.syncMetadataJson == this.syncMetadataJson &&
          other.completedAt == this.completedAt &&
          other.discardedAt == this.discardedAt);
}

class RoutineSessionsCompanion extends UpdateCompanion<RoutineSessionRow> {
  final Value<String> sessionId;
  final Value<int> routineId;
  final Value<String> routineTitleSnapshot;
  final Value<String?> workspaceId;
  final Value<String?> ownerUserId;
  final Value<String> storageScope;
  final Value<DateTime> startedAt;
  final Value<DateTime> updatedAt;
  final Value<String> status;
  final Value<int> currentStepIndex;
  final Value<int> totalStepCount;
  final Value<int?> baseRoutineVersion;
  final Value<String> stepStatesJson;
  final Value<String> routineSnapshotJson;
  final Value<String?> syncMetadataJson;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> discardedAt;
  final Value<int> rowid;
  const RoutineSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.routineId = const Value.absent(),
    this.routineTitleSnapshot = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.storageScope = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.currentStepIndex = const Value.absent(),
    this.totalStepCount = const Value.absent(),
    this.baseRoutineVersion = const Value.absent(),
    this.stepStatesJson = const Value.absent(),
    this.routineSnapshotJson = const Value.absent(),
    this.syncMetadataJson = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.discardedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineSessionsCompanion.insert({
    required String sessionId,
    required int routineId,
    required String routineTitleSnapshot,
    this.workspaceId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    required String storageScope,
    required DateTime startedAt,
    required DateTime updatedAt,
    required String status,
    required int currentStepIndex,
    required int totalStepCount,
    this.baseRoutineVersion = const Value.absent(),
    required String stepStatesJson,
    required String routineSnapshotJson,
    this.syncMetadataJson = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.discardedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       routineId = Value(routineId),
       routineTitleSnapshot = Value(routineTitleSnapshot),
       storageScope = Value(storageScope),
       startedAt = Value(startedAt),
       updatedAt = Value(updatedAt),
       status = Value(status),
       currentStepIndex = Value(currentStepIndex),
       totalStepCount = Value(totalStepCount),
       stepStatesJson = Value(stepStatesJson),
       routineSnapshotJson = Value(routineSnapshotJson);
  static Insertable<RoutineSessionRow> custom({
    Expression<String>? sessionId,
    Expression<int>? routineId,
    Expression<String>? routineTitleSnapshot,
    Expression<String>? workspaceId,
    Expression<String>? ownerUserId,
    Expression<String>? storageScope,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? status,
    Expression<int>? currentStepIndex,
    Expression<int>? totalStepCount,
    Expression<int>? baseRoutineVersion,
    Expression<String>? stepStatesJson,
    Expression<String>? routineSnapshotJson,
    Expression<String>? syncMetadataJson,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? discardedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (routineId != null) 'routine_id': routineId,
      if (routineTitleSnapshot != null)
        'routine_title_snapshot': routineTitleSnapshot,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (storageScope != null) 'storage_scope': storageScope,
      if (startedAt != null) 'started_at': startedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (currentStepIndex != null) 'current_step_index': currentStepIndex,
      if (totalStepCount != null) 'total_step_count': totalStepCount,
      if (baseRoutineVersion != null)
        'base_routine_version': baseRoutineVersion,
      if (stepStatesJson != null) 'step_states_json': stepStatesJson,
      if (routineSnapshotJson != null)
        'routine_snapshot_json': routineSnapshotJson,
      if (syncMetadataJson != null) 'sync_metadata_json': syncMetadataJson,
      if (completedAt != null) 'completed_at': completedAt,
      if (discardedAt != null) 'discarded_at': discardedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineSessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? routineId,
    Value<String>? routineTitleSnapshot,
    Value<String?>? workspaceId,
    Value<String?>? ownerUserId,
    Value<String>? storageScope,
    Value<DateTime>? startedAt,
    Value<DateTime>? updatedAt,
    Value<String>? status,
    Value<int>? currentStepIndex,
    Value<int>? totalStepCount,
    Value<int?>? baseRoutineVersion,
    Value<String>? stepStatesJson,
    Value<String>? routineSnapshotJson,
    Value<String?>? syncMetadataJson,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? discardedAt,
    Value<int>? rowid,
  }) {
    return RoutineSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      routineId: routineId ?? this.routineId,
      routineTitleSnapshot: routineTitleSnapshot ?? this.routineTitleSnapshot,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      storageScope: storageScope ?? this.storageScope,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      totalStepCount: totalStepCount ?? this.totalStepCount,
      baseRoutineVersion: baseRoutineVersion ?? this.baseRoutineVersion,
      stepStatesJson: stepStatesJson ?? this.stepStatesJson,
      routineSnapshotJson: routineSnapshotJson ?? this.routineSnapshotJson,
      syncMetadataJson: syncMetadataJson ?? this.syncMetadataJson,
      completedAt: completedAt ?? this.completedAt,
      discardedAt: discardedAt ?? this.discardedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (routineTitleSnapshot.present) {
      map['routine_title_snapshot'] = Variable<String>(
        routineTitleSnapshot.value,
      );
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (storageScope.present) {
      map['storage_scope'] = Variable<String>(storageScope.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currentStepIndex.present) {
      map['current_step_index'] = Variable<int>(currentStepIndex.value);
    }
    if (totalStepCount.present) {
      map['total_step_count'] = Variable<int>(totalStepCount.value);
    }
    if (baseRoutineVersion.present) {
      map['base_routine_version'] = Variable<int>(baseRoutineVersion.value);
    }
    if (stepStatesJson.present) {
      map['step_states_json'] = Variable<String>(stepStatesJson.value);
    }
    if (routineSnapshotJson.present) {
      map['routine_snapshot_json'] = Variable<String>(
        routineSnapshotJson.value,
      );
    }
    if (syncMetadataJson.present) {
      map['sync_metadata_json'] = Variable<String>(syncMetadataJson.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (discardedAt.present) {
      map['discarded_at'] = Variable<DateTime>(discardedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('routineId: $routineId, ')
          ..write('routineTitleSnapshot: $routineTitleSnapshot, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('storageScope: $storageScope, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('currentStepIndex: $currentStepIndex, ')
          ..write('totalStepCount: $totalStepCount, ')
          ..write('baseRoutineVersion: $baseRoutineVersion, ')
          ..write('stepStatesJson: $stepStatesJson, ')
          ..write('routineSnapshotJson: $routineSnapshotJson, ')
          ..write('syncMetadataJson: $syncMetadataJson, ')
          ..write('completedAt: $completedAt, ')
          ..write('discardedAt: $discardedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineComposerDraftsTable extends RoutineComposerDrafts
    with TableInfo<$RoutineComposerDraftsTable, RoutineComposerDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineComposerDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRoutineIdMeta = const VerificationMeta(
    'sourceRoutineId',
  );
  @override
  late final GeneratedColumn<int> sourceRoutineId = GeneratedColumn<int>(
    'source_routine_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<int> colorHex = GeneratedColumn<int>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    draftId,
    mode,
    sourceRoutineId,
    title,
    iconKey,
    colorHex,
    stepsJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_composer_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineComposerDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('source_routine_id')) {
      context.handle(
        _sourceRoutineIdMeta,
        sourceRoutineId.isAcceptableOrUnknown(
          data['source_routine_id']!,
          _sourceRoutineIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {draftId};
  @override
  RoutineComposerDraftRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineComposerDraftRow(
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      sourceRoutineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_routine_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_hex'],
      ),
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RoutineComposerDraftsTable createAlias(String alias) {
    return $RoutineComposerDraftsTable(attachedDatabase, alias);
  }
}

class RoutineComposerDraftRow extends DataClass
    implements Insertable<RoutineComposerDraftRow> {
  final String draftId;
  final String mode;
  final int? sourceRoutineId;
  final String? title;
  final String? iconKey;
  final int? colorHex;
  final String stepsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RoutineComposerDraftRow({
    required this.draftId,
    required this.mode,
    this.sourceRoutineId,
    this.title,
    this.iconKey,
    this.colorHex,
    required this.stepsJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['draft_id'] = Variable<String>(draftId);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || sourceRoutineId != null) {
      map['source_routine_id'] = Variable<int>(sourceRoutineId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<int>(colorHex);
    }
    map['steps_json'] = Variable<String>(stepsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RoutineComposerDraftsCompanion toCompanion(bool nullToAbsent) {
    return RoutineComposerDraftsCompanion(
      draftId: Value(draftId),
      mode: Value(mode),
      sourceRoutineId: sourceRoutineId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRoutineId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      stepsJson: Value(stepsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RoutineComposerDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineComposerDraftRow(
      draftId: serializer.fromJson<String>(json['draftId']),
      mode: serializer.fromJson<String>(json['mode']),
      sourceRoutineId: serializer.fromJson<int?>(json['sourceRoutineId']),
      title: serializer.fromJson<String?>(json['title']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      colorHex: serializer.fromJson<int?>(json['colorHex']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'draftId': serializer.toJson<String>(draftId),
      'mode': serializer.toJson<String>(mode),
      'sourceRoutineId': serializer.toJson<int?>(sourceRoutineId),
      'title': serializer.toJson<String?>(title),
      'iconKey': serializer.toJson<String?>(iconKey),
      'colorHex': serializer.toJson<int?>(colorHex),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RoutineComposerDraftRow copyWith({
    String? draftId,
    String? mode,
    Value<int?> sourceRoutineId = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> iconKey = const Value.absent(),
    Value<int?> colorHex = const Value.absent(),
    String? stepsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RoutineComposerDraftRow(
    draftId: draftId ?? this.draftId,
    mode: mode ?? this.mode,
    sourceRoutineId: sourceRoutineId.present
        ? sourceRoutineId.value
        : this.sourceRoutineId,
    title: title.present ? title.value : this.title,
    iconKey: iconKey.present ? iconKey.value : this.iconKey,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    stepsJson: stepsJson ?? this.stepsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RoutineComposerDraftRow copyWithCompanion(
    RoutineComposerDraftsCompanion data,
  ) {
    return RoutineComposerDraftRow(
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      mode: data.mode.present ? data.mode.value : this.mode,
      sourceRoutineId: data.sourceRoutineId.present
          ? data.sourceRoutineId.value
          : this.sourceRoutineId,
      title: data.title.present ? data.title.value : this.title,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineComposerDraftRow(')
          ..write('draftId: $draftId, ')
          ..write('mode: $mode, ')
          ..write('sourceRoutineId: $sourceRoutineId, ')
          ..write('title: $title, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorHex: $colorHex, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    draftId,
    mode,
    sourceRoutineId,
    title,
    iconKey,
    colorHex,
    stepsJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineComposerDraftRow &&
          other.draftId == this.draftId &&
          other.mode == this.mode &&
          other.sourceRoutineId == this.sourceRoutineId &&
          other.title == this.title &&
          other.iconKey == this.iconKey &&
          other.colorHex == this.colorHex &&
          other.stepsJson == this.stepsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RoutineComposerDraftsCompanion
    extends UpdateCompanion<RoutineComposerDraftRow> {
  final Value<String> draftId;
  final Value<String> mode;
  final Value<int?> sourceRoutineId;
  final Value<String?> title;
  final Value<String?> iconKey;
  final Value<int?> colorHex;
  final Value<String> stepsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RoutineComposerDraftsCompanion({
    this.draftId = const Value.absent(),
    this.mode = const Value.absent(),
    this.sourceRoutineId = const Value.absent(),
    this.title = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineComposerDraftsCompanion.insert({
    required String draftId,
    required String mode,
    this.sourceRoutineId = const Value.absent(),
    this.title = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorHex = const Value.absent(),
    required String stepsJson,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : draftId = Value(draftId),
       mode = Value(mode),
       stepsJson = Value(stepsJson);
  static Insertable<RoutineComposerDraftRow> custom({
    Expression<String>? draftId,
    Expression<String>? mode,
    Expression<int>? sourceRoutineId,
    Expression<String>? title,
    Expression<String>? iconKey,
    Expression<int>? colorHex,
    Expression<String>? stepsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (draftId != null) 'draft_id': draftId,
      if (mode != null) 'mode': mode,
      if (sourceRoutineId != null) 'source_routine_id': sourceRoutineId,
      if (title != null) 'title': title,
      if (iconKey != null) 'icon_key': iconKey,
      if (colorHex != null) 'color_hex': colorHex,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineComposerDraftsCompanion copyWith({
    Value<String>? draftId,
    Value<String>? mode,
    Value<int?>? sourceRoutineId,
    Value<String?>? title,
    Value<String?>? iconKey,
    Value<int?>? colorHex,
    Value<String>? stepsJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RoutineComposerDraftsCompanion(
      draftId: draftId ?? this.draftId,
      mode: mode ?? this.mode,
      sourceRoutineId: sourceRoutineId ?? this.sourceRoutineId,
      title: title ?? this.title,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      stepsJson: stepsJson ?? this.stepsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (sourceRoutineId.present) {
      map['source_routine_id'] = Variable<int>(sourceRoutineId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<int>(colorHex.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineComposerDraftsCompanion(')
          ..write('draftId: $draftId, ')
          ..write('mode: $mode, ')
          ..write('sourceRoutineId: $sourceRoutineId, ')
          ..write('title: $title, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorHex: $colorHex, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorSummaryMeta = const VerificationMeta(
    'lastErrorSummary',
  );
  @override
  late final GeneratedColumn<String> lastErrorSummary = GeneratedColumn<String>(
    'last_error_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operation,
    payloadJson,
    attemptCount,
    lastErrorSummary,
    nextAttemptAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error_summary')) {
      context.handle(
        _lastErrorSummaryMeta,
        lastErrorSummary.isAcceptableOrUnknown(
          data['last_error_summary']!,
          _lastErrorSummaryMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastErrorSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_summary'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxRow extends DataClass implements Insertable<SyncOutboxRow> {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String? payloadJson;
  final int attemptCount;
  final String? lastErrorSummary;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SyncOutboxRow({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payloadJson,
    required this.attemptCount,
    this.lastErrorSummary,
    this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastErrorSummary != null) {
      map['last_error_summary'] = Variable<String>(lastErrorSummary);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      attemptCount: Value(attemptCount),
      lastErrorSummary: lastErrorSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorSummary),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxRow(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastErrorSummary: serializer.fromJson<String?>(json['lastErrorSummary']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastErrorSummary': serializer.toJson<String?>(lastErrorSummary),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncOutboxRow copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    Value<String?> payloadJson = const Value.absent(),
    int? attemptCount,
    Value<String?> lastErrorSummary = const Value.absent(),
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SyncOutboxRow(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    attemptCount: attemptCount ?? this.attemptCount,
    lastErrorSummary: lastErrorSummary.present
        ? lastErrorSummary.value
        : this.lastErrorSummary,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncOutboxRow copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxRow(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastErrorSummary: data.lastErrorSummary.present
          ? data.lastErrorSummary.value
          : this.lastErrorSummary,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRow(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastErrorSummary: $lastErrorSummary, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    operation,
    payloadJson,
    attemptCount,
    lastErrorSummary,
    nextAttemptAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxRow &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.attemptCount == this.attemptCount &&
          other.lastErrorSummary == this.lastErrorSummary &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxRow> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String?> payloadJson;
  final Value<int> attemptCount;
  final Value<String?> lastErrorSummary;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastErrorSummary = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    this.payloadJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastErrorSummary = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation);
  static Insertable<SyncOutboxRow> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<int>? attemptCount,
    Expression<String>? lastErrorSummary,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastErrorSummary != null) 'last_error_summary': lastErrorSummary,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String?>? payloadJson,
    Value<int>? attemptCount,
    Value<String?>? lastErrorSummary,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      attemptCount: attemptCount ?? this.attemptCount,
      lastErrorSummary: lastErrorSummary ?? this.lastErrorSummary,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastErrorSummary.present) {
      map['last_error_summary'] = Variable<String>(lastErrorSummary.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastErrorSummary: $lastErrorSummary, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CloudAccountStatesTable extends CloudAccountStates
    with TableInfo<$CloudAccountStatesTable, CloudAccountStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CloudAccountStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _entitlementTierMeta = const VerificationMeta(
    'entitlementTier',
  );
  @override
  late final GeneratedColumn<String> entitlementTier = GeneratedColumn<String>(
    'entitlement_tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('personalFree'),
  );
  static const VerificationMeta _pendingTierMeta = const VerificationMeta(
    'pendingTier',
  );
  @override
  late final GeneratedColumn<String> pendingTier = GeneratedColumn<String>(
    'pending_tier',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bootstrapStatusMeta = const VerificationMeta(
    'bootstrapStatus',
  );
  @override
  late final GeneratedColumn<String> bootstrapStatus = GeneratedColumn<String>(
    'bootstrap_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('idle'),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authProviderMeta = const VerificationMeta(
    'authProvider',
  );
  @override
  late final GeneratedColumn<String> authProvider = GeneratedColumn<String>(
    'auth_provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastBootstrapAtMeta = const VerificationMeta(
    'lastBootstrapAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastBootstrapAt =
      GeneratedColumn<DateTime>(
        'last_bootstrap_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncErrorMeta = const VerificationMeta(
    'lastSyncError',
  );
  @override
  late final GeneratedColumn<String> lastSyncError = GeneratedColumn<String>(
    'last_sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    singletonId,
    entitlementTier,
    pendingTier,
    bootstrapStatus,
    userId,
    email,
    authProvider,
    lastBootstrapAt,
    lastSyncAt,
    lastSyncError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cloud_account_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<CloudAccountStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('entitlement_tier')) {
      context.handle(
        _entitlementTierMeta,
        entitlementTier.isAcceptableOrUnknown(
          data['entitlement_tier']!,
          _entitlementTierMeta,
        ),
      );
    }
    if (data.containsKey('pending_tier')) {
      context.handle(
        _pendingTierMeta,
        pendingTier.isAcceptableOrUnknown(
          data['pending_tier']!,
          _pendingTierMeta,
        ),
      );
    }
    if (data.containsKey('bootstrap_status')) {
      context.handle(
        _bootstrapStatusMeta,
        bootstrapStatus.isAcceptableOrUnknown(
          data['bootstrap_status']!,
          _bootstrapStatusMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('auth_provider')) {
      context.handle(
        _authProviderMeta,
        authProvider.isAcceptableOrUnknown(
          data['auth_provider']!,
          _authProviderMeta,
        ),
      );
    }
    if (data.containsKey('last_bootstrap_at')) {
      context.handle(
        _lastBootstrapAtMeta,
        lastBootstrapAt.isAcceptableOrUnknown(
          data['last_bootstrap_at']!,
          _lastBootstrapAtMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_error')) {
      context.handle(
        _lastSyncErrorMeta,
        lastSyncError.isAcceptableOrUnknown(
          data['last_sync_error']!,
          _lastSyncErrorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  CloudAccountStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CloudAccountStateRow(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      entitlementTier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entitlement_tier'],
      )!,
      pendingTier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_tier'],
      ),
      bootstrapStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bootstrap_status'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      authProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_provider'],
      ),
      lastBootstrapAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_bootstrap_at'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
      lastSyncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_sync_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CloudAccountStatesTable createAlias(String alias) {
    return $CloudAccountStatesTable(attachedDatabase, alias);
  }
}

class CloudAccountStateRow extends DataClass
    implements Insertable<CloudAccountStateRow> {
  final int singletonId;
  final String entitlementTier;
  final String? pendingTier;
  final String bootstrapStatus;
  final String? userId;
  final String? email;
  final String? authProvider;
  final DateTime? lastBootstrapAt;
  final DateTime? lastSyncAt;
  final String? lastSyncError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CloudAccountStateRow({
    required this.singletonId,
    required this.entitlementTier,
    this.pendingTier,
    required this.bootstrapStatus,
    this.userId,
    this.email,
    this.authProvider,
    this.lastBootstrapAt,
    this.lastSyncAt,
    this.lastSyncError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    map['entitlement_tier'] = Variable<String>(entitlementTier);
    if (!nullToAbsent || pendingTier != null) {
      map['pending_tier'] = Variable<String>(pendingTier);
    }
    map['bootstrap_status'] = Variable<String>(bootstrapStatus);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || authProvider != null) {
      map['auth_provider'] = Variable<String>(authProvider);
    }
    if (!nullToAbsent || lastBootstrapAt != null) {
      map['last_bootstrap_at'] = Variable<DateTime>(lastBootstrapAt);
    }
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    if (!nullToAbsent || lastSyncError != null) {
      map['last_sync_error'] = Variable<String>(lastSyncError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CloudAccountStatesCompanion toCompanion(bool nullToAbsent) {
    return CloudAccountStatesCompanion(
      singletonId: Value(singletonId),
      entitlementTier: Value(entitlementTier),
      pendingTier: pendingTier == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingTier),
      bootstrapStatus: Value(bootstrapStatus),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      authProvider: authProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(authProvider),
      lastBootstrapAt: lastBootstrapAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBootstrapAt),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastSyncError: lastSyncError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CloudAccountStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CloudAccountStateRow(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      entitlementTier: serializer.fromJson<String>(json['entitlementTier']),
      pendingTier: serializer.fromJson<String?>(json['pendingTier']),
      bootstrapStatus: serializer.fromJson<String>(json['bootstrapStatus']),
      userId: serializer.fromJson<String?>(json['userId']),
      email: serializer.fromJson<String?>(json['email']),
      authProvider: serializer.fromJson<String?>(json['authProvider']),
      lastBootstrapAt: serializer.fromJson<DateTime?>(json['lastBootstrapAt']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      lastSyncError: serializer.fromJson<String?>(json['lastSyncError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'entitlementTier': serializer.toJson<String>(entitlementTier),
      'pendingTier': serializer.toJson<String?>(pendingTier),
      'bootstrapStatus': serializer.toJson<String>(bootstrapStatus),
      'userId': serializer.toJson<String?>(userId),
      'email': serializer.toJson<String?>(email),
      'authProvider': serializer.toJson<String?>(authProvider),
      'lastBootstrapAt': serializer.toJson<DateTime?>(lastBootstrapAt),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'lastSyncError': serializer.toJson<String?>(lastSyncError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CloudAccountStateRow copyWith({
    int? singletonId,
    String? entitlementTier,
    Value<String?> pendingTier = const Value.absent(),
    String? bootstrapStatus,
    Value<String?> userId = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> authProvider = const Value.absent(),
    Value<DateTime?> lastBootstrapAt = const Value.absent(),
    Value<DateTime?> lastSyncAt = const Value.absent(),
    Value<String?> lastSyncError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CloudAccountStateRow(
    singletonId: singletonId ?? this.singletonId,
    entitlementTier: entitlementTier ?? this.entitlementTier,
    pendingTier: pendingTier.present ? pendingTier.value : this.pendingTier,
    bootstrapStatus: bootstrapStatus ?? this.bootstrapStatus,
    userId: userId.present ? userId.value : this.userId,
    email: email.present ? email.value : this.email,
    authProvider: authProvider.present ? authProvider.value : this.authProvider,
    lastBootstrapAt: lastBootstrapAt.present
        ? lastBootstrapAt.value
        : this.lastBootstrapAt,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastSyncError: lastSyncError.present
        ? lastSyncError.value
        : this.lastSyncError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CloudAccountStateRow copyWithCompanion(CloudAccountStatesCompanion data) {
    return CloudAccountStateRow(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      entitlementTier: data.entitlementTier.present
          ? data.entitlementTier.value
          : this.entitlementTier,
      pendingTier: data.pendingTier.present
          ? data.pendingTier.value
          : this.pendingTier,
      bootstrapStatus: data.bootstrapStatus.present
          ? data.bootstrapStatus.value
          : this.bootstrapStatus,
      userId: data.userId.present ? data.userId.value : this.userId,
      email: data.email.present ? data.email.value : this.email,
      authProvider: data.authProvider.present
          ? data.authProvider.value
          : this.authProvider,
      lastBootstrapAt: data.lastBootstrapAt.present
          ? data.lastBootstrapAt.value
          : this.lastBootstrapAt,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastSyncError: data.lastSyncError.present
          ? data.lastSyncError.value
          : this.lastSyncError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CloudAccountStateRow(')
          ..write('singletonId: $singletonId, ')
          ..write('entitlementTier: $entitlementTier, ')
          ..write('pendingTier: $pendingTier, ')
          ..write('bootstrapStatus: $bootstrapStatus, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('authProvider: $authProvider, ')
          ..write('lastBootstrapAt: $lastBootstrapAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastSyncError: $lastSyncError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    singletonId,
    entitlementTier,
    pendingTier,
    bootstrapStatus,
    userId,
    email,
    authProvider,
    lastBootstrapAt,
    lastSyncAt,
    lastSyncError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CloudAccountStateRow &&
          other.singletonId == this.singletonId &&
          other.entitlementTier == this.entitlementTier &&
          other.pendingTier == this.pendingTier &&
          other.bootstrapStatus == this.bootstrapStatus &&
          other.userId == this.userId &&
          other.email == this.email &&
          other.authProvider == this.authProvider &&
          other.lastBootstrapAt == this.lastBootstrapAt &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastSyncError == this.lastSyncError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CloudAccountStatesCompanion
    extends UpdateCompanion<CloudAccountStateRow> {
  final Value<int> singletonId;
  final Value<String> entitlementTier;
  final Value<String?> pendingTier;
  final Value<String> bootstrapStatus;
  final Value<String?> userId;
  final Value<String?> email;
  final Value<String?> authProvider;
  final Value<DateTime?> lastBootstrapAt;
  final Value<DateTime?> lastSyncAt;
  final Value<String?> lastSyncError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const CloudAccountStatesCompanion({
    this.singletonId = const Value.absent(),
    this.entitlementTier = const Value.absent(),
    this.pendingTier = const Value.absent(),
    this.bootstrapStatus = const Value.absent(),
    this.userId = const Value.absent(),
    this.email = const Value.absent(),
    this.authProvider = const Value.absent(),
    this.lastBootstrapAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CloudAccountStatesCompanion.insert({
    this.singletonId = const Value.absent(),
    this.entitlementTier = const Value.absent(),
    this.pendingTier = const Value.absent(),
    this.bootstrapStatus = const Value.absent(),
    this.userId = const Value.absent(),
    this.email = const Value.absent(),
    this.authProvider = const Value.absent(),
    this.lastBootstrapAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<CloudAccountStateRow> custom({
    Expression<int>? singletonId,
    Expression<String>? entitlementTier,
    Expression<String>? pendingTier,
    Expression<String>? bootstrapStatus,
    Expression<String>? userId,
    Expression<String>? email,
    Expression<String>? authProvider,
    Expression<DateTime>? lastBootstrapAt,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastSyncError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (entitlementTier != null) 'entitlement_tier': entitlementTier,
      if (pendingTier != null) 'pending_tier': pendingTier,
      if (bootstrapStatus != null) 'bootstrap_status': bootstrapStatus,
      if (userId != null) 'user_id': userId,
      if (email != null) 'email': email,
      if (authProvider != null) 'auth_provider': authProvider,
      if (lastBootstrapAt != null) 'last_bootstrap_at': lastBootstrapAt,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastSyncError != null) 'last_sync_error': lastSyncError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CloudAccountStatesCompanion copyWith({
    Value<int>? singletonId,
    Value<String>? entitlementTier,
    Value<String?>? pendingTier,
    Value<String>? bootstrapStatus,
    Value<String?>? userId,
    Value<String?>? email,
    Value<String?>? authProvider,
    Value<DateTime?>? lastBootstrapAt,
    Value<DateTime?>? lastSyncAt,
    Value<String?>? lastSyncError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return CloudAccountStatesCompanion(
      singletonId: singletonId ?? this.singletonId,
      entitlementTier: entitlementTier ?? this.entitlementTier,
      pendingTier: pendingTier ?? this.pendingTier,
      bootstrapStatus: bootstrapStatus ?? this.bootstrapStatus,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      authProvider: authProvider ?? this.authProvider,
      lastBootstrapAt: lastBootstrapAt ?? this.lastBootstrapAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (entitlementTier.present) {
      map['entitlement_tier'] = Variable<String>(entitlementTier.value);
    }
    if (pendingTier.present) {
      map['pending_tier'] = Variable<String>(pendingTier.value);
    }
    if (bootstrapStatus.present) {
      map['bootstrap_status'] = Variable<String>(bootstrapStatus.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (authProvider.present) {
      map['auth_provider'] = Variable<String>(authProvider.value);
    }
    if (lastBootstrapAt.present) {
      map['last_bootstrap_at'] = Variable<DateTime>(lastBootstrapAt.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastSyncError.present) {
      map['last_sync_error'] = Variable<String>(lastSyncError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CloudAccountStatesCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('entitlementTier: $entitlementTier, ')
          ..write('pendingTier: $pendingTier, ')
          ..write('bootstrapStatus: $bootstrapStatus, ')
          ..write('userId: $userId, ')
          ..write('email: $email, ')
          ..write('authProvider: $authProvider, ')
          ..write('lastBootstrapAt: $lastBootstrapAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastSyncError: $lastSyncError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDb extends GeneratedDatabase {
  _$LocalDb(QueryExecutor e) : super(e);
  $LocalDbManager get managers => $LocalDbManager(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  late final $RoutineRunsTable routineRuns = $RoutineRunsTable(this);
  late final $RoutineRemindersTable routineReminders = $RoutineRemindersTable(
    this,
  );
  late final $RoutineSessionsTable routineSessions = $RoutineSessionsTable(
    this,
  );
  late final $RoutineComposerDraftsTable routineComposerDrafts =
      $RoutineComposerDraftsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $CloudAccountStatesTable cloudAccountStates =
      $CloudAccountStatesTable(this);
  late final RoutineDao routineDao = RoutineDao(this as LocalDb);
  late final RoutineRunDao routineRunDao = RoutineRunDao(this as LocalDb);
  late final RoutineReminderDao routineReminderDao = RoutineReminderDao(
    this as LocalDb,
  );
  late final RoutineSessionDao routineSessionDao = RoutineSessionDao(
    this as LocalDb,
  );
  late final RoutineComposerDraftDao routineComposerDraftDao =
      RoutineComposerDraftDao(this as LocalDb);
  late final SyncOutboxDao syncOutboxDao = SyncOutboxDao(this as LocalDb);
  late final CloudAccountDao cloudAccountDao = CloudAccountDao(this as LocalDb);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    routines,
    routineRuns,
    routineReminders,
    routineSessions,
    routineComposerDrafts,
    syncOutbox,
    cloudAccountStates,
  ];
}

typedef $$RoutinesTableCreateCompanionBuilder =
    RoutinesCompanion Function({
      Value<int> id,
      required String title,
      required String stepsJson,
      required DateTime createdAt,
      Value<String?> emoji,
      Value<int?> colorHex,
      Value<bool> isPinned,
      Value<DateTime?> pinnedAt,
      Value<int?> reminderDay,
      Value<String?> reminderTime,
      Value<int> version,
      Value<DateTime> updatedAt,
      Value<String?> cloudId,
      Value<String?> ownerUserId,
      Value<String> syncStatus,
      Value<DateTime?> lastSyncedAt,
    });
typedef $$RoutinesTableUpdateCompanionBuilder =
    RoutinesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> stepsJson,
      Value<DateTime> createdAt,
      Value<String?> emoji,
      Value<int?> colorHex,
      Value<bool> isPinned,
      Value<DateTime?> pinnedAt,
      Value<int?> reminderDay,
      Value<String?> reminderTime,
      Value<int> version,
      Value<DateTime> updatedAt,
      Value<String?> cloudId,
      Value<String?> ownerUserId,
      Value<String> syncStatus,
      Value<DateTime?> lastSyncedAt,
    });

class $$RoutinesTableFilterComposer
    extends Composer<_$LocalDb, $RoutinesTable> {
  $$RoutinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderDay => $composableBuilder(
    column: $table.reminderDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutinesTableOrderingComposer
    extends Composer<_$LocalDb, $RoutinesTable> {
  $$RoutinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderDay => $composableBuilder(
    column: $table.reminderDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutinesTableAnnotationComposer
    extends Composer<_$LocalDb, $RoutinesTable> {
  $$RoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<DateTime> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);

  GeneratedColumn<int> get reminderDay => $composableBuilder(
    column: $table.reminderDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$RoutinesTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $RoutinesTable,
          Routine,
          $$RoutinesTableFilterComposer,
          $$RoutinesTableOrderingComposer,
          $$RoutinesTableAnnotationComposer,
          $$RoutinesTableCreateCompanionBuilder,
          $$RoutinesTableUpdateCompanionBuilder,
          (Routine, BaseReferences<_$LocalDb, $RoutinesTable, Routine>),
          Routine,
          PrefetchHooks Function()
        > {
  $$RoutinesTableTableManager(_$LocalDb db, $RoutinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> emoji = const Value.absent(),
                Value<int?> colorHex = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime?> pinnedAt = const Value.absent(),
                Value<int?> reminderDay = const Value.absent(),
                Value<String?> reminderTime = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
              }) => RoutinesCompanion(
                id: id,
                title: title,
                stepsJson: stepsJson,
                createdAt: createdAt,
                emoji: emoji,
                colorHex: colorHex,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                reminderDay: reminderDay,
                reminderTime: reminderTime,
                version: version,
                updatedAt: updatedAt,
                cloudId: cloudId,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String stepsJson,
                required DateTime createdAt,
                Value<String?> emoji = const Value.absent(),
                Value<int?> colorHex = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime?> pinnedAt = const Value.absent(),
                Value<int?> reminderDay = const Value.absent(),
                Value<String?> reminderTime = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
              }) => RoutinesCompanion.insert(
                id: id,
                title: title,
                stepsJson: stepsJson,
                createdAt: createdAt,
                emoji: emoji,
                colorHex: colorHex,
                isPinned: isPinned,
                pinnedAt: pinnedAt,
                reminderDay: reminderDay,
                reminderTime: reminderTime,
                version: version,
                updatedAt: updatedAt,
                cloudId: cloudId,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $RoutinesTable,
      Routine,
      $$RoutinesTableFilterComposer,
      $$RoutinesTableOrderingComposer,
      $$RoutinesTableAnnotationComposer,
      $$RoutinesTableCreateCompanionBuilder,
      $$RoutinesTableUpdateCompanionBuilder,
      (Routine, BaseReferences<_$LocalDb, $RoutinesTable, Routine>),
      Routine,
      PrefetchHooks Function()
    >;
typedef $$RoutineRunsTableCreateCompanionBuilder =
    RoutineRunsCompanion Function({
      required String id,
      required String routineId,
      required String routineTitle,
      required DateTime finishedAt,
      Value<String?> stepCompletionData,
      Value<String?> ownerUserId,
      Value<String> syncStatus,
      Value<DateTime?> lastSyncedAt,
      Value<String?> syncMetadataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$RoutineRunsTableUpdateCompanionBuilder =
    RoutineRunsCompanion Function({
      Value<String> id,
      Value<String> routineId,
      Value<String> routineTitle,
      Value<DateTime> finishedAt,
      Value<String?> stepCompletionData,
      Value<String?> ownerUserId,
      Value<String> syncStatus,
      Value<DateTime?> lastSyncedAt,
      Value<String?> syncMetadataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RoutineRunsTableFilterComposer
    extends Composer<_$LocalDb, $RoutineRunsTable> {
  $$RoutineRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineTitle => $composableBuilder(
    column: $table.routineTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepCompletionData => $composableBuilder(
    column: $table.stepCompletionData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncMetadataJson => $composableBuilder(
    column: $table.syncMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutineRunsTableOrderingComposer
    extends Composer<_$LocalDb, $RoutineRunsTable> {
  $$RoutineRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineTitle => $composableBuilder(
    column: $table.routineTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepCompletionData => $composableBuilder(
    column: $table.stepCompletionData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncMetadataJson => $composableBuilder(
    column: $table.syncMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutineRunsTableAnnotationComposer
    extends Composer<_$LocalDb, $RoutineRunsTable> {
  $$RoutineRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<String> get routineTitle => $composableBuilder(
    column: $table.routineTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stepCompletionData => $composableBuilder(
    column: $table.stepCompletionData,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncMetadataJson => $composableBuilder(
    column: $table.syncMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RoutineRunsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $RoutineRunsTable,
          RoutineRun,
          $$RoutineRunsTableFilterComposer,
          $$RoutineRunsTableOrderingComposer,
          $$RoutineRunsTableAnnotationComposer,
          $$RoutineRunsTableCreateCompanionBuilder,
          $$RoutineRunsTableUpdateCompanionBuilder,
          (
            RoutineRun,
            BaseReferences<_$LocalDb, $RoutineRunsTable, RoutineRun>,
          ),
          RoutineRun,
          PrefetchHooks Function()
        > {
  $$RoutineRunsTableTableManager(_$LocalDb db, $RoutineRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routineId = const Value.absent(),
                Value<String> routineTitle = const Value.absent(),
                Value<DateTime> finishedAt = const Value.absent(),
                Value<String?> stepCompletionData = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> syncMetadataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineRunsCompanion(
                id: id,
                routineId: routineId,
                routineTitle: routineTitle,
                finishedAt: finishedAt,
                stepCompletionData: stepCompletionData,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
                syncMetadataJson: syncMetadataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routineId,
                required String routineTitle,
                required DateTime finishedAt,
                Value<String?> stepCompletionData = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> syncMetadataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineRunsCompanion.insert(
                id: id,
                routineId: routineId,
                routineTitle: routineTitle,
                finishedAt: finishedAt,
                stepCompletionData: stepCompletionData,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
                syncMetadataJson: syncMetadataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutineRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $RoutineRunsTable,
      RoutineRun,
      $$RoutineRunsTableFilterComposer,
      $$RoutineRunsTableOrderingComposer,
      $$RoutineRunsTableAnnotationComposer,
      $$RoutineRunsTableCreateCompanionBuilder,
      $$RoutineRunsTableUpdateCompanionBuilder,
      (RoutineRun, BaseReferences<_$LocalDb, $RoutineRunsTable, RoutineRun>),
      RoutineRun,
      PrefetchHooks Function()
    >;
typedef $$RoutineRemindersTableCreateCompanionBuilder =
    RoutineRemindersCompanion Function({
      Value<int> id,
      required int routineId,
      required int dayOfWeek,
      required String time,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> cloudId,
      Value<String?> ownerUserId,
      Value<String> syncStatus,
      Value<DateTime?> lastSyncedAt,
    });
typedef $$RoutineRemindersTableUpdateCompanionBuilder =
    RoutineRemindersCompanion Function({
      Value<int> id,
      Value<int> routineId,
      Value<int> dayOfWeek,
      Value<String> time,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> cloudId,
      Value<String?> ownerUserId,
      Value<String> syncStatus,
      Value<DateTime?> lastSyncedAt,
    });

class $$RoutineRemindersTableFilterComposer
    extends Composer<_$LocalDb, $RoutineRemindersTable> {
  $$RoutineRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutineRemindersTableOrderingComposer
    extends Composer<_$LocalDb, $RoutineRemindersTable> {
  $$RoutineRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutineRemindersTableAnnotationComposer
    extends Composer<_$LocalDb, $RoutineRemindersTable> {
  $$RoutineRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$RoutineRemindersTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $RoutineRemindersTable,
          RoutineReminder,
          $$RoutineRemindersTableFilterComposer,
          $$RoutineRemindersTableOrderingComposer,
          $$RoutineRemindersTableAnnotationComposer,
          $$RoutineRemindersTableCreateCompanionBuilder,
          $$RoutineRemindersTableUpdateCompanionBuilder,
          (
            RoutineReminder,
            BaseReferences<_$LocalDb, $RoutineRemindersTable, RoutineReminder>,
          ),
          RoutineReminder,
          PrefetchHooks Function()
        > {
  $$RoutineRemindersTableTableManager(
    _$LocalDb db,
    $RoutineRemindersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> routineId = const Value.absent(),
                Value<int> dayOfWeek = const Value.absent(),
                Value<String> time = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
              }) => RoutineRemindersCompanion(
                id: id,
                routineId: routineId,
                dayOfWeek: dayOfWeek,
                time: time,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cloudId: cloudId,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int routineId,
                required int dayOfWeek,
                required String time,
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
              }) => RoutineRemindersCompanion.insert(
                id: id,
                routineId: routineId,
                dayOfWeek: dayOfWeek,
                time: time,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cloudId: cloudId,
                ownerUserId: ownerUserId,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutineRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $RoutineRemindersTable,
      RoutineReminder,
      $$RoutineRemindersTableFilterComposer,
      $$RoutineRemindersTableOrderingComposer,
      $$RoutineRemindersTableAnnotationComposer,
      $$RoutineRemindersTableCreateCompanionBuilder,
      $$RoutineRemindersTableUpdateCompanionBuilder,
      (
        RoutineReminder,
        BaseReferences<_$LocalDb, $RoutineRemindersTable, RoutineReminder>,
      ),
      RoutineReminder,
      PrefetchHooks Function()
    >;
typedef $$RoutineSessionsTableCreateCompanionBuilder =
    RoutineSessionsCompanion Function({
      required String sessionId,
      required int routineId,
      required String routineTitleSnapshot,
      Value<String?> workspaceId,
      Value<String?> ownerUserId,
      required String storageScope,
      required DateTime startedAt,
      required DateTime updatedAt,
      required String status,
      required int currentStepIndex,
      required int totalStepCount,
      Value<int?> baseRoutineVersion,
      required String stepStatesJson,
      required String routineSnapshotJson,
      Value<String?> syncMetadataJson,
      Value<DateTime?> completedAt,
      Value<DateTime?> discardedAt,
      Value<int> rowid,
    });
typedef $$RoutineSessionsTableUpdateCompanionBuilder =
    RoutineSessionsCompanion Function({
      Value<String> sessionId,
      Value<int> routineId,
      Value<String> routineTitleSnapshot,
      Value<String?> workspaceId,
      Value<String?> ownerUserId,
      Value<String> storageScope,
      Value<DateTime> startedAt,
      Value<DateTime> updatedAt,
      Value<String> status,
      Value<int> currentStepIndex,
      Value<int> totalStepCount,
      Value<int?> baseRoutineVersion,
      Value<String> stepStatesJson,
      Value<String> routineSnapshotJson,
      Value<String?> syncMetadataJson,
      Value<DateTime?> completedAt,
      Value<DateTime?> discardedAt,
      Value<int> rowid,
    });

class $$RoutineSessionsTableFilterComposer
    extends Composer<_$LocalDb, $RoutineSessionsTable> {
  $$RoutineSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineTitleSnapshot => $composableBuilder(
    column: $table.routineTitleSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStepIndex => $composableBuilder(
    column: $table.currentStepIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalStepCount => $composableBuilder(
    column: $table.totalStepCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRoutineVersion => $composableBuilder(
    column: $table.baseRoutineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepStatesJson => $composableBuilder(
    column: $table.stepStatesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineSnapshotJson => $composableBuilder(
    column: $table.routineSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncMetadataJson => $composableBuilder(
    column: $table.syncMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get discardedAt => $composableBuilder(
    column: $table.discardedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutineSessionsTableOrderingComposer
    extends Composer<_$LocalDb, $RoutineSessionsTable> {
  $$RoutineSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineTitleSnapshot => $composableBuilder(
    column: $table.routineTitleSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStepIndex => $composableBuilder(
    column: $table.currentStepIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalStepCount => $composableBuilder(
    column: $table.totalStepCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRoutineVersion => $composableBuilder(
    column: $table.baseRoutineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepStatesJson => $composableBuilder(
    column: $table.stepStatesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineSnapshotJson => $composableBuilder(
    column: $table.routineSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncMetadataJson => $composableBuilder(
    column: $table.syncMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get discardedAt => $composableBuilder(
    column: $table.discardedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutineSessionsTableAnnotationComposer
    extends Composer<_$LocalDb, $RoutineSessionsTable> {
  $$RoutineSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<String> get routineTitleSnapshot => $composableBuilder(
    column: $table.routineTitleSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storageScope => $composableBuilder(
    column: $table.storageScope,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get currentStepIndex => $composableBuilder(
    column: $table.currentStepIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalStepCount => $composableBuilder(
    column: $table.totalStepCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseRoutineVersion => $composableBuilder(
    column: $table.baseRoutineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stepStatesJson => $composableBuilder(
    column: $table.stepStatesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get routineSnapshotJson => $composableBuilder(
    column: $table.routineSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncMetadataJson => $composableBuilder(
    column: $table.syncMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get discardedAt => $composableBuilder(
    column: $table.discardedAt,
    builder: (column) => column,
  );
}

class $$RoutineSessionsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $RoutineSessionsTable,
          RoutineSessionRow,
          $$RoutineSessionsTableFilterComposer,
          $$RoutineSessionsTableOrderingComposer,
          $$RoutineSessionsTableAnnotationComposer,
          $$RoutineSessionsTableCreateCompanionBuilder,
          $$RoutineSessionsTableUpdateCompanionBuilder,
          (
            RoutineSessionRow,
            BaseReferences<_$LocalDb, $RoutineSessionsTable, RoutineSessionRow>,
          ),
          RoutineSessionRow,
          PrefetchHooks Function()
        > {
  $$RoutineSessionsTableTableManager(_$LocalDb db, $RoutineSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> routineId = const Value.absent(),
                Value<String> routineTitleSnapshot = const Value.absent(),
                Value<String?> workspaceId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> storageScope = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> currentStepIndex = const Value.absent(),
                Value<int> totalStepCount = const Value.absent(),
                Value<int?> baseRoutineVersion = const Value.absent(),
                Value<String> stepStatesJson = const Value.absent(),
                Value<String> routineSnapshotJson = const Value.absent(),
                Value<String?> syncMetadataJson = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> discardedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineSessionsCompanion(
                sessionId: sessionId,
                routineId: routineId,
                routineTitleSnapshot: routineTitleSnapshot,
                workspaceId: workspaceId,
                ownerUserId: ownerUserId,
                storageScope: storageScope,
                startedAt: startedAt,
                updatedAt: updatedAt,
                status: status,
                currentStepIndex: currentStepIndex,
                totalStepCount: totalStepCount,
                baseRoutineVersion: baseRoutineVersion,
                stepStatesJson: stepStatesJson,
                routineSnapshotJson: routineSnapshotJson,
                syncMetadataJson: syncMetadataJson,
                completedAt: completedAt,
                discardedAt: discardedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int routineId,
                required String routineTitleSnapshot,
                Value<String?> workspaceId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                required String storageScope,
                required DateTime startedAt,
                required DateTime updatedAt,
                required String status,
                required int currentStepIndex,
                required int totalStepCount,
                Value<int?> baseRoutineVersion = const Value.absent(),
                required String stepStatesJson,
                required String routineSnapshotJson,
                Value<String?> syncMetadataJson = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> discardedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineSessionsCompanion.insert(
                sessionId: sessionId,
                routineId: routineId,
                routineTitleSnapshot: routineTitleSnapshot,
                workspaceId: workspaceId,
                ownerUserId: ownerUserId,
                storageScope: storageScope,
                startedAt: startedAt,
                updatedAt: updatedAt,
                status: status,
                currentStepIndex: currentStepIndex,
                totalStepCount: totalStepCount,
                baseRoutineVersion: baseRoutineVersion,
                stepStatesJson: stepStatesJson,
                routineSnapshotJson: routineSnapshotJson,
                syncMetadataJson: syncMetadataJson,
                completedAt: completedAt,
                discardedAt: discardedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutineSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $RoutineSessionsTable,
      RoutineSessionRow,
      $$RoutineSessionsTableFilterComposer,
      $$RoutineSessionsTableOrderingComposer,
      $$RoutineSessionsTableAnnotationComposer,
      $$RoutineSessionsTableCreateCompanionBuilder,
      $$RoutineSessionsTableUpdateCompanionBuilder,
      (
        RoutineSessionRow,
        BaseReferences<_$LocalDb, $RoutineSessionsTable, RoutineSessionRow>,
      ),
      RoutineSessionRow,
      PrefetchHooks Function()
    >;
typedef $$RoutineComposerDraftsTableCreateCompanionBuilder =
    RoutineComposerDraftsCompanion Function({
      required String draftId,
      required String mode,
      Value<int?> sourceRoutineId,
      Value<String?> title,
      Value<String?> iconKey,
      Value<int?> colorHex,
      required String stepsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$RoutineComposerDraftsTableUpdateCompanionBuilder =
    RoutineComposerDraftsCompanion Function({
      Value<String> draftId,
      Value<String> mode,
      Value<int?> sourceRoutineId,
      Value<String?> title,
      Value<String?> iconKey,
      Value<int?> colorHex,
      Value<String> stepsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RoutineComposerDraftsTableFilterComposer
    extends Composer<_$LocalDb, $RoutineComposerDraftsTable> {
  $$RoutineComposerDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceRoutineId => $composableBuilder(
    column: $table.sourceRoutineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutineComposerDraftsTableOrderingComposer
    extends Composer<_$LocalDb, $RoutineComposerDraftsTable> {
  $$RoutineComposerDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceRoutineId => $composableBuilder(
    column: $table.sourceRoutineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutineComposerDraftsTableAnnotationComposer
    extends Composer<_$LocalDb, $RoutineComposerDraftsTable> {
  $$RoutineComposerDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get sourceRoutineId => $composableBuilder(
    column: $table.sourceRoutineId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<int> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RoutineComposerDraftsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $RoutineComposerDraftsTable,
          RoutineComposerDraftRow,
          $$RoutineComposerDraftsTableFilterComposer,
          $$RoutineComposerDraftsTableOrderingComposer,
          $$RoutineComposerDraftsTableAnnotationComposer,
          $$RoutineComposerDraftsTableCreateCompanionBuilder,
          $$RoutineComposerDraftsTableUpdateCompanionBuilder,
          (
            RoutineComposerDraftRow,
            BaseReferences<
              _$LocalDb,
              $RoutineComposerDraftsTable,
              RoutineComposerDraftRow
            >,
          ),
          RoutineComposerDraftRow,
          PrefetchHooks Function()
        > {
  $$RoutineComposerDraftsTableTableManager(
    _$LocalDb db,
    $RoutineComposerDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineComposerDraftsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RoutineComposerDraftsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RoutineComposerDraftsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> draftId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> sourceRoutineId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<int?> colorHex = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineComposerDraftsCompanion(
                draftId: draftId,
                mode: mode,
                sourceRoutineId: sourceRoutineId,
                title: title,
                iconKey: iconKey,
                colorHex: colorHex,
                stepsJson: stepsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String draftId,
                required String mode,
                Value<int?> sourceRoutineId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<int?> colorHex = const Value.absent(),
                required String stepsJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineComposerDraftsCompanion.insert(
                draftId: draftId,
                mode: mode,
                sourceRoutineId: sourceRoutineId,
                title: title,
                iconKey: iconKey,
                colorHex: colorHex,
                stepsJson: stepsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutineComposerDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $RoutineComposerDraftsTable,
      RoutineComposerDraftRow,
      $$RoutineComposerDraftsTableFilterComposer,
      $$RoutineComposerDraftsTableOrderingComposer,
      $$RoutineComposerDraftsTableAnnotationComposer,
      $$RoutineComposerDraftsTableCreateCompanionBuilder,
      $$RoutineComposerDraftsTableUpdateCompanionBuilder,
      (
        RoutineComposerDraftRow,
        BaseReferences<
          _$LocalDb,
          $RoutineComposerDraftsTable,
          RoutineComposerDraftRow
        >,
      ),
      RoutineComposerDraftRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      required String id,
      required String entityType,
      required String entityId,
      required String operation,
      Value<String?> payloadJson,
      Value<int> attemptCount,
      Value<String?> lastErrorSummary,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<String> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String?> payloadJson,
      Value<int> attemptCount,
      Value<String?> lastErrorSummary,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$LocalDb, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorSummary => $composableBuilder(
    column: $table.lastErrorSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$LocalDb, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorSummary => $composableBuilder(
    column: $table.lastErrorSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$LocalDb, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorSummary => $composableBuilder(
    column: $table.lastErrorSummary,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $SyncOutboxTable,
          SyncOutboxRow,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxRow,
            BaseReferences<_$LocalDb, $SyncOutboxTable, SyncOutboxRow>,
          ),
          SyncOutboxRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$LocalDb db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastErrorSummary = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                attemptCount: attemptCount,
                lastErrorSummary: lastErrorSummary,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String entityId,
                required String operation,
                Value<String?> payloadJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastErrorSummary = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                attemptCount: attemptCount,
                lastErrorSummary: lastErrorSummary,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $SyncOutboxTable,
      SyncOutboxRow,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxRow,
        BaseReferences<_$LocalDb, $SyncOutboxTable, SyncOutboxRow>,
      ),
      SyncOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$CloudAccountStatesTableCreateCompanionBuilder =
    CloudAccountStatesCompanion Function({
      Value<int> singletonId,
      Value<String> entitlementTier,
      Value<String?> pendingTier,
      Value<String> bootstrapStatus,
      Value<String?> userId,
      Value<String?> email,
      Value<String?> authProvider,
      Value<DateTime?> lastBootstrapAt,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastSyncError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$CloudAccountStatesTableUpdateCompanionBuilder =
    CloudAccountStatesCompanion Function({
      Value<int> singletonId,
      Value<String> entitlementTier,
      Value<String?> pendingTier,
      Value<String> bootstrapStatus,
      Value<String?> userId,
      Value<String?> email,
      Value<String?> authProvider,
      Value<DateTime?> lastBootstrapAt,
      Value<DateTime?> lastSyncAt,
      Value<String?> lastSyncError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$CloudAccountStatesTableFilterComposer
    extends Composer<_$LocalDb, $CloudAccountStatesTable> {
  $$CloudAccountStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entitlementTier => $composableBuilder(
    column: $table.entitlementTier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingTier => $composableBuilder(
    column: $table.pendingTier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bootstrapStatus => $composableBuilder(
    column: $table.bootstrapStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authProvider => $composableBuilder(
    column: $table.authProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastBootstrapAt => $composableBuilder(
    column: $table.lastBootstrapAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CloudAccountStatesTableOrderingComposer
    extends Composer<_$LocalDb, $CloudAccountStatesTable> {
  $$CloudAccountStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entitlementTier => $composableBuilder(
    column: $table.entitlementTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingTier => $composableBuilder(
    column: $table.pendingTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bootstrapStatus => $composableBuilder(
    column: $table.bootstrapStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authProvider => $composableBuilder(
    column: $table.authProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastBootstrapAt => $composableBuilder(
    column: $table.lastBootstrapAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CloudAccountStatesTableAnnotationComposer
    extends Composer<_$LocalDb, $CloudAccountStatesTable> {
  $$CloudAccountStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entitlementTier => $composableBuilder(
    column: $table.entitlementTier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingTier => $composableBuilder(
    column: $table.pendingTier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bootstrapStatus => $composableBuilder(
    column: $table.bootstrapStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get authProvider => $composableBuilder(
    column: $table.authProvider,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastBootstrapAt => $composableBuilder(
    column: $table.lastBootstrapAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CloudAccountStatesTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $CloudAccountStatesTable,
          CloudAccountStateRow,
          $$CloudAccountStatesTableFilterComposer,
          $$CloudAccountStatesTableOrderingComposer,
          $$CloudAccountStatesTableAnnotationComposer,
          $$CloudAccountStatesTableCreateCompanionBuilder,
          $$CloudAccountStatesTableUpdateCompanionBuilder,
          (
            CloudAccountStateRow,
            BaseReferences<
              _$LocalDb,
              $CloudAccountStatesTable,
              CloudAccountStateRow
            >,
          ),
          CloudAccountStateRow,
          PrefetchHooks Function()
        > {
  $$CloudAccountStatesTableTableManager(
    _$LocalDb db,
    $CloudAccountStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CloudAccountStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CloudAccountStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CloudAccountStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<String> entitlementTier = const Value.absent(),
                Value<String?> pendingTier = const Value.absent(),
                Value<String> bootstrapStatus = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> authProvider = const Value.absent(),
                Value<DateTime?> lastBootstrapAt = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CloudAccountStatesCompanion(
                singletonId: singletonId,
                entitlementTier: entitlementTier,
                pendingTier: pendingTier,
                bootstrapStatus: bootstrapStatus,
                userId: userId,
                email: email,
                authProvider: authProvider,
                lastBootstrapAt: lastBootstrapAt,
                lastSyncAt: lastSyncAt,
                lastSyncError: lastSyncError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<String> entitlementTier = const Value.absent(),
                Value<String?> pendingTier = const Value.absent(),
                Value<String> bootstrapStatus = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> authProvider = const Value.absent(),
                Value<DateTime?> lastBootstrapAt = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CloudAccountStatesCompanion.insert(
                singletonId: singletonId,
                entitlementTier: entitlementTier,
                pendingTier: pendingTier,
                bootstrapStatus: bootstrapStatus,
                userId: userId,
                email: email,
                authProvider: authProvider,
                lastBootstrapAt: lastBootstrapAt,
                lastSyncAt: lastSyncAt,
                lastSyncError: lastSyncError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CloudAccountStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $CloudAccountStatesTable,
      CloudAccountStateRow,
      $$CloudAccountStatesTableFilterComposer,
      $$CloudAccountStatesTableOrderingComposer,
      $$CloudAccountStatesTableAnnotationComposer,
      $$CloudAccountStatesTableCreateCompanionBuilder,
      $$CloudAccountStatesTableUpdateCompanionBuilder,
      (
        CloudAccountStateRow,
        BaseReferences<
          _$LocalDb,
          $CloudAccountStatesTable,
          CloudAccountStateRow
        >,
      ),
      CloudAccountStateRow,
      PrefetchHooks Function()
    >;

class $LocalDbManager {
  final _$LocalDb _db;
  $LocalDbManager(this._db);
  $$RoutinesTableTableManager get routines =>
      $$RoutinesTableTableManager(_db, _db.routines);
  $$RoutineRunsTableTableManager get routineRuns =>
      $$RoutineRunsTableTableManager(_db, _db.routineRuns);
  $$RoutineRemindersTableTableManager get routineReminders =>
      $$RoutineRemindersTableTableManager(_db, _db.routineReminders);
  $$RoutineSessionsTableTableManager get routineSessions =>
      $$RoutineSessionsTableTableManager(_db, _db.routineSessions);
  $$RoutineComposerDraftsTableTableManager get routineComposerDrafts =>
      $$RoutineComposerDraftsTableTableManager(_db, _db.routineComposerDrafts);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$CloudAccountStatesTableTableManager get cloudAccountStates =>
      $$CloudAccountStatesTableTableManager(_db, _db.cloudAccountStates);
}
