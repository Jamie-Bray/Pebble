import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';

void main() {
  group('GuidanceAudioStorage', () {
    late Directory tempRoot;
    late LocalGuidanceAudioStorage storage;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp(
        'pebble_guidance_audio_test_',
      );
      storage = LocalGuidanceAudioStorage(
        documentsDirectory: () async {
          return tempRoot;
        },
      );
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('creates metadata for clips within the 10 second cap', () async {
      final path = p.join(tempRoot.path, 'clip.m4a');
      await File(path).writeAsBytes([1, 2, 3, 4]);

      final metadata = await storage.createMetadataForRecordedFile(
        absolutePath: path,
        duration: GuidanceAudioStorage.maxDuration,
      );

      expect(metadata.localPath, 'clip.m4a');
      expect(metadata.durationMs, 10000);
      expect(metadata.mimeType, GuidanceAudioStorage.defaultMimeType);
      expect(metadata.byteSize, 4);
    });

    test('rejects and deletes clips over the 10 second cap', () async {
      final path = p.join(tempRoot.path, 'too-long.m4a');
      final file = await File(path).writeAsBytes([1, 2, 3]);

      await expectLater(
        storage.createMetadataForRecordedFile(
          absolutePath: path,
          duration:
              GuidanceAudioStorage.maxDuration +
              const Duration(milliseconds: 1),
        ),
        throwsStateError,
      );

      expect(await file.exists(), isFalse);
    });
  });
}
