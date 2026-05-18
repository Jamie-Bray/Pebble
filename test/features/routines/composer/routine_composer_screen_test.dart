import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
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
  Finder findStepFieldWithText(String value, {bool skipOffstage = true}) =>
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == value,
        skipOffstage: skipOffstage,
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

      await tester.tap(find.widgetWithText(FilledButton, 'Add step'));
      await tester.pumpAndSettle();

      expect(findPrimaryStepField(), findsOneWidget);
      expect(findStepFields(), findsNothing);
      final firstStepField = tester.widget<TextField>(findPrimaryStepField());
      expect(firstStepField.focusNode?.hasFocus, isTrue);
    },
  );

  testWidgets('primary add step inserts a focused row after step text exists', (
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
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
    await tester.enterText(firstStepFieldFinder, 'Check the hob');
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Add next step'), findsOneWidget);
    expect(find.text('Add step creates the next one'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add next step'));
    await tester.pumpAndSettle();

    expect(find.text('Check the hob'), findsOneWidget);
    expect(findStepFields(), findsOneWidget);
    final newStepField = tester.widget<TextField>(findStepFields().first);
    expect(newStepField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('app bar done enables only with content and clutter is removed', (
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
    expect(find.widgetWithText(FilledButton, 'Add step'), findsOneWidget);
    expect(find.text('Save routine'), findsNothing);

    final doneButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Done'),
    );
    expect(doneButton.onPressed, isNull);

    final firstStepFieldFinder = findAnyStepField().first;
    await tester.tap(firstStepFieldFinder);
    await tester.pump();
    await tester.enterText(firstStepFieldFinder, 'Check doors');
    await tester.pump();

    final enabledDoneButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Done'),
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

    await tester.tap(find.widgetWithText(TextButton, 'Done'));
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

  testWidgets('edit mode focuses the requested initial step index', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = FakeRoutineComposerDraftRepository();
    final routine = _routine(
      id: 42,
      title: 'Departure Check',
      steps: List.generate(10, (index) => _step('Composer step ${index + 1}')),
    );

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
          home: RoutineComposerScreen.edit(
            routine: routine,
            initialStepIndex: 7,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    final targetField = findStepFieldWithText('Composer step 8');
    expect(targetField, findsOneWidget);
    expect(tester.widget<TextField>(targetField).focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid initial step target falls back without crashing', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();
    final routine = _routine(
      id: 43,
      title: 'Departure Check',
      steps: [_step('Check windows'), _step('Pack wallet')],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: RoutineComposerScreen.edit(
            routine: routine,
            initialStepIndex: 99,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Departure Check'), findsOneWidget);
    expect(find.text('Check windows'), findsOneWidget);
    expect(find.text('Pack wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Routine _routine({
  required int id,
  required String title,
  required List<RoutineStep> steps,
}) {
  final createdAt = DateTime(2026, 4, id % 28 + 1);
  return Routine(
    id: id,
    title: title,
    stepsJson: jsonEncode(steps.map((step) => step.toJson()).toList()),
    createdAt: createdAt,
    emoji: 'list-check',
    colorHex: null,
    isPinned: false,
    pinnedAt: null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: createdAt,
    cloudId: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

RoutineStep _step(String label) => RoutineStep.check(label: label);
