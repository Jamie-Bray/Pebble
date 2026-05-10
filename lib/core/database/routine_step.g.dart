// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_step.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StepGuidanceAudio _$StepGuidanceAudioFromJson(Map<String, dynamic> json) =>
    StepGuidanceAudio(
      localPath: json['localPath'] as String,
      durationMs: (json['durationMs'] as num).toInt(),
      mimeType: json['mimeType'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt(),
    );

Map<String, dynamic> _$StepGuidanceAudioToJson(StepGuidanceAudio instance) =>
    <String, dynamic>{
      'localPath': instance.localPath,
      'durationMs': instance.durationMs,
      'mimeType': instance.mimeType,
      'byteSize': instance.byteSize,
    };

_$CheckStepImpl _$$CheckStepImplFromJson(Map<String, dynamic> json) =>
    _$CheckStepImpl(
      label: json['label'] as String,
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 1,
      photoPrompt: json['photoPrompt'] as String?,
      allowSkip: json['allowSkip'] as bool? ?? false,
      allowGallery: json['allowGallery'] as bool? ?? true,
      guidanceAudio: json['guidanceAudio'] == null
          ? null
          : StepGuidanceAudio.fromJson(
              json['guidanceAudio'] as Map<String, dynamic>,
            ),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$CheckStepImplToJson(_$CheckStepImpl instance) =>
    <String, dynamic>{
      'label': instance.label,
      'requiresPhoto': instance.requiresPhoto,
      'photoCount': instance.photoCount,
      'photoPrompt': instance.photoPrompt,
      'allowSkip': instance.allowSkip,
      'allowGallery': instance.allowGallery,
      'guidanceAudio': instance.guidanceAudio,
      'runtimeType': instance.$type,
    };

_$InfoStepImpl _$$InfoStepImplFromJson(Map<String, dynamic> json) =>
    _$InfoStepImpl(
      message: json['message'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$InfoStepImplToJson(_$InfoStepImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'runtimeType': instance.$type,
    };

_$TimerStepImpl _$$TimerStepImplFromJson(Map<String, dynamic> json) =>
    _$TimerStepImpl(
      duration: (json['duration'] as num).toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$TimerStepImplToJson(_$TimerStepImpl instance) =>
    <String, dynamic>{
      'duration': instance.duration,
      'runtimeType': instance.$type,
    };
