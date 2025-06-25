import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble/models/routine.dart';
import 'package:pebble/screens/routine_details_screen.dart';
import 'package:pebble/screens/edit_routine_screen.dart';

class MockNavigatorObserver extends NavigatorObserver {
  Route? lastPopped;
  Object? lastPopResult;
  @override
  void didPop(Route route, Route? previousRoute) {
    lastPopped = route;
    if (route.settings.arguments != null) {
      lastPopResult = route.settings.arguments;
    }
  }
}

void main() {
  final sampleRoutine = Routine(
    id: 'r1',
    title: 'Evening Routine',
    description: 'Wind down and prepare for sleep.',
    categories: ['Evening', 'Wellness'],
    tasks: [
      Task(
        id: 't1',
        label: 'Brush teeth',
        category: 'Evening',
        notes: '',
        photoRequired: false,
        order: 1,
      ),
      Task(
        id: 't2',
        label: 'Take medication',
        category: 'Wellness',
        notes: 'With water',
        photoRequired: true,
        order: 2,
      ),
      Task(
        id: 't3',
        label: 'Read a book',
        category: 'Evening',
        notes: null,
        photoRequired: false,
        order: 3,
      ),
    ],
  );

  Widget makeTestable({required Widget child}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: child,
    );
  }

  testWidgets('RoutineDetailsScreen displays title, description, categories, and tasks', (WidgetTester tester) async {
    await tester.pumpWidget(makeTestable(child: RoutineDetailsScreen(routine: sampleRoutine)));

    // Title and description
    expect(find.byKey(const Key('routineTitle')), findsOneWidget);
    expect(find.text('Evening Routine'), findsWidgets);
    expect(find.byKey(const Key('routineDescription')), findsOneWidget);
    expect(find.text('Wind down and prepare for sleep.'), findsWidgets);

    // Category filter chips
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Evening'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Wellness'), findsOneWidget);

    // Task widgets
    expect(find.text('Brush teeth'), findsOneWidget);
    expect(find.text('Take medication'), findsOneWidget);
    expect(find.text('Read a book'), findsOneWidget);

    // Icons: photoRequired and notes
    final cameraIcon = find.byIcon(Icons.camera_alt_outlined);
    final noteIcon = find.byIcon(Icons.sticky_note_2_outlined);
    expect(cameraIcon, findsOneWidget); // Only 'Take medication' has photoRequired
    expect(noteIcon, findsOneWidget);   // Only 'Take medication' has notes
  });

  testWidgets('Tapping a task opens the bottom sheet', (WidgetTester tester) async {
    await tester.pumpWidget(makeTestable(child: RoutineDetailsScreen(routine: sampleRoutine)));

    // Tap on 'Take medication' task
    await tester.tap(find.text('Take medication'));
    await tester.pumpAndSettle();

    // Bottom sheet should appear with 'Edit Task' and label
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Label: Take medication'), findsOneWidget);
    expect(find.text('Notes: With water'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('RoutineDetailsScreen edit flow updates routine', (tester) async {
    final routine = Routine(
      id: 'r1',
      title: 'Test Routine',
      description: 'Original description',
      categories: ['Test'],
      tasks: [
        Task(
          id: 't1',
          label: 'Task 1',
          category: 'Test',
          notes: '',
          photoRequired: false,
          order: 0,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RoutineDetailsScreen(routine: routine),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial values
    expect(find.byKey(const Key('routineTitle')), findsOneWidget);
    expect(find.text('Test Routine'), findsWidgets);
    expect(find.byKey(const Key('routineDescription')), findsOneWidget);
    expect(find.text('Original description'), findsWidgets);

    // Tap Edit button
    await tester.tap(find.byKey(const Key('editRoutineButton')));
    await tester.pumpAndSettle();

    // EditRoutineScreen should appear, change title and description
    await tester.enterText(find.byType(TextFormField).at(0), 'Updated Routine');
    await tester.enterText(find.byType(TextFormField).at(1), 'Updated description');
    // Save
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save').first);
    await tester.pumpAndSettle();

    // RoutineDetailsScreen should show updated values
    expect(find.text('Updated Routine'), findsWidgets);
    expect(find.text('Updated description'), findsWidgets);
  });
} 