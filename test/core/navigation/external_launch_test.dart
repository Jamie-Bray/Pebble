import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:pebble_routines/core/navigation/external_launch.dart';

Future<GoRouter> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Text('Home')),
      GoRoute(
        path: '/play/:id',
        builder: (context, state) =>
            Text('Player ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('opens the player from Home', (tester) async {
    final router = await _pump(tester);
    var refreshes = 0;

    openRoutineFromExternalLaunch(
      router,
      routineId: 7,
      refreshSession: () => refreshes++,
    );
    await tester.pumpAndSettle();

    expect(find.text('Player 7'), findsOneWidget);
    expect(refreshes, 0);
  });

  testWidgets('asks for a fresh session when that player is already open '
      '(pushed over Home)', (tester) async {
    final router = await _pump(tester);
    unawaited(router.push('/play/7'));
    await tester.pumpAndSettle();
    expect(currentRouterPath(router), '/play/7');
    var refreshes = 0;

    openRoutineFromExternalLaunch(
      router,
      routineId: 7,
      refreshSession: () => refreshes++,
    );
    await tester.pumpAndSettle();

    expect(refreshes, 1);
    expect(find.text('Player 7'), findsOneWidget);
  });

  testWidgets('asks for a fresh session when the player was opened by go', (
    tester,
  ) async {
    final router = await _pump(tester);
    router.go('/play/7');
    await tester.pumpAndSettle();
    var refreshes = 0;

    openRoutineFromExternalLaunch(
      router,
      routineId: 7,
      refreshSession: () => refreshes++,
    );

    expect(refreshes, 1);
  });

  testWidgets('switches to another routine without refreshing', (tester) async {
    final router = await _pump(tester);
    unawaited(router.push('/play/7'));
    await tester.pumpAndSettle();
    var refreshes = 0;

    openRoutineFromExternalLaunch(
      router,
      routineId: 8,
      refreshSession: () => refreshes++,
    );
    await tester.pumpAndSettle();

    expect(refreshes, 0);
    expect(find.text('Player 8'), findsOneWidget);
    expect(currentRouterPath(router), '/play/8');
  });
}
