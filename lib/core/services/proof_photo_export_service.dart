import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

class ProofPhotoExportResult {
  const ProofPhotoExportResult({required this.saved, required this.message});

  final bool saved;
  final String message;
}

abstract class ProofPhotoExportService {
  bool get canSaveCopyToPhotos;

  Future<ProofPhotoExportResult> saveCopyToPhotos(File proofFile);
}

/// Saves through the platform gallery APIs with the least permission possible:
/// Android 10+ and iOS need no runtime prompt for add-only saves; only
/// Android 9 and below ask, and only at the moment the user exports.
/// The action wording must stay "Save a copy to Photos", never "Download".
class GalProofPhotoExportService implements ProofPhotoExportService {
  const GalProofPhotoExportService();

  @override
  bool get canSaveCopyToPhotos =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<ProofPhotoExportResult> saveCopyToPhotos(File proofFile) async {
    if (!canSaveCopyToPhotos) {
      return const ProofPhotoExportResult(
        saved: false,
        message: "This phone can't save to Photos.",
      );
    }
    if (!await proofFile.exists()) {
      return const ProofPhotoExportResult(
        saved: false,
        message: 'This photo has been deleted.',
      );
    }
    try {
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          return const ProofPhotoExportResult(
            saved: false,
            message: 'Pebble needs permission to save to Photos. You can allow it in your phone settings.',
          );
        }
      }
      await Gal.putImage(proofFile.path);
      return const ProofPhotoExportResult(
        saved: true,
        message: 'Saved to Photos.',
      );
    } on GalException catch (error) {
      final message = switch (error.type) {
        GalExceptionType.accessDenied =>
          'Pebble needs permission to save to Photos. You can allow it in your phone settings.',
        GalExceptionType.notEnoughSpace =>
          "There isn't enough space on this phone to save the photo.",
        GalExceptionType.notSupportedFormat =>
          "Photos can't save this file type.",
        GalExceptionType.unexpected =>
          "Couldn't save to Photos. Try again.",
      };
      return ProofPhotoExportResult(saved: false, message: message);
    }
  }
}

final proofPhotoExportServiceProvider = Provider<ProofPhotoExportService>(
  (ref) => const GalProofPhotoExportService(),
);
