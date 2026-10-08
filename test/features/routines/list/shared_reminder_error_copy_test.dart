import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_reminders_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('friendlySharedReminderErrorMessage', () {
    test('hides raw function exception details for missing service config', () {
      final message = friendlySharedReminderErrorMessage(
        'FunctionException(status: 500, details: {error: Shared alert environment is not configured}, reasonPhrase: Internal Server Error)',
      );

      expect(
        message,
        "Completion emails aren't available right now. Try again later.",
      );
      expect(message, isNot(contains('FunctionException')));
      expect(message, isNot(contains('status: 500')));
    });

    test('hides unrecognised raw function status payloads', () {
      final message = friendlySharedReminderErrorMessage(
        'FunctionException(status: 500, details: {error: Internal Server Error})',
      );

      expect(message, "Couldn't update completion emails. Try again.");
      expect(message, isNot(contains('FunctionException')));
      expect(message, isNot(contains('status: 500')));
    });

    test('uses friendly copy for auth and entitlement errors', () {
      expect(
        friendlySharedReminderErrorMessage(
          'SharedReminderRepositoryException: Missing user authorization',
        ),
        'Sign in again to manage who gets notified.',
      );
      expect(
        friendlySharedReminderErrorMessage(
          'SharedReminderRepositoryException: Personal Premium is required',
        ),
        'Premium is required to notify someone.',
      );
    });

    test('shows the server message for limits instead of a generic error', () {
      final error = sharedReminderExceptionFromFunctionError(
        const FunctionException(
          status: 429,
          details: {
            'error': 'Too many invites today. Please try again tomorrow.',
            'code': 'senderDailyLimit',
          },
        ),
      );
      expect(error.code, 'senderDailyLimit');
      expect(error.status, 429);
      expect(
        friendlySharedReminderErrorMessage(error),
        'Too many invites today. Please try again tomorrow.',
      );
    });

    test('blocked recipients get calm wording', () {
      final error = sharedReminderExceptionFromFunctionError(
        const FunctionException(
          status: 403,
          details: {
            'error': 'This recipient has blocked invites from this account',
          },
        ),
      );
      expect(
        friendlySharedReminderErrorMessage(error),
        "This address isn't accepting invitations from you.",
      );
    });

    test('never shows provider JSON', () {
      expect(
        friendlySharedReminderErrorMessage(
          SharedReminderRepositoryException('{"statusCode":422,"name":"x"}'),
        ),
        "Couldn't update completion emails. Try again.",
      );
      final noDetails = sharedReminderExceptionFromFunctionError(
        const FunctionException(status: 502, details: 'Bad gateway'),
      );
      expect(
        noDetails.message,
        "Completion emails aren't available right now. Try again later.",
      );
    });
  });

  group('completion email request and result', () {
    test('sends UTC time plus the device offset', () {
      final local = DateTime(2026, 10, 3, 22, 41);
      final body = completionRequestBody(
        routineKey: 'local:1',
        routineTitle: 'Lock up',
        runId: 'run-1',
        sessionId: 's-1',
        completedAt: local,
        completedSteps: 4,
        totalSteps: 4,
      );
      final sentAt = DateTime.parse(body['completedAt'] as String);
      expect((body['completedAt'] as String).endsWith('Z'), isTrue);
      expect(sentAt.isAtSameMomentAs(local), isTrue);
      expect(body['utcOffsetMinutes'], local.timeZoneOffset.inMinutes);
    });

    test('lists checked and skipped steps in order, never pending ones', () {
      final checkedAt = DateTime.utc(2026, 10, 3, 21, 38);
      final session = RoutineSession.fromJson({
        'sessionId': 's-1',
        'routineId': 1,
        'routineTitleSnapshot': 'Lock up',
        'status': 'completed',
        'totalStepCount': 3,
        'routineSnapshotSteps': [
          {'runtimeType': 'check', 'label': 'Front door'},
          {'runtimeType': 'check', 'label': 'Hob off'},
          {'runtimeType': 'timer', 'duration': 30},
        ],
        'stepStates': [
          {
            'stepIndex': 0,
            'status': 'completed',
            'completedAt': checkedAt.toIso8601String(),
          },
          {'stepIndex': 1, 'status': 'skipped'},
          {'stepIndex': 2, 'status': 'pending'},
        ],
      });
      final steps = completionEmailSteps(session);
      expect(steps.map((s) => s.title), ['Front door', 'Hob off']);
      final body = completionRequestBody(
        routineKey: 'local:1',
        routineTitle: 'Lock up',
        runId: 'run-1',
        sessionId: 's-1',
        completedAt: checkedAt,
        completedSteps: 1,
        totalSteps: 3,
        steps: steps,
      );
      expect(body['steps'], [
        {
          'title': 'Front door',
          'status': 'done',
          'completedAt': '2026-10-03T21:38:00.000Z',
        },
        {'title': 'Hob off', 'status': 'skipped'},
      ]);
      expect(
        completionRequestBody(
          routineKey: 'local:1',
          routineTitle: 'Lock up',
          runId: 'run-1',
          sessionId: 's-1',
          completedAt: checkedAt,
          completedSteps: 0,
          totalSteps: 0,
        ).containsKey('steps'),
        isFalse,
      );
    });

    test(
      'completion screen note says what happened, and nothing otherwise',
      () {
        expect(
          SharedReminderCompletionResult.fromJson(const {
            'sent': true,
            'recipientEmail': 'sam@example.com',
          }).completionScreenNote,
          'Completion email sent to sam@example.com.',
        );
        expect(
          SharedReminderCompletionResult.fromJson(const {
            'sent': true,
            'alreadySent': true,
          }).completionScreenNote,
          isNull,
        );
        expect(
          SharedReminderCompletionResult.fromJson(const {
            'sent': false,
            'reason': 'noAcceptedContact',
          }).completionScreenNote,
          isNull,
        );
        expect(
          SharedReminderCompletionResult.fromJson(const {
            'sent': false,
            'reason': 'rateLimited',
          }).completionScreenNote,
          contains('not sent'),
        );
        expect(
          const SharedReminderCompletionResult(
            sent: false,
            reason: 'offline',
          ).completionScreenNote,
          "Completion email not sent because there's no connection.",
        );
      },
    );
  });
}
