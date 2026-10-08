import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/routines/cover/routine_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('covers round-trip through their stored form', () {
    for (final scene in RoutineCoverScene.values) {
      final cover = RoutineCoverSceneChoice(scene);
      expect(RoutineCover.decode(cover.encode()), cover);
    }
    const photo = RoutineCoverPhoto('/docs/routine_covers/1_1.jpg');
    expect(RoutineCover.decode(photo.encode()), photo);
    expect(RoutineCover.decode('scene:volcano'), isNull);
    expect(RoutineCover.decode(null), isNull);
  });

  test('a picked photo is copied in, and the old copy removed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final docs = await Directory.systemTemp.createTemp('covers');
    addTearDown(() => docs.delete(recursive: true));
    final store = RoutineCoverStore(prefs, documents: () async => docs);

    final picked = File('${docs.path}/picked.jpg')..writeAsBytesSync([1, 2]);
    await store.write(4, RoutineCoverPhoto(picked.path));
    final first = store.read(4)! as RoutineCoverPhoto;
    expect(first.path, contains('routine_covers'));
    expect(File(first.path).existsSync(), isTrue);

    await store.write(
      4,
      const RoutineCoverSceneChoice(RoutineCoverScene.hills),
    );
    expect(
      store.read(4),
      const RoutineCoverSceneChoice(RoutineCoverScene.hills),
    );
    expect(File(first.path).existsSync(), isFalse);

    await store.write(4, null);
    expect(store.read(4), isNull);
  });
}
