import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/routine_step.dart';

void main() {
  group('RoutineStep guidance audio serialization', () {
    test('serializes and deserializes guidance audio metadata', () {
      const audio = StepGuidanceAudio(
        localPath: 'routine_guidance_audio/clip.m4a',
        durationMs: 5000,
        mimeType: 'audio/mp4',
        byteSize: 2048,
      );
      const step = RoutineStep.check(
        label: 'Check the back door',
        guidanceAudio: audio,
      );

      final decoded = RoutineStep.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(step.toJson())) as Map),
      );

      expect(decoded.guidanceAudio, audio);
    });

    test('existing check steps without guidance audio still deserialize', () {
      final decoded = RoutineStep.fromJson({
        'runtimeType': 'check',
        'label': 'Lock the door',
        'requiresPhoto': false,
        'photoCount': 1,
        'allowSkip': false,
        'allowGallery': true,
      });

      expect(decoded.guidanceAudio, isNull);
      expect(decoded.hasPhotoRequirement, isFalse);
      expect(decoded.canSkip, isFalse);
    });

    test('existing photo proof steps remain unchanged', () {
      final decoded = RoutineStep.fromJson({
        'runtimeType': 'check',
        'label': 'Take a photo',
        'requiresPhoto': true,
        'photoCount': 1,
        'allowSkip': true,
        'allowGallery': true,
      });

      expect(decoded.guidanceAudio, isNull);
      expect(decoded.hasPhotoRequirement, isTrue);
      expect(decoded.requiredPhotoCount, 1);
      expect(decoded.canSkip, isTrue);
    });
  });
}
