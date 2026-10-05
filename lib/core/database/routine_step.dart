import 'package:freezed_annotation/freezed_annotation.dart';

part 'routine_step.freezed.dart';
part 'routine_step.g.dart';

const maxStepDescriptionChars = 500;

@freezed
class RoutineStep with _$RoutineStep {
  const factory RoutineStep.check({
    required String label,
    @Default(false) bool requiresPhoto,
    @Default(1) int photoCount,
    String? photoPrompt,
    @Default(false) bool allowSkip,
    @Default(true) bool allowGallery,
    StepGuidanceAudio? guidanceAudio,
  }) = CheckStep;

  const factory RoutineStep.info({required String message}) = InfoStep;

  const factory RoutineStep.timer({required int duration}) = TimerStep;

  factory RoutineStep.fromJson(Map<String, dynamic> json) =>
      _$RoutineStepFromJson(json);
}

@JsonSerializable()
class StepGuidanceAudio {
  const StepGuidanceAudio({
    required this.localPath,
    required this.durationMs,
    this.mimeType,
    this.byteSize,
    this.remoteObjectKey,
  });

  final String localPath;
  final int durationMs;
  final String? mimeType;
  final int? byteSize;

  /// Cloud backup copy in the `routine-proofs` bucket, set once the clip has
  /// been uploaded. Omitted from JSON while null so routines saved before
  /// voice prompt backup round-trip unchanged.
  @JsonKey(includeIfNull: false)
  final String? remoteObjectKey;

  StepGuidanceAudio copyWith({String? remoteObjectKey}) {
    return StepGuidanceAudio(
      localPath: localPath,
      durationMs: durationMs,
      mimeType: mimeType,
      byteSize: byteSize,
      remoteObjectKey: remoteObjectKey ?? this.remoteObjectKey,
    );
  }

  factory StepGuidanceAudio.fromJson(Map<String, dynamic> json) =>
      _$StepGuidanceAudioFromJson(json);

  Map<String, dynamic> toJson() => _$StepGuidanceAudioToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StepGuidanceAudio &&
        other.localPath == localPath &&
        other.durationMs == durationMs &&
        other.mimeType == mimeType &&
        other.byteSize == byteSize &&
        other.remoteObjectKey == remoteObjectKey;
  }

  @override
  int get hashCode =>
      Object.hash(localPath, durationMs, mimeType, byteSize, remoteObjectKey);
}

// Extension to easily check photo requirements
extension RoutineStepPhotoExtension on RoutineStep {
  /// Optional check-step instructions use the existing photoPrompt JSON field
  /// so old routines, saved sessions and backups need no schema migration.
  /// The historical default camera instruction is not a step description.
  String? get stepDescription {
    final text = photoPrompt?.trim();
    return text == null || text.isEmpty || text == 'Take a photo' ? null : text;
  }

  bool get hasPhotoRequirement => when(
    check:
        (
          label,
          requiresPhoto,
          photoCount,
          photoPrompt,
          allowSkip,
          allowGallery,
          guidanceAudio,
        ) => requiresPhoto,
    info: (message) => false,
    timer: (duration) => false,
  );

  int get requiredPhotoCount => when(
    check:
        (
          label,
          requiresPhoto,
          photoCount,
          photoPrompt,
          allowSkip,
          allowGallery,
          guidanceAudio,
        ) => requiresPhoto ? photoCount : 0,
    info: (message) => 0,
    timer: (duration) => 0,
  );

  String? get photoPrompt => when(
    check:
        (
          label,
          requiresPhoto,
          photoCount,
          photoPrompt,
          allowSkip,
          allowGallery,
          guidanceAudio,
        ) => photoPrompt,
    info: (message) => null,
    timer: (duration) => null,
  );

  // NEW: Add canSkip property
  bool get canSkip => when(
    check:
        (
          label,
          requiresPhoto,
          photoCount,
          photoPrompt,
          allowSkip,
          allowGallery,
          guidanceAudio,
        ) => allowSkip,
    info: (message) => true, // Info steps can always be skipped
    timer: (duration) => false, // Timer steps cannot be skipped
  );

  bool get allowGallery => when(
    check:
        (
          label,
          requiresPhoto,
          photoCount,
          photoPrompt,
          allowSkip,
          allowGallery,
          guidanceAudio,
        ) => allowGallery,
    info: (message) => false,
    timer: (duration) => false,
  );

  StepGuidanceAudio? get guidanceAudio => maybeWhen(
    check:
        (
          label,
          requiresPhoto,
          photoCount,
          photoPrompt,
          allowSkip,
          allowGallery,
          guidanceAudio,
        ) => guidanceAudio,
    orElse: () => null,
  );
}

// Helper methods for step creation
extension RoutineStepHelpers on RoutineStep {
  /// Create a simple check step
  static RoutineStep simpleCheck(String label) => RoutineStep.check(
    label: label,
    requiresPhoto: false,
    allowSkip: false,
    allowGallery: true,
  );

  /// Create a check step with photo requirement
  static RoutineStep checkWithPhoto(String label) => RoutineStep.check(
    label: label,
    requiresPhoto: true,
    allowSkip: false,
    allowGallery: true,
  );

  /// Create a skippable check step
  static RoutineStep skippableCheck(String label) => RoutineStep.check(
    label: label,
    requiresPhoto: false,
    allowSkip: true,
    allowGallery: true,
  );
}
