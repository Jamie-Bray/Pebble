import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/services/proof_photo_export_service.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';

// 1x1 transparent PNG so Image.file decodes cleanly inside the test.
final _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _FakeProofPhotoExportService implements ProofPhotoExportService {
  _FakeProofPhotoExportService({required this.canSave, required this.result});

  final bool canSave;
  final ProofPhotoExportResult result;
  final List<File> savedFiles = [];

  @override
  bool get canSaveCopyToPhotos => canSave;

  @override
  Future<ProofPhotoExportResult> saveCopyToPhotos(File proofFile) async {
    savedFiles.add(proofFile);
    return result;
  }
}

void main() {
  late Directory tempDir;
  late File photoFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gallery_viewer_test');
    photoFile = File('${tempDir.path}/proof.png');
    await photoFile.writeAsBytes(_tinyPngBytes);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Widget buildViewer(_FakeProofPhotoExportService service) {
    return ProviderScope(
      overrides: [
        proofPhotoExportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        home: PebblePhotoGalleryViewer(
          photos: const [
            PebbleGalleryPhoto(
              id: 'proof-1',
              storedPath: 'proof-1',
              title: 'Lock the front door',
            ),
          ],
          initialIndex: 0,
          resolvePhotoFile: (_) async => photoFile,
        ),
      ),
    );
  }

  testWidgets('save action exports the resolved photo file', (tester) async {
    final service = _FakeProofPhotoExportService(
      canSave: true,
      result: const ProofPhotoExportResult(
        saved: true,
        message: 'Saved a copy to Photos.',
      ),
    );

    await tester.pumpWidget(buildViewer(service));
    await tester.pumpAndSettle();

    final saveButton = find.text('Save a copy to Photos');
    expect(saveButton, findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(service.savedFiles, hasLength(1));
    expect(service.savedFiles.single.path, photoFile.path);
    expect(find.text('Saved a copy to Photos.'), findsOneWidget);
  });

  testWidgets('save action is hidden when the platform cannot save', (
    tester,
  ) async {
    final service = _FakeProofPhotoExportService(
      canSave: false,
      result: const ProofPhotoExportResult(saved: false, message: 'n/a'),
    );

    await tester.pumpWidget(buildViewer(service));
    await tester.pumpAndSettle();

    expect(find.text('Save a copy to Photos'), findsNothing);
  });
}
