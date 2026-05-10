import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment {
  staging,
  production;

  static AppEnvironment parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw StateError(
        'APP_ENV must be set to either "staging" or "production".',
      ),
    };
  }
}

class AppRuntimeConfig {
  const AppRuntimeConfig({
    required this.environment,
    required this.accountDeletionUrl,
  });

  final AppEnvironment environment;
  final Uri? accountDeletionUrl;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isStaging => environment == AppEnvironment.staging;
}

const String _appEnvironmentEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'staging',
);
const String _accountDeletionUrlEnv = String.fromEnvironment(
  'PEBBLE_ACCOUNT_DELETION_URL',
);

AppRuntimeConfig appRuntimeConfigFromEnvironment() {
  final environment = AppEnvironment.parse(_appEnvironmentEnv);
  final rawDeletionUrl = _accountDeletionUrlEnv.trim();
  final deletionUrl = rawDeletionUrl.isEmpty
      ? null
      : Uri.tryParse(rawDeletionUrl);

  return AppRuntimeConfig(
    environment: environment,
    accountDeletionUrl: deletionUrl,
  );
}

final appRuntimeConfigProvider = Provider<AppRuntimeConfig>((ref) {
  return appRuntimeConfigFromEnvironment();
});
