import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';

import 'fake_routine_composer_draft_repository.dart';

void main() {
  Finder findStepFields() => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == 'Step',
  );
  Finder findPrimaryStepField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Start with your first step',
  );
  Finder findAnyStepField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.hintText == 'Start with your first step' ||
            widget.decoration?.hintText == 'Step'),
  );

  testWidgets('blank routine auto-focuses the first step on open', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          home: RoutineComposerScreen.newDraft(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(findPrimaryStepField(), findsOneWidget);
    final firstStepField = tester.widget<TextField>(findPrimaryStepField());
    expect(firstStepField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('submit on a step adds a new row and moves focus forward', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: RoutineComposerScreen.newDraft(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstStepFieldFinder = findAnyStepField().first;
    await tester.tap(firstStepFieldFinder);
    await tester.pump();
    await tester.enterText(firstStepFieldFinder, 'Lock doors');
    await tester.pump();
    tester
        .widget<TextField>(firstStepFieldFinder)
        .onChanged
        ?.call('Lock doors\n');
    await tester.pumpAndSettle();

    expect(find.text('Lock doors'), findsOneWidget);
    expect(findStepFields(), findsOneWidget);
    final newStepField = tester.widget<TextField>(findStepFields().first);
    expect(newStepField.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
    'add step focuses the first empty step instead of adding another blank row',
    (tester) async {
      final repository = FakeRoutineComposerDraftRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineComposerDraftRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
              useMaterial3: true,
            ),
            home: RoutineComposerScreen.newDraft(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Add step'));
      await tester.pumpAndSettle();

      expect(findPrimaryStepField(), findsOneWidget);
      expect(findStepFields(), findsNothing);
      final firstStepField = tester.widget<TextField>(findPrimaryStepField());
      expect(firstStepField.focusNode?.hasFocus, isTrue);
    },
  );

  testWidgets('bottom done enables only with content and clutter is removed', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
            useMaterial3: true,
          ),
          home: RoutineComposerScreen.newDraft(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Routine Composer'), findsNothing);
    expect(find.text('Brain-dump first. Upgrade steps after.'), findsNothing);
    expect(find.text('Keys & wallet'), findsNothing);
    expect(find.text('New Routine'), findsOneWidget);

    final doneButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save routine'),
    );
    expect(doneButton.onPressed, isNull);

    final firstStepFieldFinder = findAnyStepField().first;
    await tester.tap(firstStepFieldFinder);
    await tester.pump();
    await tester.enterText(firstStepFieldFinder, 'Check doors');
    await tester.pump();

    final enabledDoneButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save routine'),
    );
    expect(enabledDoneButton.onPressed, isNotNull);
  });

  testWidgets('done publishes successfully while the step field is focused', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();
    var saveCompleted = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          home: RoutineComposerScreen.newDraft(
            onSaveComplete: (_) {
              saveCompleted = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstStepFieldFinder = findAnyStepField().first;
    await tester.tap(firstStepFieldFinder);
    await tester.pump();
    await tester.enterText(firstStepFieldFinder, 'Lock doors');
    await tester.pump();

    expect(
      tester.widget<TextField>(firstStepFieldFinder).focusNode?.hasFocus,
      isTrue,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save routine'));
    await tester.pumpAndSettle();

    expect(saveCompleted, isTrue);
    expect(repository.publishDraftCallCount, 1);
    expect(repository.publishedRoutines.single.title, 'Lock doors');
  });

  testWidgets('draft status avoids durable saved copy while editing', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          home: RoutineComposerScreen.newDraft(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstStepFieldFinder = findAnyStepField().first;
    await tester.enterText(firstStepFieldFinder, 'Check windows');
    await tester.pump();

    expect(find.text('Updating...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));

    expect(find.text('Ready to finish'), findsOneWidget);
  });

  testWidgets('template composer uses distinct title and seed content', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();
    const seedData = RoutineComposerSeedData(
      title: 'Leaving Home',
      iconKey: 'house',
      colorHex: null,
      steps: [
        RoutineComposerStepDraft(
          id: 'template-step',
          text: 'Lock the door',
          requiresPhoto: false,
          allowSkip: false,
          sortOrder: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),
          home: RoutineComposerScreen.customizeTemplate(seedData: seedData),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Use Template'), findsOneWidget);
    expect(find.text('New Routine'), findsNothing);
    expect(find.text('Leaving Home'), findsOneWidget);
    expect(find.text('Lock the door'), findsOneWidget);
  });
}
