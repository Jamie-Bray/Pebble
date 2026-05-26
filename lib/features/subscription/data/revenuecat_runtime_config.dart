import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RevenueCatRuntimeConfig {
  const RevenueCatRuntimeConfig({
    required this.androidApiKey,
    required this.iosApiKey,
    this.entitlementId = 'personal_premium',
  });

  const RevenueCatRuntimeConfig.disabled()
    : androidApiKey = '',
      iosApiKey = '',
      entitlementId = 'personal_premium';

  final String androidApiKey;
  final String iosApiKey;
  final String entitlementId;

  bool get hasAnyApiKey => androidApiKey.isNotEmpty || iosApiKey.isNotEmpty;

  String? get apiKeyForCurrentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => androidApiKey.isEmpty ? null : androidApiKey,
      TargetPlatform.iOS => iosApiKey.isEmpty ? null : iosApiKey,
      _ => null,
    };
  }

  bool get supportsCurrentPlatform => apiKeyForCurrentPlatform != null;
}

final revenueCatRuntimeConfigProvider = Provider<RevenueCatRuntimeConfig>((
  ref,
) {
  return const RevenueCatRuntimeConfig.disabled();
});
