import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

void main() {
  test('a wrong or expired code gets plain wording', () {
    expect(
      friendlyAuthApiError(
        const AuthException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
      ),
      "That code didn't work. Check it, or send a new one.",
    );
  });

  test('asking for codes too often asks the person to wait', () {
    expect(
      friendlyAuthApiError(
        const AuthException(
          'For security purposes, you can only request this after 42 '
          'seconds.',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      'Please wait a minute before asking for another code.',
    );
  });

  test('a failed send says so plainly', () {
    expect(
      friendlyAuthApiError(
        const AuthException(
          'Error sending magic link email',
          statusCode: '500',
        ),
      ),
      "We couldn't send the email just now. Try again in a few minutes.",
    );
  });

  test('anything else keeps the original message', () {
    expect(
      friendlyAuthApiError(const AuthException('Signups not allowed')),
      isNull,
    );
  });
}
