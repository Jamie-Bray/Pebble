import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

abstract class RoutinePlayerPhotoPicker {
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
    double? maxWidth,
  });

  /// Recovers a capture whose result never reached Dart because Android
  /// destroyed the activity while the system camera was in the foreground.
  Future<XFile?> retrieveLostPhoto();
}

class ImagePickerRoutinePlayerPhotoPicker implements RoutinePlayerPhotoPicker {
  ImagePickerRoutinePlayerPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
    double? maxWidth,
  }) {
    return _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
  }

  @override
  Future<XFile?> retrieveLostPhoto() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        return null;
      }
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        return files.last;
      }
      return response.file;
    } catch (_) {
      // Recovery is best-effort; a failure here must never block the player.
      return null;
    }
  }
}

final routinePlayerPhotoPickerProvider = Provider<RoutinePlayerPhotoPicker>(
  (ref) => ImagePickerRoutinePlayerPhotoPicker(),
);
