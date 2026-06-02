import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';

import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

import '../../../support/premium_policy_test_utils.dart';
import 'fake_routine_composer_draft_repository.dart';

void main() {
  Future<void> pumpComposer(
    WidgetTester tester, {
    required UserTier tier,
    RoutineComposerScreen? screen,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              screen ?? RoutineComposerScreen.newDraft(),
        ),
        GoRoute(
          path: '/premium',
          builder: (context, state) {
            return const Scaffold(body: Center(child: Text('Paywall')));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(
            FakeRoutineComposerDraftRepository(),
          ),
          subscriptionProvider.overrideWithValue(tier),
          premiumFeaturePolicyProvider.overrideWithValue(
            premiumFeaturePolicyForTier(tier),
          ),
          guidanceAudioStorageProvider.overrideWithValue(
            const _FakeGuidanceAudioStorage(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('free tier pressing record guidance audio opens the paywall', (
    tester,
  ) async {
    await pumpComposer(tester, tier: UserTier.personalFree);

    await tester.tap(find.text('Voice tip'));
    await tester.pumpAndSettle();
    expect(find.text('Upgrade for voice tips'), findsOneWidget);

    await tester.tap(find.text('Upgrade for voice tips'));
    await tester.pumpAndSettle();
    expect(find.text('Paywall'), findsOneWidget);
  });

  testWidgets(
    'premium tier exposes unlocked record guidance audio affordance',
    (tester) async {
      await pumpComposer(tester, tier: UserTier.personalPremium);

      await tester.tap(find.text('Voice tip'));
      await tester.pumpAndSettle();

      expect(find.text('Hold to record'), findsOneWidget);
      expect(find.byIcon(LucideIcons.lock), findsNothing);
    },
  );
}

class _FakeGuidanceAudioStorage implements GuidanceAudioStorage {
  const _FakeGuidanceAudioStorage();

  @override
  Future<StepGuidanceAudio> createMetadataForRecordedFile({
    required String absolutePath,
    required Duration duration,
    String mimeType = GuidanceAudioStorage.defaultMimeType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteStoredAudio(String localPath) async {
    // No-op for test
  }

  @override
  Future<void> cleanupOrphanedAudio(Set<String> activeLocalPaths) async {
    // No-op for test
  }

  @override
  Future<String> prepareRecordingPath() {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveStoredPath(String localPath) async {
    return localPath;
  }
}
