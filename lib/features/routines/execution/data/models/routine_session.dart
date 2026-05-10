import 'package:pebble_routines/core/database/routine_step.dart';

enum RoutineSessionStatus { active, completed, discarded }

enum SessionStepStatus { pending, completed, skipped }

enum ProofUploadStatus { localOnly, pendingUpload, uploaded, failed }

enum SessionStorageScope { localOnly, personalCloud, workspaceCloud }

class SessionRoutingContext {
  final String? workspaceId;
  final String? ownerUserId;
  final SessionStorageScope storageScope;

  const SessionRoutingContext({
    required this.storageScope,
    this.workspaceId,
    this.ownerUserId,
  });
}

class RoutineSessionSyncMetadata {
  final bool needsSync;
  final DateTime? lastSyncedAt;
  final DateTime? lastSyncAttemptAt;
  final String? remoteSessionId;
  final String? completedRunId;
  final String? lastError;

  const RoutineSessionSyncMetadata({
    required this.needsSync,
    this.lastSyncedAt,
    this.lastSyncAttemptAt,
    this.remoteSessionId,
    this.completedRunId,
    this.lastError,
  });

  factory RoutineSessionSyncMetadata.fromJson(Map<String, dynamic> json) {
    return RoutineSessionSyncMetadata(
      needsSync: json['needsSync'] == true,
      lastSyncedAt: _parseDateTime(json['lastSyncedAt']),
      lastSyncAttemptAt: _parseDateTime(json['lastSyncAttemptAt']),
      remoteSessionId: json['remoteSessionId']?.toString(),
      completedRunId: json['completedRunId']?.toString(),
      lastError: json['lastError']?.toString(),
    );
  }

  RoutineSessionSyncMetadata copyWith({
    bool? needsSync,
    DateTime? lastSyncedAt,
    DateTime? lastSyncAttemptAt,
    String? remoteSessionId,
    String? completedRunId,
    String? lastError,
  }) {
    return RoutineSessionSyncMetadata(
      needsSync: needsSync ?? this.needsSync,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      remoteSessionId: remoteSessionId ?? this.remoteSessionId,
      completedRunId: completedRunId ?? this.completedRunId,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'needsSync': needsSync,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'lastSyncAttemptAt': lastSyncAttemptAt?.toIso8601String(),
      'remoteSessionId': remoteSessionId,
      'completedRunId': completedRunId,
      'lastError': lastError,
    };
  }
}

class RoutineSessionProofAsset {
  final String proofId;
  final String localRelativePath;
  final String? remoteObjectKey;
  final ProofUploadStatus uploadStatus;
  final DateTime capturedAt;

  const RoutineSessionProofAsset({
    required this.proofId,
    required this.localRelativePath,
    required this.remoteObjectKey,
    required this.uploadStatus,
    required this.capturedAt,
  });

  factory RoutineSessionProofAsset.fromJson(Map<String, dynamic> json) {
    return RoutineSessionProofAsset(
      proofId: json['proofId']?.toString() ?? '',
      localRelativePath: json['localRelativePath']?.toString() ?? '',
      remoteObjectKey: json['remoteObjectKey']?.toString(),
      uploadStatus: _proofUploadStatusFromString(
        json['uploadStatus']?.toString(),
      ),
      capturedAt: _parseDateTime(json['capturedAt']) ?? DateTime.now(),
    );
  }

  RoutineSessionProofAsset copyWith({
    String? proofId,
    String? localRelativePath,
    String? remoteObjectKey,
    ProofUploadStatus? uploadStatus,
    DateTime? capturedAt,
  }) {
    return RoutineSessionProofAsset(
      proofId: proofId ?? this.proofId,
      localRelativePath: localRelativePath ?? this.localRelativePath,
      remoteObjectKey: remoteObjectKey ?? this.remoteObjectKey,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'proofId': proofId,
      'localRelativePath': localRelativePath,
      'remoteObjectKey': remoteObjectKey,
      'uploadStatus': uploadStatus.name,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}

class RoutineSessionStepState {
  final int stepIndex;
  final SessionStepStatus status;
  final DateTime? completedAt;
  final List<RoutineSessionProofAsset> proofAssets;

  const RoutineSessionStepState({
    required this.stepIndex,
    required this.status,
    required this.completedAt,
    required this.proofAssets,
  });

  factory RoutineSessionStepState.initial(int stepIndex) {
    return RoutineSessionStepState(
      stepIndex: stepIndex,
      status: SessionStepStatus.pending,
      completedAt: null,
      proofAssets: const [],
    );
  }

  factory RoutineSessionStepState.fromJson(Map<String, dynamic> json) {
    final rawProofs = json['proofAssets'];
    final proofAssets = rawProofs is List
        ? rawProofs
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(RoutineSessionProofAsset.fromJson)
              .toList()
        : const <RoutineSessionProofAsset>[];

    return RoutineSessionStepState(
      stepIndex: (json['stepIndex'] as num?)?.toInt() ?? 0,
      status: _sessionStepStatusFromString(json['status']?.toString()),
      completedAt: _parseDateTime(json['completedAt']),
      proofAssets: proofAssets,
    );
  }

  RoutineSessionStepState copyWith({
    int? stepIndex,
    SessionStepStatus? status,
    DateTime? completedAt,
    List<RoutineSessionProofAsset>? proofAssets,
  }) {
    return RoutineSessionStepState(
      stepIndex: stepIndex ?? this.stepIndex,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      proofAssets: proofAssets ?? this.proofAssets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepIndex': stepIndex,
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'proofAssets': proofAssets.map((asset) => asset.toJson()).toList(),
    };
  }
}

class RoutineSessionResumeSummary {
  final String sessionId;
  final int routineId;
  final String routineTitleSnapshot;
  final int currentStepIndex;
  final int totalStepCount;
  final DateTime updatedAt;

  const RoutineSessionResumeSummary({
    required this.sessionId,
    required this.routineId,
    required this.routineTitleSnapshot,
    required this.currentStepIndex,
    required this.totalStepCount,
    required this.updatedAt,
  });

  int get displayStepNumber {
    if (totalStepCount <= 0) {
      return 0;
    }
    final clampedIndex = currentStepIndex.clamp(0, totalStepCount - 1);
    return clampedIndex + 1;
  }
}

class RoutineSession {
  final String sessionId;
  final int routineId;
  final String routineTitleSnapshot;
  final String? workspaceId;
  final String? ownerUserId;
  final SessionStorageScope storageScope;
  final DateTime startedAt;
  final DateTime updatedAt;
  final RoutineSessionStatus status;
  final int currentStepIndex;
  final int totalStepCount;
  final int? baseRoutineVersion;
  final List<RoutineStep> routineSnapshotSteps;
  final List<RoutineSessionStepState> stepStates;
  final RoutineSessionSyncMetadata? syncMetadata;
  final DateTime? completedAt;
  final DateTime? discardedAt;

  const RoutineSession({
    required this.sessionId,
    required this.routineId,
    required this.routineTitleSnapshot,
    required this.workspaceId,
    required this.ownerUserId,
    required this.storageScope,
    required this.startedAt,
    required this.updatedAt,
    required this.status,
    required this.currentStepIndex,
    required this.totalStepCount,
    required this.baseRoutineVersion,
    required this.routineSnapshotSteps,
    required this.stepStates,
    required this.syncMetadata,
    required this.completedAt,
    required this.discardedAt,
  });

  factory RoutineSession.fromJson(Map<String, dynamic> json) {
    final rawStepStates = json['stepStates'];
    final rawSnapshot = json['routineSnapshotSteps'];

    return RoutineSession(
      sessionId: json['sessionId']?.toString() ?? '',
      routineId: (json['routineId'] as num?)?.toInt() ?? 0,
      routineTitleSnapshot: json['routineTitleSnapshot']?.toString() ?? '',
      workspaceId: json['workspaceId']?.toString(),
      ownerUserId: json['ownerUserId']?.toString(),
      storageScope: _storageScopeFromString(json['storageScope']?.toString()),
      startedAt: _parseDateTime(json['startedAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
      status: _routineSessionStatusFromString(json['status']?.toString()),
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      totalStepCount: (json['totalStepCount'] as num?)?.toInt() ?? 0,
      baseRoutineVersion: (json['baseRoutineVersion'] as num?)?.toInt(),
      routineSnapshotSteps: rawSnapshot is List
          ? rawSnapshot
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .map(RoutineStep.fromJson)
                .toList()
          : const <RoutineStep>[],
      stepStates: rawStepStates is List
          ? rawStepStates
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .map(RoutineSessionStepState.fromJson)
                .toList()
          : const <RoutineSessionStepState>[],
      syncMetadata: json['syncMetadata'] is Map
          ? RoutineSessionSyncMetadata.fromJson(
              Map<String, dynamic>.from(json['syncMetadata'] as Map),
            )
          : null,
      completedAt: _parseDateTime(json['completedAt']),
      discardedAt: _parseDateTime(json['discardedAt']),
    ).normalized();
  }

  RoutineSession copyWith({
    String? sessionId,
    int? routineId,
    String? routineTitleSnapshot,
    String? workspaceId,
    String? ownerUserId,
    SessionStorageScope? storageScope,
    DateTime? startedAt,
    DateTime? updatedAt,
    RoutineSessionStatus? status,
    int? currentStepIndex,
    int? totalStepCount,
    int? baseRoutineVersion,
    List<RoutineStep>? routineSnapshotSteps,
    List<RoutineSessionStepState>? stepStates,
    RoutineSessionSyncMetadata? syncMetadata,
    DateTime? completedAt,
    DateTime? discardedAt,
  }) {
    return RoutineSession(
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
      routineSnapshotSteps: routineSnapshotSteps ?? this.routineSnapshotSteps,
      stepStates: stepStates ?? this.stepStates,
      syncMetadata: syncMetadata ?? this.syncMetadata,
      completedAt: completedAt ?? this.completedAt,
      discardedAt: discardedAt ?? this.discardedAt,
    ).normalized();
  }

  RoutineSession normalized() {
    final effectiveTotal = totalStepCount < 0
        ? 0
        : totalStepCount != 0
        ? totalStepCount
        : routineSnapshotSteps.length;
    final normalizedStepStates = List.generate(effectiveTotal, (index) {
      if (index < stepStates.length) {
        final state = stepStates[index];
        return state.stepIndex == index
            ? state
            : state.copyWith(stepIndex: index);
      }
      return RoutineSessionStepState.initial(index);
    });

    final lastIndex = effectiveTotal <= 0 ? 0 : effectiveTotal - 1;
    final normalizedCurrentStep = effectiveTotal <= 0
        ? 0
        : currentStepIndex.clamp(0, lastIndex);

    return RoutineSession(
      sessionId: sessionId,
      routineId: routineId,
      routineTitleSnapshot: routineTitleSnapshot,
      workspaceId: workspaceId,
      ownerUserId: ownerUserId,
      storageScope: storageScope,
      startedAt: startedAt,
      updatedAt: updatedAt,
      status: status,
      currentStepIndex: normalizedCurrentStep,
      totalStepCount: effectiveTotal,
      baseRoutineVersion: baseRoutineVersion,
      routineSnapshotSteps: routineSnapshotSteps,
      stepStates: normalizedStepStates,
      syncMetadata: syncMetadata,
      completedAt: completedAt,
      discardedAt: discardedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'routineId': routineId,
      'routineTitleSnapshot': routineTitleSnapshot,
      'workspaceId': workspaceId,
      'ownerUserId': ownerUserId,
      'storageScope': storageScope.name,
      'startedAt': startedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'currentStepIndex': currentStepIndex,
      'totalStepCount': totalStepCount,
      'baseRoutineVersion': baseRoutineVersion,
      'routineSnapshotSteps': routineSnapshotSteps
          .map((step) => step.toJson())
          .toList(),
      'stepStates': stepStates.map((stepState) => stepState.toJson()).toList(),
      'syncMetadata': syncMetadata?.toJson(),
      'completedAt': completedAt?.toIso8601String(),
      'discardedAt': discardedAt?.toIso8601String(),
    };
  }

  RoutineSessionResumeSummary toResumeSummary() {
    return RoutineSessionResumeSummary(
      sessionId: sessionId,
      routineId: routineId,
      routineTitleSnapshot: routineTitleSnapshot,
      currentStepIndex: currentStepIndex,
      totalStepCount: totalStepCount,
      updatedAt: updatedAt,
    );
  }

  List<bool> get completedSteps => stepStates
      .map((state) => state.status == SessionStepStatus.completed)
      .toList();

  List<bool> get skippedSteps => stepStates
      .map((state) => state.status == SessionStepStatus.skipped)
      .toList();

  List<DateTime?> get stepCompletionTimestamps =>
      stepStates.map((state) => state.completedAt).toList();

  int get completedStepsCount => stepStates
      .where((state) => state.status == SessionStepStatus.completed)
      .length;

  int get skippedStepsCount => stepStates
      .where((state) => state.status == SessionStepStatus.skipped)
      .length;

  RoutineStep? get currentStep {
    if (routineSnapshotSteps.isEmpty) {
      return null;
    }
    if (currentStepIndex < 0 ||
        currentStepIndex >= routineSnapshotSteps.length) {
      return null;
    }
    return routineSnapshotSteps[currentStepIndex];
  }

  RoutineSessionStepState? get currentStepState {
    if (stepStates.isEmpty) {
      return null;
    }
    if (currentStepIndex < 0 || currentStepIndex >= stepStates.length) {
      return null;
    }
    return stepStates[currentStepIndex];
  }

  bool get isActive => status == RoutineSessionStatus.active;

  bool get isFinalStep =>
      totalStepCount > 0 && currentStepIndex >= totalStepCount - 1;

  bool canAddProofToCurrentStep(int maxPhotos) {
    final stepState = currentStepState;
    if (stepState == null) {
      return false;
    }
    return stepState.proofAssets.length < maxPhotos;
  }

  bool get isTerminal {
    if (stepStates.isEmpty) {
      return false;
    }
    return stepStates.every(
      (state) => state.status != SessionStepStatus.pending,
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

RoutineSessionStatus _routineSessionStatusFromString(String? value) {
  return RoutineSessionStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => RoutineSessionStatus.active,
  );
}

SessionStepStatus _sessionStepStatusFromString(String? value) {
  return SessionStepStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => SessionStepStatus.pending,
  );
}

ProofUploadStatus _proofUploadStatusFromString(String? value) {
  return ProofUploadStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => ProofUploadStatus.localOnly,
  );
}

SessionStorageScope _storageScopeFromString(String? value) {
  return SessionStorageScope.values.firstWhere(
    (scope) => scope.name == value,
    orElse: () => SessionStorageScope.localOnly,
  );
}
