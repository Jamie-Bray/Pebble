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
        message: 'Saving to Photos is not available on this device.',
      );
    }
    if (!await proofFile.exists()) {
      return const ProofPhotoExportResult(
        saved: false,
        message: 'This proof photo is no longer available.',
      );
    }
    try {
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          return const ProofPhotoExportResult(
            saved: false,
            message: 'Pebble needs permission before it can save to Photos.',
          );
        }
      }
      await Gal.putImage(proofFile.path);
      return const ProofPhotoExportResult(
        saved: true,
        message: 'Saved a copy to Photos.',
      );
    } on GalException catch (error) {
      final message = switch (error.type) {
        GalExceptionType.accessDenied =>
          'Pebble needs permission before it can save to Photos.',
        GalExceptionType.notEnoughSpace =>
          'There is not enough space on this device to save the photo.',
        GalExceptionType.notSupportedFormat =>
          'This photo is in a format that cannot be saved to Photos.',
        GalExceptionType.unexpected =>
          'Something went wrong while saving to Photos. Please try again.',
      };
      return ProofPhotoExportResult(saved: false, message: message);
    }
  }
}

final proofPhotoExportServiceProvider = Provider<ProofPhotoExportService>(
  (ref) => const GalProofPhotoExportService(),
);
