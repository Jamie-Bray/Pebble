import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/providers/ai_caption_store.dart';
import 'package:pebble_routines/features/routines/execution/ui/player_proof_zone.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';
import 'package:pebble_routines/features/routines/execution/ui/step_check_off.dart';

RoutineSessionProofAsset _asset(String id) => RoutineSessionProofAsset(
  proofId: id,
  localRelativePath: 'proofs/$id.webp',
  remoteObjectKey: null,
  uploadStatus: ProofUploadStatus.localOnly,
  capturedAt: DateTime(2026, 10, 7, 8, 2),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<RoutineSessionProofAsset> assets,
  required Map<String, ProofAiDescription> captions,
  void Function(String proofId)? onRetry,
  List<String>? opened,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: PlayerProofZone(
              proofAssets: assets,
              aiDescriptionFor: (asset) => captions[asset.proofId],
              showCaptionSlot: true,
              resolveProofPath: (path) async => '/nowhere/$path',
              onTakePhoto: () async {},
              onOpenPhoto: (id) async => opened?.add(id),
              onRemovePhoto: (_) async {},
              onRetryCaption: onRetry,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('screen readers can expand and collapse the compact trail', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StepTrail(
            compact: true,
            entries: [
              StepTrailEntry(
                stepIndex: 0,
                label: 'Door',
                timeLabel: '8:00 AM',
                skipped: false,
              ),
              StepTrailEntry(
                stepIndex: 1,
                label: 'Window',
                timeLabel: '8:01 AM',
                skipped: false,
              ),
              StepTrailEntry(
                stepIndex: 2,
                label: 'Lights',
                timeLabel: '8:02 AM',
                skipped: false,
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in [
      'Show all checked steps',
      'Show fewer checked steps',
    ]) {
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp(label)));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          nodeId: node.id,
          type: SemanticsAction.tap,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(
      find.bySemanticsLabel(RegExp('Show all checked steps')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('screen readers can retry a caption and use photo actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final retried = <String>[];
    await _pump(
      tester,
      assets: [_asset('p1')],
      captions: const {'p1': ProofAiDescription.failed(canRetry: true)},
      onRetry: retried.add,
    );
    final retry = tester.getSemantics(
      find.bySemanticsLabel('$aiPhotoFailedMessage $aiPhotoRetryAction'),
    );
    expect(retry.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        nodeId: retry.id,
        type: SemanticsAction.tap,
        viewId: tester.view.viewId,
      ),
    );
    expect(retried, ['p1']);
    for (final label in ['Remove proof photo 1', 'Add another proof photo']) {
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    }
    semantics.dispose();
  });

  testWidgets('no photo: one tile that takes the photo, no caption slot', (
    tester,
  ) async {
    await _pump(tester, assets: const [], captions: const {});
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text(aiPhotoDescribingLabel), findsNothing);
  });

  testWidgets('one photo: "Describing…" holds the slot, then the caption', (
    tester,
  ) async {
    final asset = _asset('p1');
    await _pump(
      tester,
      assets: [asset],
      captions: const {'p1': ProofAiDescription.pending()},
    );
    expect(find.textContaining(aiPhotoDescribingLabel), findsOneWidget);
    final slot = find.byType(ProofCaptionSlot);
    final pendingHeight = tester.getSize(slot).height;

    await _pump(
      tester,
      assets: [asset],
      captions: const {'p1': ProofAiDescription.ready('A grey door.')},
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('A grey door.'), findsOneWidget);
    expect(find.textContaining(aiPhotoLabel), findsOneWidget);
    expect(
      tester.getSize(slot).height,
      pendingHeight,
      reason: 'nothing below the photo moves when the caption lands',
    );
  });

  testWidgets('a retryable failure offers Try again and calls back', (
    tester,
  ) async {
    final retried = <String>[];
    await _pump(
      tester,
      assets: [_asset('p1')],
      captions: const {'p1': ProofAiDescription.failed(canRetry: true)},
      onRetry: retried.add,
    );
    expect(find.textContaining(aiPhotoRetryFailedShort), findsOneWidget);
    await tester.tap(find.textContaining(aiPhotoRetryAction));
    expect(retried, ['p1']);
  });

  testWidgets('a refusal shows its reason and no Try again', (tester) async {
    await _pump(
      tester,
      assets: [_asset('p1')],
      captions: const {
        'p1': ProofAiDescription.failed(
          failureMessage: aiPhotoUnavailableMessage,
        ),
      },
    );
    expect(find.textContaining(aiPhotoUnavailableMessage), findsOneWidget);
    expect(find.textContaining(aiPhotoRetryAction), findsNothing);
  });

  testWidgets('several photos: one caption slot, for the picked thumbnail', (
    tester,
  ) async {
    final opened = <String>[];
    final assets = [_asset('p1'), _asset('p2'), _asset('p3')];
    const captions = {
      'p1': ProofAiDescription.ready('First photo text.'),
      'p2': ProofAiDescription.ready('Second photo text.'),
      'p3': ProofAiDescription.pending(),
    };
    await _pump(tester, assets: assets, captions: captions, opened: opened);
    expect(find.byType(ProofCaptionSlot), findsOneWidget);
    // The newest photo is shown first.
    expect(find.textContaining(aiPhotoDescribingLabel), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('proof-strip-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Second photo text.'), findsOneWidget);
    expect(find.textContaining('First photo text.'), findsNothing);
    expect(opened, isEmpty, reason: 'the first tap only picks it');

    await tester.tap(find.byKey(const ValueKey('proof-strip-1')));
    await tester.pumpAndSettle();
    expect(opened, ['p2']);
    expect(find.byKey(const ValueKey('proof-add-tile')), findsOneWidget);
  });

  testWidgets('the completion receipt counts the run\'s AI descriptions', (
    tester,
  ) async {
    Future<void> pumpComplete({required int described, int describing = 0}) {
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: RoutineCompleteScreen(
                routineName: 'Leaving the house',
                totalStepsCompleted: 2,
                totalPhotosSaved: 2,
                photos: [
                  for (final id in ['p1', 'p2'])
                    CompletionPhoto(id: id, load: () async => null),
                ],
                aiDescribedCount: described,
                aiDescribingCount: describing,
                onBackToHome: () {},
                onReviewRoutine: () {},
              ),
            ),
          ),
        ),
      );
    }

    await pumpComplete(described: 0, describing: 2);
    expect(find.text('Describing 2 photos…'), findsOneWidget);
    await pumpComplete(described: 1, describing: 1);
    expect(find.text('1 AI description · 1 more on the way'), findsOneWidget);
    await pumpComplete(described: 2);
    expect(
      find.text('2 AI descriptions · Tap a photo to read them'),
      findsOneWidget,
    );
    await pumpComplete(described: 0);
    expect(find.byKey(const ValueKey('completion-ai-line')), findsNothing);
  });

  testWidgets('large text: the strip and caption fit without overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      assets: [_asset('p1'), _asset('p2'), _asset('p3'), _asset('p4')],
      captions: const {
        'p4': ProofAiDescription.ready(
          'A brass key in a white door lock, seen close up, with a grey '
          'lever handle above it.',
        ),
      },
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('A brass key'), findsOneWidget);
  });
}
