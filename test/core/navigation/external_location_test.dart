import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:pebble_routines/core/navigation/external_location.dart';

/// A router with the same redirect and error page as the app's, and stub
/// screens for Home and the player.
GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => externalLocationRedirect(state.uri),
    errorBuilder: pebbleRouterErrorBuilder,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Text('Home')),
      GoRoute(
        path: '/play/:id',
        builder: (context, state) =>
            Text('Player ${state.pathParameters['id']}'),
      ),
    ],
  );
}

Future<GoRouter> _pump(WidgetTester tester) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('externalLocationRedirect', () {
    test('maps the widget launch URI to the player', () {
      expect(
        externalLocationRedirect(Uri.parse('pebble://play/42')),
        '/play/42',
      );
    });

    test('maps a bare routine id path to the player', () {
      expect(
        externalLocationRedirect(Uri.parse('/1791244052621')),
        '/play/1791244052621',
      );
    });

    test('sends other pebble:// URIs home', () {
      expect(externalLocationRedirect(Uri.parse('pebble://play')), '/');
      expect(externalLocationRedirect(Uri.parse('pebble://play/abc')), '/');
      expect(externalLocationRedirect(Uri.parse('pebble://settings')), '/');
    });

    test('leaves real routes and unknown paths alone', () {
      expect(externalLocationRedirect(Uri.parse('/')), isNull);
      expect(externalLocationRedirect(Uri.parse('/play/42')), isNull);
      expect(externalLocationRedirect(Uri.parse('/settings')), isNull);
      expect(externalLocationRedirect(Uri.parse('/nowhere')), isNull);
      expect(externalLocationRedirect(Uri.parse('/12/34')), isNull);
    });
  });

  group('router', () {
    testWidgets('a bare routine id opens the player', (tester) async {
      final router = await _pump(tester);
      router.go('/1791244052621');
      await tester.pumpAndSettle();

      expect(find.text('Player 1791244052621'), findsOneWidget);
      expect(find.textContaining('GoException'), findsNothing);
    });

    testWidgets('the widget launch URI opens the player', (tester) async {
      final router = await _pump(tester);
      router.go('pebble://play/42');
      await tester.pumpAndSettle();

      expect(find.text('Player 42'), findsOneWidget);
    });

    testWidgets('an unknown path shows the calm error page', (tester) async {
      final router = await _pump(tester);
      router.go('/no-such-page');
      await tester.pumpAndSettle();

      expect(find.text("This page isn't available"), findsOneWidget);
      expect(find.textContaining('GoException'), findsNothing);
      expect(find.textContaining('no routes'), findsNothing);

      await tester.tap(find.text('Back to home'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
