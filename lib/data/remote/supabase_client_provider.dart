import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRuntimeConfig {
  final bool enabled;
  final String url;
  final String anonKey;
  final String? googleWebClientId;

  /// iOS OAuth client ID. iOS Google Sign-In needs its own client in addition
  /// to the web (server) client; its reversed form must also be registered as
  /// a URL scheme (see ios/Flutter/GoogleSignIn.xcconfig.example).
  final String? googleIosClientId;

  const SupabaseRuntimeConfig({
    required this.enabled,
    required this.url,
    required this.anonKey,
    this.googleWebClientId,
    this.googleIosClientId,
  });

  const SupabaseRuntimeConfig.disabled()
    : enabled = false,
      url = '',
      anonKey = '',
      googleWebClientId = null,
      googleIosClientId = null;

  /// Whether Google sign-in is fully configured for the running platform, so
  /// the button is never offered when tapping it could only fail.
  bool get supportsGoogleSignIn {
    if (googleWebClientId?.isNotEmpty != true) return false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return googleIosClientId?.isNotEmpty == true;
    }
    return true;
  }
}

final supabaseRuntimeConfigProvider = Provider<SupabaseRuntimeConfig>((ref) {
  return const SupabaseRuntimeConfig.disabled();
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final config = ref.watch(supabaseRuntimeConfigProvider);
  if (!config.enabled) {
    return null;
  }
  return Supabase.instance.client;
});
