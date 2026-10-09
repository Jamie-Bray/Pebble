import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';

void main() {
  test('AI photo descriptions are hidden for launch', () {
    expect(aiPhotoFeatureVisible, isFalse);
  });
}
