import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';

void main() {
  group('Proof media fair use policy', () {
    Future<LocalProofMediaFairUseStore> buildStore() async {
      SharedPreferences.setMockInitialValues({});
      return LocalProofMediaFairUseStore(await SharedPreferences.getInstance());
    }

    test(
      'allows proof uploads while under storage and upload limits',
      () async {
        final store = await buildStore();

        final check = await store.canUploadProof(byteCount: 100 * 1024);

        expect(check.allowed, isTrue);
        expect(check.reason, ProofMediaUploadBlockReason.none);
        expect(check.state.status, ProofMediaFairUseStatus.ok);
      },
    );

    test('blocks files above the hard per-file limit', () async {
      final store = await buildStore();

      final check = await store.canUploadProof(
        byteCount: ProofMediaFairUsePolicy.perFileLimitBytes + 1,
      );

      expect(check.allowed, isFalse);
      expect(check.reason, ProofMediaUploadBlockReason.fileTooLarge);
    });

    test(
      'blocks photo uploads after 500 uploads in the rolling window',
      () async {
        final store = await buildStore();

        for (
          var index = 0;
          index < ProofMediaFairUsePolicy.monthlyUploadLimit;
          index++
        ) {
          await store.recordProofUpload(byteCount: 1);
        }
        final check = await store.canUploadProof(byteCount: 1);

        expect(check.allowed, isFalse);
        expect(check.reason, ProofMediaUploadBlockReason.uploadsFull);
        expect(check.state.status, ProofMediaFairUseStatus.full);
      },
    );

    test('blocks photo uploads when active proof storage is full', () async {
      final store = await buildStore();

      await store.recordProofUpload(
        byteCount: ProofMediaFairUsePolicy.storageLimitBytes - 1,
      );
      final check = await store.canUploadProof(byteCount: 2);

      expect(check.allowed, isFalse);
      expect(check.reason, ProofMediaUploadBlockReason.storageFull);
    });

    test('reports warning once storage crosses 80 percent', () async {
      final store = await buildStore();

      await store.recordProofUpload(
        byteCount:
            (ProofMediaFairUsePolicy.storageLimitBytes *
                    ProofMediaFairUsePolicy.warningThreshold)
                .ceil() +
            1,
      );
      final state = await store.load();

      expect(state.status, ProofMediaFairUseStatus.warning);
      expect(state.storageLabel, contains('of 1 GB used'));
    });
  });
}
