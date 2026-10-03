import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:pebble_routines/core/config/app_runtime_config.dart';

/// Crash reporting only runs when a SENTRY_DSN dart-define is supplied at
/// build time. Local builds without a DSN never initialise Sentry at all.
const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

bool get isCrashReportingConfigured => sentryDsn.isNotEmpty;

/// Crashes only: no tracing, no replay, no screenshots, and no user identity.
/// Pebble is local-first; nothing a user typed, recorded, or photographed may
/// leave the device through a crash report. If crash reporting ever grows
/// beyond stack traces + device/OS/app-version, update LEGAL_PROCESSOR_MAP.md,
/// the privacy policy, and the Play Data safety form first.
void configureSentryOptions(
  SentryFlutterOptions options,
  AppRuntimeConfig config,
) {
  options.dsn = sentryDsn;
  options.environment = config.environment.name;
  options.sendDefaultPii = false;
  options.attachScreenshot = false;
  // attachViewHierarchy, tracing, and session replay are all off by default
  // and must stay off; see the privacy note above before changing any of them.
  options.maxBreadcrumbs = 32;
  // debugPrint output includes account and RevenueCat IDs; it must never
  // become crash breadcrumbs, or crash reports would be linked to the user.
  options.enablePrintBreadcrumbs = false;
  options.beforeSend = (event, hint) {
    event.user = null;
    event.serverName = null;
    return event;
  };
}

/// Reports an error Pebble recovered from (the app carried on). Always logged
/// locally; sent to Sentry only when crash reporting is configured, under the
/// same privacy options as crashes. [context] must be a fixed label, never
/// user content.
void reportRecoveredError(
  Object error,
  StackTrace stackTrace, {
  required String context,
}) {
  debugPrint('[$context] $error');
  if (!isCrashReportingConfigured) return;
  unawaited(
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) => scope.setTag('pebble.context', context),
    ),
  );
}
