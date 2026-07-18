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
  options.beforeSend = (event, hint) {
    event.user = null;
    event.serverName = null;
    return event;
  };
}
