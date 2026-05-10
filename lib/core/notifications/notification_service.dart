import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:pebble_routines/core/database/local_db.dart';

/// A singleton service for managing routine reminder notifications.
///
/// Handles timezone detection, permission requests, and scheduling
/// of recurring weekly notifications for routine reminders.
class NotificationService {
  static const String _androidChannelId = 'pebble_reminders_v2';
  static const String _androidChannelName = 'Pebble Reminders';
  static const String _androidChannelDescription =
      'Routine reminder notifications';

  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<int> _selectedRoutineController =
      StreamController<int>.broadcast();

  /// Stream that emits routine IDs when notification is tapped
  Stream<int> get selectedRoutineIdStream => _selectedRoutineController.stream;

  /// Initializes the notification service with timezone detection and permissions
  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final id = int.tryParse(payload);
        if (id != null) _selectedRoutineController.add(id);
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Requests notification permission from the user
  ///
  /// Returns `true` if permission is granted, `false` otherwise
  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  /// Backward-compatible alias used by some settings code paths.
  Future<bool> requestPermissions() => requestNotificationPermission();

  Future<bool> requestNotificationPermission() async {
    if (await hasNotificationPermission()) return true;

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidImpl?.requestNotificationsPermission();
      if (granted == true) return true;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final macImpl = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted =
          await iosImpl?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      final macGranted =
          await macImpl?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      if (iosGranted || macGranted) return true;
    }

    final result = await Permission.notification.request();
    return result.isGranted || result.isLimited || result.isProvisional;
  }

  /// Schedules a recurring weekly reminder for a routine
  ///
  /// [routineId] - Unique identifier for the routine
  /// [title] - Display name of the routine
  /// [dayOfWeek] - Day of week (1=Monday, 7=Sunday)
  /// [time] - Time of day for the reminder
  ///
  /// Throws [Exception] if notification permission is denied
  Future<void> scheduleRoutineReminder({
    required int routineId,
    required String title,
    required int dayOfWeek, // 1=Monday ... 7=Sunday
    required TimeOfDay time,
    int? reminderId,
    bool requestPermissionIfNeeded = true,
  }) async {
    // Ensure notification permission is granted
    final hasPermission = requestPermissionIfNeeded
        ? await requestNotificationPermission()
        : await hasNotificationPermission();
    if (!hasPermission) {
      throw Exception(
        'Notification permission denied. Please enable notifications in app settings.',
      );
    }

    // Ensure timezone is correctly set
    if (tz.local.name == 'UTC') {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    }

    final tz.TZDateTime scheduled = _nextInstanceOfWeekday(dayOfWeek, time);
    final notificationId = _notificationIdFor(
      routineId: routineId,
      reminderId: reminderId,
    );

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _zonedSchedule(
      notificationId: notificationId,
      title: "Time for your '$title' routine",
      body: 'Tap to start',
      scheduled: scheduled,
      details: details,
      payload: routineId.toString(),
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels a scheduled routine reminder
  ///
  /// [routineId] - Unique identifier for the routine to cancel
  /// [reminderId] - Optional reminder row ID for multi-reminder schedules
  Future<void> cancelRoutineReminder(int routineId, {int? reminderId}) async {
    final notificationId = _notificationIdFor(
      routineId: routineId,
      reminderId: reminderId,
    );
    await _plugin.cancel(notificationId);
  }

  /// Cancels ALL notifications scheduled by this app
  Future<void> cancelAllScheduledNotifications() async {
    await _plugin.cancelAll();
  }

  /// Cancels all notifications for a specific routine
  Future<void> cancelAllNotificationsForRoutine(
    int routineId,
    List<RoutineReminder> reminders,
  ) async {
    for (final reminder in reminders) {
      await cancelRoutineReminder(routineId, reminderId: reminder.id);
    }
  }

  int _notificationIdFor({required int routineId, int? reminderId}) {
    // Keep IDs deterministic across app restarts.
    // Bit 30 marks "multi-reminder row IDs" to avoid collisions with legacy
    // routine-level IDs.
    if (reminderId != null) {
      return ((1 << 30) | (reminderId & 0x3FFFFFFF)) & 0x7FFFFFFF;
    }
    return routineId & 0x3FFFFFFF;
  }

  Future<void> _zonedSchedule({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required NotificationDetails details,
    required String payload,
    required AndroidScheduleMode scheduleMode,
  }) {
    return _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduled,
      details,
      payload: payload,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Calculates the next occurrence of a weekday at the specified time
  ///
  /// [weekday] - Day of week (1=Monday, 7=Sunday)
  /// [time] - Time of day for the reminder
  ///
  /// Returns the next scheduled time for the reminder
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, start from tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Find the next occurrence of the specified weekday
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
