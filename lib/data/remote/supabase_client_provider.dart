import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRuntimeConfig {
  final bool enabled;
  final String url;
  final String anonKey;
  final String? googleWebClientId;

  const SupabaseRuntimeConfig({
    required this.enabled,
    required this.url,
    required this.anonKey,
    this.googleWebClientId,
  });

  const SupabaseRuntimeConfig.disabled()
    : enabled = false,
      url = '',
      anonKey = '',
      googleWebClientId = null;
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
