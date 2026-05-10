import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

class AuthIdentity {
  final String userId;
  final String? email;
  final String provider;

  const AuthIdentity({
    required this.userId,
    required this.email,
    required this.provider,
  });
}

abstract class AuthRepository {
  bool get isConfigured;
  Future<AuthIdentity?> currentIdentity();
  Future<void> requestEmailOtp(String email);
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  });
  Future<AuthIdentity> signInWithGoogle();
  Future<AuthIdentity> signInWithApple();
  Future<void> upsertProfile({required AuthIdentity identity});
  Future<void> deleteAccount();
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, this._config);

  final SupabaseClient? _client;
  final SupabaseRuntimeConfig _config;
  GoogleSignIn? _googleSignIn;

  @override
  bool get isConfigured => _client != null && _config.enabled;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null || !_config.enabled) {
      throw StateError('Sign-in is not available in this build yet.');
    }
    return client;
  }

  GoogleSignIn get _requiredGoogleSignIn {
    final webClientId = _config.googleWebClientId;
    if (webClientId == null || webClientId.isEmpty) {
      throw StateError('Google sign-in is not available in this build yet.');
    }
    return _googleSignIn ??= GoogleSignIn(
      scopes: const ['email'],
      serverClientId: webClientId,
    );
  }

  @override
  Future<AuthIdentity?> currentIdentity() async {
    final client = _client;
    if (client == null || !_config.enabled) {
      return null;
    }
    final user = client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return AuthIdentity(
      userId: user.id,
      email: user.email,
      provider: user.appMetadata['provider']?.toString() ?? 'unknown',
    );
  }

  @override
  Future<void> requestEmailOtp(String email) async {
    await _requiredClient.auth.signInWithOtp(email: email);
  }

  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final response = await _requiredClient.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    final user = response.user;
    if (user == null) {
      throw StateError('We couldn\'t complete sign-in. Please try again.');
    }
    return AuthIdentity(
      userId: user.id,
      email: user.email ?? email,
      provider: 'emailOtp',
    );
  }

  @override
  Future<AuthIdentity> signInWithGoogle() async {
    final google = _requiredGoogleSignIn;
    await google.signOut();
    final account = await google.signIn();
    if (account == null) {
      throw StateError('Google sign-in was canceled.');
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google sign-in could not be completed. Please try again.',
      );
    }

    final response = await _requiredClient.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    final user = response.user;
    if (user == null) {
      throw StateError(
        'We couldn\'t complete Google sign-in. Please try again.',
      );
    }
    return AuthIdentity(
      userId: user.id,
      email: user.email ?? account.email,
      provider: 'google',
    );
  }

  @override
  Future<AuthIdentity> signInWithApple() async {
    if (!Platform.isIOS) {
      throw StateError('Apple sign-in is available on iPhone and iPad only.');
    }

    final rawNonce = _generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
      nonce: nonce,
    );
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError(
        'Apple sign-in could not be completed. Please try again.',
      );
    }

    final response = await _requiredClient.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: identityToken,
      nonce: rawNonce,
    );
    final user = response.user;
    if (user == null) {
      throw StateError(
        'We couldn\'t complete Apple sign-in. Please try again.',
      );
    }
    return AuthIdentity(
      userId: user.id,
      email: user.email ?? credential.email,
      provider: 'apple',
    );
  }

  @override
  Future<void> upsertProfile({required AuthIdentity identity}) async {
    await _requiredClient.from('profiles').upsert({
      'id': identity.userId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _requiredClient.functions.invoke('delete-account');
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw StateError(details['error'] as String);
      }
      throw StateError(
        'We could not delete your account right now. Please try again.',
      );
    }

    try {
      final google = _googleSignIn;
      if (google != null) {
        await google.signOut();
      }
    } catch (_) {}

    try {
      await _requiredClient.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<void> signOut() async {
    try {
      final google = _googleSignIn;
      if (google != null) {
        await google.signOut();
      }
    } catch (_) {}
    await _requiredClient.auth.signOut();
  }

  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final config = ref.watch(supabaseRuntimeConfigProvider);
  return SupabaseAuthRepository(client, config);
});
