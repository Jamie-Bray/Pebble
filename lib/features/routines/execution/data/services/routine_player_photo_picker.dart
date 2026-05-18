import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

abstract class RoutinePlayerPhotoPicker {
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
    double? maxWidth,
  });
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
}

final routinePlayerPhotoPickerProvider = Provider<RoutinePlayerPhotoPicker>(
  (ref) => ImagePickerRoutinePlayerPhotoPicker(),
);
