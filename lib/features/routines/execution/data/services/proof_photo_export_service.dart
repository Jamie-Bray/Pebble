import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProofPhotoExportResult {
  const ProofPhotoExportResult({required this.saved, required this.message});

  final bool saved;
  final String message;
}

abstract class ProofPhotoExportService {
  bool get canSaveCopyToPhotos;

  Future<ProofPhotoExportResult> saveCopyToPhotos(File proofFile);
}

class PlatformProofPhotoExportService implements ProofPhotoExportService {
  const PlatformProofPhotoExportService();

  @override
  bool get canSaveCopyToPhotos => false;

  @override
  Future<ProofPhotoExportResult> saveCopyToPhotos(File proofFile) async {
    if (!await proofFile.exists()) {
      return const ProofPhotoExportResult(
        saved: false,
        message: 'This proof photo is no longer available.',
      );
    }

    // TODO: Add a least-permission iOS/Android gallery-save implementation.
    // The action label must be "Save a copy to Photos". Do not request broad
    // gallery/delete permissions; only ask at the moment the user exports.
    return const ProofPhotoExportResult(
      saved: false,
      message: 'Save a copy to Photos is not ready in this build.',
    );
  }
}

final proofPhotoExportServiceProvider = Provider<ProofPhotoExportService>(
  (ref) => const PlatformProofPhotoExportService(),
);
