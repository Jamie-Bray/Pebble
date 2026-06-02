import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_reminders_screen.dart';

void main() {
  group('friendlySharedReminderErrorMessage', () {
    test('hides raw function exception details for missing service config', () {
      final message = friendlySharedReminderErrorMessage(
        'FunctionException(status: 500, details: {error: Shared alert environment is not configured}, reasonPhrase: Internal Server Error)',
      );

      expect(
        message,
        'Email alerts are not ready yet. Please try again later.',
      );
      expect(message, isNot(contains('FunctionException')));
      expect(message, isNot(contains('status: 500')));
    });

    test('hides unrecognised raw function status payloads', () {
      final message = friendlySharedReminderErrorMessage(
        'FunctionException(status: 500, details: {error: Internal Server Error})',
      );

      expect(message, 'Could not update shared notification.');
      expect(message, isNot(contains('FunctionException')));
      expect(message, isNot(contains('status: 500')));
    });

    test('uses friendly copy for auth and entitlement errors', () {
      expect(
        friendlySharedReminderErrorMessage(
          'SharedReminderRepositoryException: Missing user authorization',
        ),
        'Sign in again to manage trusted contacts.',
      );
      expect(
        friendlySharedReminderErrorMessage(
          'SharedReminderRepositoryException: Personal Premium is required',
        ),
        'Premium is required for trusted contacts.',
      );
    });
  });
}
