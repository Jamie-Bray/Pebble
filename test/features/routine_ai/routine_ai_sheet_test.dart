import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/routine_ai/routine_ai_service.dart';
import 'package:pebble_routines/features/routine_ai/ui/routine_ai_sheet.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAi implements RoutineAiClient {
  final calls = <({String key, String description, bool ask, int answers})>[];
  List<RoutineAiReply> replies = [];

  @override
  Future<RoutineAiStatus> status() async =>
      const RoutineAiStatus(enabled: true);

  @override
  Future<RoutineAiReply> build({
    required String buildKey,
    required String description,
    List<RoutineAiAnswer> answers = const [],
    bool askQuestions = false,
  }) async {
    calls.add((
      key: buildKey,
      description: description,
      ask: askQuestions,
      answers: answers.length,
    ));
    return replies.removeAt(0);
  }
}

const _draft = RoutineAiDraft(
  name: 'Leaving the house',
  steps: [
    RoutineAiStep(
      label: 'Hob dials off',
      photo: true,
      detail: 'Look at each dial on the hob and the oven.',
    ),
    RoutineAiStep(label: 'Back door locked', photo: false),
    RoutineAiStep(label: 'Front door locked', photo: true),
  ],
);

Future<Future<RoutineAiDraft?> Function()> _open(
  WidgetTester tester,
  _FakeAi ai, {
  SharedPreferences? prefs,
}) async {
  RoutineAiDraft? result;
  var done = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routineAiClientProvider.overrideWithValue(ai),
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.fromId(ThemeId.highNoon),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<RoutineAiDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const RoutineAiSheet(),
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  return () async => done ? result : null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a sentence becomes a draft the person can adjust and use', (
    tester,
  ) async {
    final ai = _FakeAi()..replies = [const RoutineAiReply.draft(_draft)];
    final result = await _open(tester, ai);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to check?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('routine-ai-description')),
      'leaving the house',
    );
    await tester.pump();
    expect(find.textContaining('free'), findsNothing);
    await tester.tap(find.text('Skip the questions and build it'));
    await tester.pumpAndSettle();

    expect(find.text('Leaving the house'), findsOneWidget);
    expect(find.text('Hob dials off'), findsOneWidget);

    // Photo off on the first step, and the second step removed.
    await tester.tap(find.byTooltip('Photo on').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Remove step').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this routine'));
    await tester.pumpAndSettle();

    final draft = await result();
    expect(draft, isNotNull);
    expect(draft!.steps.map((s) => s.label), [
      'Hob dials off',
      'Front door locked',
    ]);
    expect(draft.steps.first.photo, isFalse);
    expect(ai.calls.single.description, 'leaving the house');
  });

  testWidgets('questions first, then a draft on the same build', (
    tester,
  ) async {
    final ai = _FakeAi()
      ..replies = [
        const RoutineAiReply.questions([
          RoutineAiQuestion(
            question: 'Do you drive to work?',
            options: ['Yes', 'No'],
          ),
        ]),
        const RoutineAiReply.draft(_draft),
      ];
    await _open(tester, ai);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('routine-ai-description')),
      'leaving for work',
    );
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Do you drive to work?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.tap(find.text('Build it'));
    await tester.pumpAndSettle();

    expect(find.text('Hob dials off'), findsOneWidget);
    expect(ai.calls.length, 2);
    expect(ai.calls.first.ask, isTrue);
    expect(ai.calls.last.answers, 1);
    expect(ai.calls.first.key, ai.calls.last.key);
  });

  testWidgets(
    'closing after questions keeps the free build key for next time',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final ai = _FakeAi()
        ..replies = [
          const RoutineAiReply.questions([
            RoutineAiQuestion(
              question: 'Do you drive?',
              options: ['Yes', 'No'],
            ),
          ]),
          const RoutineAiReply.draft(_draft),
        ];
      await _open(tester, ai, prefs: prefs);
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bedtime'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Do you drive?'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        prefs.getString('routine_ai_pending_build_key'),
        ai.calls.first.key,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bedtime'));
      await tester.pump();
      await tester.tap(find.text('Skip the questions and build it'));
      await tester.pumpAndSettle();

      expect(find.text('Hob dials off'), findsOneWidget);
      expect(ai.calls.last.key, ai.calls.first.key);
      expect(prefs.getString('routine_ai_pending_build_key'), isNull);
    },
  );

  testWidgets('a used free build explains Personal Premium', (tester) async {
    final ai = _FakeAi()..replies = [const RoutineAiReply.refused('freeUsed')];
    await _open(tester, ai);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bedtime'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text("You've used your free AI build"), findsOneWidget);
    expect(
      find.textContaining('Build more routines with AI with Personal Premium.'),
      findsOneWidget,
    );
    expect(find.text('See Personal Premium'), findsOneWidget);
  });

  test('the draft seeds the editor with its steps and photo choices', () {
    final seed = routineAiSeedData(_draft);
    expect(seed.title, 'Leaving the house');
    expect(seed.steps.map((s) => s.text), [
      'Hob dials off',
      'Back door locked',
      'Front door locked',
    ]);
    expect(seed.steps.map((s) => s.requiresPhoto), [true, false, true]);
    expect(seed.steps.map((s) => s.sortOrder), [0, 1, 2]);
    // The hidden detail becomes the step's description in the editor.
    expect(
      seed.steps.first.photoPrompt,
      'Look at each dial on the hob and the oven.',
    );
    expect(seed.steps[1].photoPrompt, '');
  });

  test('a draft reply is read safely', () {
    expect(RoutineAiDraft.fromJson(null), isNull);
    expect(RoutineAiDraft.fromJson({'name': 'A', 'steps': []}), isNull);
    final draft = RoutineAiDraft.fromJson({
      'name': ' Bedtime ',
      'steps': [
        {'label': 'Lights off', 'photo': false},
        {'label': ''},
        'junk',
      ],
    });
    expect(draft!.name, 'Bedtime');
    expect(draft.steps.single.label, 'Lights off');
  });
}
