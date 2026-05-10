import 'dart:convert';

import 'package:pebble_routines/core/database/routine_step.dart';

class RoutineComposerStepDraft {
  final String id;
  final String text;
  final bool requiresPhoto;
  final bool allowSkip;
  final StepGuidanceAudio? guidanceAudio;
  final int sortOrder;

  const RoutineComposerStepDraft({
    required this.id,
    required this.text,
    required this.requiresPhoto,
    required this.allowSkip,
    this.guidanceAudio,
    required this.sortOrder,
  });

  factory RoutineComposerStepDraft.fromJson(Map<String, dynamic> json) {
    return RoutineComposerStepDraft(
      id: json['id'] as String,
      text: (json['text'] as String?) ?? '',
      requiresPhoto: json['requiresPhoto'] as bool? ?? false,
      allowSkip: json['allowSkip'] as bool? ?? false,
      guidanceAudio: json['guidanceAudio'] is Map
          ? StepGuidanceAudio.fromJson(
              Map<String, dynamic>.from(json['guidanceAudio'] as Map),
            )
          : null,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  static List<RoutineComposerStepDraft> listFromJsonString(String jsonString) {
    if (jsonString.trim().isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map(
          (item) => RoutineComposerStepDraft.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static String listToJsonString(List<RoutineComposerStepDraft> steps) {
    return jsonEncode(steps.map((step) => step.toJson()).toList());
  }

  RoutineComposerStepDraft copyWith({
    String? id,
    String? text,
    bool? requiresPhoto,
    bool? allowSkip,
    StepGuidanceAudio? guidanceAudio,
    bool clearGuidanceAudio = false,
    int? sortOrder,
  }) {
    return RoutineComposerStepDraft(
      id: id ?? this.id,
      text: text ?? this.text,
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      allowSkip: allowSkip ?? this.allowSkip,
      guidanceAudio: clearGuidanceAudio
          ? null
          : guidanceAudio ?? this.guidanceAudio,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'requiresPhoto': requiresPhoto,
      'allowSkip': allowSkip,
      if (guidanceAudio != null) 'guidanceAudio': guidanceAudio!.toJson(),
      'sortOrder': sortOrder,
    };
  }

  bool get hasText => text.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutineComposerStepDraft &&
        other.id == id &&
        other.text == text &&
        other.requiresPhoto == requiresPhoto &&
        other.allowSkip == allowSkip &&
        other.guidanceAudio == guidanceAudio &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode =>
      Object.hash(id, text, requiresPhoto, allowSkip, guidanceAudio, sortOrder);
}
