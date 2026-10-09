import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';

/// The painted headers Pebble ships, so a routine can have a cover without
/// a photo. They are drawn in the theme's colours, so they never clash.
enum RoutineCoverScene {
  ripples('Ripples'),
  hills('Hills'),
  shore('Shore'),
  dawn('Dawn'),
  night('Night'),
  softGlow('Soft glow');

  const RoutineCoverScene(this.label);

  final String label;
}

/// A routine's cover: a painted scene or the user's own photo. Shown as a
/// soft, dimmed header behind Home. Kept on this phone only (not backed up).
sealed class RoutineCover {
  const RoutineCover();

  String encode();

  static RoutineCover? decode(String? raw) {
    if (raw == null) return null;
    if (raw.startsWith('scene:')) {
      final key = raw.substring(6);
      for (final scene in RoutineCoverScene.values) {
        if (scene.name == key) return RoutineCoverSceneChoice(scene);
      }
      return null;
    }
    if (raw.startsWith('photo:')) {
      return RoutineCoverPhoto(raw.substring(6));
    }
    return null;
  }
}

class RoutineCoverSceneChoice extends RoutineCover {
  const RoutineCoverSceneChoice(this.scene);

  final RoutineCoverScene scene;

  @override
  String encode() => 'scene:${scene.name}';

  @override
  bool operator ==(Object other) =>
      other is RoutineCoverSceneChoice && other.scene == scene;

  @override
  int get hashCode => scene.hashCode;
}

class RoutineCoverPhoto extends RoutineCover {
  const RoutineCoverPhoto(this.path);

  /// Absolute path of the copy Pebble keeps in its documents folder (or,
  /// before saving, the picked file).
  final String path;

  @override
  String encode() => 'photo:$path';

  @override
  bool operator ==(Object other) =>
      other is RoutineCoverPhoto && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Reads and writes covers. Photos are copied into
/// `<documents>/routine_covers/` so they survive the picker's temp folder
/// being cleared.
class RoutineCoverStore {
  RoutineCoverStore(this._prefs, {Future<Directory> Function()? documents})
    : _documents = documents ?? getApplicationDocumentsDirectory;

  final SharedPreferences _prefs;
  final Future<Directory> Function() _documents;

  static String _key(int routineId) => 'pebble.routine_cover.$routineId';

  RoutineCover? read(int routineId) =>
      RoutineCover.decode(_prefs.getString(_key(routineId)));

  Future<void> write(int routineId, RoutineCover? cover) async {
    final previous = read(routineId);
    if (cover == null) {
      await _prefs.remove(_key(routineId));
    } else {
      var stored = cover;
      if (cover is RoutineCoverPhoto && cover != previous) {
        stored = RoutineCoverPhoto(await _copyIn(routineId, cover.path));
      }
      await _prefs.setString(_key(routineId), stored.encode());
    }
    if (previous is RoutineCoverPhoto && previous != read(routineId)) {
      await _deleteQuietly(previous.path);
    }
  }

  Future<String> _copyIn(int routineId, String source) async {
    final dir = Directory(p.join((await _documents()).path, 'routine_covers'));
    await dir.create(recursive: true);
    // A fresh name each time, so Image.file never shows a cached old cover.
    final target = p.join(
      dir.path,
      '${routineId}_${DateTime.now().millisecondsSinceEpoch}'
      '${p.extension(source).isEmpty ? '.jpg' : p.extension(source)}',
    );
    await File(source).copy(target);
    return target;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover cover file is harmless.
    }
  }
}

final routineCoverStoreProvider = Provider<RoutineCoverStore>(
  (ref) => RoutineCoverStore(ref.watch(sharedPreferencesProvider)),
);

/// Bumped after every write so [routineCoverProvider] re-reads.
final routineCoverRevisionProvider = StateProvider<int>((ref) => 0);

final routineCoverProvider = Provider.family<RoutineCover?, int>((
  ref,
  routineId,
) {
  ref.watch(routineCoverRevisionProvider);
  return ref.watch(routineCoverStoreProvider).read(routineId);
});

/// Saves [cover] for [routineId] and refreshes everything showing it.
Future<void> saveRoutineCover(
  WidgetRef ref,
  int routineId,
  RoutineCover? cover,
) async {
  await ref.read(routineCoverStoreProvider).write(routineId, cover);
  ref.read(routineCoverRevisionProvider.notifier).state++;
}
