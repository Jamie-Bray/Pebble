import 'package:go_router/go_router.dart';

/// The path of the screen on top right now, including pushed routes (the
/// player is usually pushed over Home, which `currentConfiguration.uri`
/// alone doesn't show).
String currentRouterPath(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  if (config.matches.isNotEmpty) {
    final last = config.matches.last;
    if (last is ImperativeRouteMatch) return last.matches.uri.path;
  }
  return config.uri.path;
}

/// Opens the player for [routineId] after a widget or notification tap.
///
/// When that routine's player is already on screen (for example its
/// completion screen is still showing), going to the same location would
/// keep the finished session, so [refreshSession] asks for the session
/// again instead: a finished run then starts fresh, and a run in progress
/// simply resumes.
void openRoutineFromExternalLaunch(
  GoRouter router, {
  required int routineId,
  required void Function() refreshSession,
}) {
  final target = '/play/$routineId';
  if (currentRouterPath(router) == target) {
    refreshSession();
    return;
  }
  router.go(target);
}
