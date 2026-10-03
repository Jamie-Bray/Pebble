import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/remote_proof_asset_data_source.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';

const _userId = '11111111-1111-1111-1111-111111111111';
const _objectKey = 'users/$_userId/run/run-1/proof-1.webp';

class _FakeRemoteProofs extends RemoteProofAssetDataSource {
  _FakeRemoteProofs({this.signedInUserId = _userId}) : super(null);

  @override
  String? signedInUserId;

  final List<String> requested = [];
  Object? failWith;
  Uint8List bytes = Uint8List.fromList([1, 2, 3]);
  Completer<void>? gate;

  @override
  bool get isEnabled => true;

  @override
  Future<Uint8List?> downloadBytes(String objectKey) async {
    requested.add(objectKey);
    await gate?.future;
    final error = failWith;
    if (error != null) throw error;
    return bytes;
  }
}

RoutineSessionProofAsset _asset({String remoteObjectKey = _objectKey}) {
  return RoutineSessionProofAsset(
    proofId: 'proof-1',
    localRelativePath: 'routine_session_proofs/session-1/proof-1.webp',
    remoteObjectKey: remoteObjectKey,
    uploadStatus: ProofUploadStatus.uploaded,
    capturedAt: DateTime(2026, 8, 4),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late _FakeRemoteProofs remote;
  late DateTime now;
  late LocalRoutineSessionProofStorage storage;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('pebble_proofs_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => documents.path,
        );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    remote = _FakeRemoteProofs();
    now = DateTime(2026, 8, 4, 12);
    storage = LocalRoutineSessionProofStorage(
      remote: remote,
      fairUseStore: LocalProofMediaFairUseStore(prefs),
      clock: () => now,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await documents.delete(recursive: true);
  });

  test('a proof missing from storage is requested once, not on every '
      'rebuild', () async {
    remote.failWith = const StorageException(
      'Object not found',
      statusCode: '404',
      error: 'not_found',
    );

    for (var i = 0; i < 5; i++) {
      expect(await storage.resolveProofAssetFile(_asset()), isNull);
      now = now.add(const Duration(minutes: 3));
    }

    expect(remote.requested, [_objectKey]);
  });

  test('never downloads while signed out', () async {
    remote.signedInUserId = null;

    expect(await storage.resolveProofAssetFile(_asset()), isNull);
    expect(remote.requested, isEmpty);
  });

  test('never downloads another account\'s proofs', () async {
    remote.signedInUserId = '22222222-2222-2222-2222-222222222222';

    expect(await storage.resolveProofAssetFile(_asset()), isNull);
    expect(remote.requested, isEmpty);
  });

  test('transient failures back off, then recover', () async {
    remote.failWith = const SocketException('offline');

    expect(await storage.resolveProofAssetFile(_asset()), isNull);
    expect(await storage.resolveProofAssetFile(_asset()), isNull);
    expect(remote.requested, hasLength(1));

    now = now.add(const Duration(minutes: 1, seconds: 1));
    expect(await storage.resolveProofAssetFile(_asset()), isNull);
    expect(remote.requested, hasLength(2));

    // Second failure doubles the wait.
    now = now.add(const Duration(minutes: 1, seconds: 1));
    expect(await storage.resolveProofAssetFile(_asset()), isNull);
    expect(remote.requested, hasLength(2));

    remote.failWith = null;
    now = now.add(const Duration(minutes: 1));
    final file = await storage.resolveProofAssetFile(_asset());
    expect(file, isNotNull);
    expect(await file!.readAsBytes(), [1, 2, 3]);
    expect(remote.requested, hasLength(3));

    // Once on disk, the local copy is used without another download.
    expect(await storage.resolveProofAssetFile(_asset()), isNotNull);
    expect(remote.requested, hasLength(3));
  });

  test('concurrent requests for the same proof share one download', () async {
    final gate = remote.gate = Completer<void>();
    final pending = [
      storage.resolveProofAssetFile(_asset()),
      storage.resolveProofAssetFile(_asset()),
    ];
    // Let both callers get past their (real, async) local-file check and
    // reach the network before the first download finishes.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    gate.complete();
    final results = await Future.wait(pending);

    expect(results.every((file) => file != null), isTrue);
    expect(remote.requested, hasLength(1));
  });

  test('recognises Supabase "object not found" responses', () {
    expect(
      isMissingProofObjectError(
        const StorageException('Object not found', statusCode: '400'),
      ),
      isTrue,
    );
    expect(
      isMissingProofObjectError(
        const StorageException(
          'exp claim timestamp check failed',
          statusCode: '400',
          error: 'InvalidJWT',
        ),
      ),
      isFalse,
    );
    expect(isMissingProofObjectError(const SocketException('x')), isFalse);
  });
}
