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

    test('guidance audio saved before cloud backup still parses', () {
      final decoded = RoutineStep.fromJson({
        'runtimeType': 'check',
        'label': 'Feed the cat',
        'guidanceAudio': {
          'localPath': 'clip.wav',
          'durationMs': 4000,
          'mimeType': 'audio/wav',
          'byteSize': 1024,
        },
      });

      expect(decoded.guidanceAudio?.localPath, 'clip.wav');
      expect(decoded.guidanceAudio?.remoteObjectKey, isNull);
      expect(
        decoded.guidanceAudio!.toJson().containsKey('remoteObjectKey'),
        isFalse,
      );
    });

    test('round-trips the remote object key once backed up', () {
      const audio = StepGuidanceAudio(
        localPath: 'clip.wav',
        durationMs: 4000,
        remoteObjectKey: 'users/u1/guidance_audio/clip.wav',
      );
      const step = RoutineStep.check(
        label: 'Feed the cat',
        guidanceAudio: audio,
      );

      final decoded = RoutineStep.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(step.toJson())) as Map),
      );

      expect(decoded.guidanceAudio, audio);
      expect(
        decoded.guidanceAudio?.remoteObjectKey,
        'users/u1/guidance_audio/clip.wav',
      );
    });
  });
}
