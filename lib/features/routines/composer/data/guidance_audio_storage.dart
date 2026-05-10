import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:uuid/uuid.dart';

abstract class GuidanceAudioStorage {
  static const maxDuration = Duration(seconds: 10);
  static const defaultMimeType = 'audio/wav';

  Future<String> prepareRecordingPath();

  Future<StepGuidanceAudio> createMetadataForRecordedFile({
    required String absolutePath,
    required Duration duration,
    String mimeType = defaultMimeType,
  });

  Future<String> resolveStoredPath(String localPath);

  Future<void> deleteStoredAudio(String localPath);
}

class LocalGuidanceAudioStorage implements GuidanceAudioStorage {
  const LocalGuidanceAudioStorage({
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory = documentsDirectory;

  static const _folderName = 'routine_guidance_audio';
  static const _uuid = Uuid();
  final Future<Directory> Function()? _documentsDirectory;

  @override
  Future<String> prepareRecordingPath() async {
    final root = await _rootDirectory();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return p.join(root.path, '${_uuid.v4()}.wav');
  }

  @override
  Future<StepGuidanceAudio> createMetadataForRecordedFile({
    required String absolutePath,
    required Duration duration,
    String mimeType = GuidanceAudioStorage.defaultMimeType,
  }) async {
    final file = File(absolutePath);
    if (!await file.exists()) {
      throw StateError('Guidance audio file not found.');
    }
    if (duration > GuidanceAudioStorage.maxDuration) {
      await file.delete();
      throw StateError('Guidance audio is longer than 10 seconds.');
    }

    final fileName = p.basename(file.absolute.path);
    final byteSize = await file.length();

    return StepGuidanceAudio(
      localPath: fileName,
      durationMs: duration.inMilliseconds,
      mimeType: mimeType,
      byteSize: byteSize,
    );
  }

  @override
  Future<String> resolveStoredPath(String localPath) async {
    if (localPath.isEmpty || p.isAbsolute(localPath)) {
      return localPath;
    }
    // Always extract basename to prevent symlink traversal corruption from older saves
    final fileName = p.basename(localPath);
    final root = await _rootDirectory();
    return p.join(root.path, fileName);
  }

  @override
  Future<void> deleteStoredAudio(String localPath) async {
    final absolutePath = await resolveStoredPath(localPath);
    if (absolutePath.isEmpty) return;
    final file = File(absolutePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _rootDirectory() async {
    final documentsDirectory = await _documentsRoot();
    return Directory(p.join(documentsDirectory.path, _folderName));
  }

  Future<Directory> _documentsRoot() {
    final override = _documentsDirectory;
    if (override != null) {
      return override();
    }
    return getApplicationDocumentsDirectory();
  }
}

final guidanceAudioStorageProvider = Provider<GuidanceAudioStorage>((ref) {
  return const LocalGuidanceAudioStorage();
});
