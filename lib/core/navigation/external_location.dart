import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';

final RegExp _digitsOnly = RegExp(r'^\d+$');

/// Maps a location that came from outside the app to a real Pebble route,
/// or returns null when [uri] needs no help.
///
/// The home-screen widget launches the app with `pebble://play/<id>`. Pebble
/// handles that launch in Dart, but if a launcher or platform ever hands the
/// URI (or just its path, `/<id>`) to the router as well, this sends it to
/// the player instead of a "page not found" screen:
///
/// - `pebble://play/<id>` and a bare `/<digits>` go to `/play/<id>`.
/// - Any other `pebble://` URI goes to Home.
String? externalLocationRedirect(Uri uri) {
  if (uri.scheme == 'pebble') {
    if (uri.host == 'play' && uri.pathSegments.isNotEmpty) {
      final id = uri.pathSegments.first;
      if (_digitsOnly.hasMatch(id)) return '/play/$id';
    }
    return '/';
  }
  final segments = uri.pathSegments;
  if (segments.length == 1 && _digitsOnly.hasMatch(segments.first)) {
    return '/play/${segments.first}';
  }
  return null;
}

/// The router's error page: a calm "not available" screen with a way home.
/// It never shows the raw router exception.
Widget pebbleRouterErrorBuilder(BuildContext context, GoRouterState state) {
  return const PageNotAvailableScreen();
}

/// Shown for a location Pebble has no screen for.
class PageNotAvailableScreen extends StatelessWidget {
  const PageNotAvailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foundation = context.darkFoundation;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  size: 42,
                  color: foundation.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  "This page isn't available",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: foundation.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The link may be out of date.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foundation.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                PebbleButton.primary(
                  onPressed: () => GoRouter.of(context).go('/'),
                  label: 'Back to home',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
