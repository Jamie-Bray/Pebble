import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/notifications/notification_service.dart';

NotificationAppLaunchDetails _launch({
  required bool didLaunch,
  String? payload,
}) {
  return NotificationAppLaunchDetails(
    didLaunch,
    notificationResponse: NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: payload,
    ),
  );
}

void main() {
  group('routineIdFromNotificationLaunch', () {
    test('returns the routine when a reminder tap launched the app', () {
      expect(
        routineIdFromNotificationLaunch(
          _launch(didLaunch: true, payload: '42'),
        ),
        42,
      );
    });

    test('ignores launches that did not come from a notification', () {
      expect(
        routineIdFromNotificationLaunch(
          _launch(didLaunch: false, payload: '42'),
        ),
        isNull,
      );
      expect(routineIdFromNotificationLaunch(null), isNull);
    });

    test('ignores missing or malformed payloads', () {
      expect(routineIdFromNotificationLaunch(_launch(didLaunch: true)), isNull);
      expect(
        routineIdFromNotificationLaunch(
          _launch(didLaunch: true, payload: 'not-a-routine'),
        ),
        isNull,
      );
      expect(
        routineIdFromNotificationLaunch(
          const NotificationAppLaunchDetails(true),
        ),
        isNull,
      );
    });
  });
}
