import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Reminder lead-time options users can choose from.
enum ReminderOffset {
  atTime(Duration.zero, 'At start time'),
  fiveMin(Duration(minutes: 5), '5 minutes before'),
  tenMin(Duration(minutes: 10), '10 minutes before'),
  fifteenMin(Duration(minutes: 15), '15 minutes before'),
  thirtyMin(Duration(minutes: 30), '30 minutes before'),
  oneHour(Duration(hours: 1), '1 hour before');

  final Duration duration;
  final String label;
  const ReminderOffset(this.duration, this.label);
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // Initialize Timezones for scheduling
    tz.initializeTimeZones();

    // Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Fix for iOS permissions - Defer request
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(initializationSettings);
  }

  Future<void> requestPermissions() async {
    // Request Permissions for Firebase Messaging
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Request Permissions for Local Notifications (iOS)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Schedule a weekly reminder for a class
  Future<void> scheduleClassReminder({
    required int id,
    required String title,
    required String body,
    required String dayName, // e.g., "Monday"
    required String timeString, // e.g., "08:00 AM"
    Duration reminderBefore = const Duration(minutes: 10),
  }) async {
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      // 1. Parse the Time (e.g., "08:00 AM")
      final timeParts = timeString.split(' '); // ["08:00", "AM"]
      final hm = timeParts[0].split(':');
      int hour = int.parse(hm[0]);
      int minute = int.parse(hm[1]);
      if (timeParts[1] == "PM" && hour != 12) hour += 12;
      if (timeParts[1] == "AM" && hour == 12) hour = 0;

      // 2. Find the next occurrence of the specific Day
      int targetWeekday = _getWeekdayIndex(dayName); // 1 = Mon, 7 = Sun

      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Adjust to the correct day of week
      while (scheduledDate.weekday != targetWeekday) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // If the calculated time is in the past, move to next week
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }

      // 3. Subtract reminder offset
      scheduledDate = scheduledDate.subtract(reminderBefore);

      // 4. Schedule It
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timetable_channel',
            'Timetable Reminders',
            channelDescription: 'Reminders for upcoming classes and events',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // ignore: missing_required_param
        matchDateTimeComponents:
            DateTimeComponents.dayOfWeekAndTime, // Repeats weekly
      );

      debugPrint(
        "Scheduled $title for $dayName at $timeString (Next: $scheduledDate)",
      );
    } catch (e) {
      debugPrint("Error scheduling notification: $e");
    }
  }

  /// Schedule a one-time event notification for a specific date and time.
  Future<void> scheduleEventNotification({
    required int id,
    required String title,
    required String body,
    required DateTime eventDateTime,
    Duration reminderBefore = const Duration(minutes: 10),
  }) async {
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        eventDateTime.subtract(reminderBefore),
        tz.local,
      );

      // Don't schedule if it's already in the past
      if (scheduledDate.isBefore(now)) {
        debugPrint("Event notification skipped — already in the past.");
        return;
      }

      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timetable_events_channel',
            'Timetable Events',
            channelDescription: 'Reminders for timetable events',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint("Scheduled event $title at $scheduledDate");
    } catch (e) {
      debugPrint("Error scheduling event notification: $e");
    }
  }

  /// Cancel multiple notifications by their IDs.
  Future<void> cancelNotifications(List<int> ids) async {
    for (final id in ids) {
      await _localNotifications.cancel(id);
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Check how many pending notifications are scheduled.
  Future<int> pendingNotificationCount() async {
    final pending =
        await _localNotifications.pendingNotificationRequests();
    return pending.length;
  }

  int _getWeekdayIndex(String day) {
    switch (day) {
      case 'Monday':
        return 1;
      case 'Tuesday':
        return 2;
      case 'Wednesday':
        return 3;
      case 'Thursday':
        return 4;
      case 'Friday':
        return 5;
      case 'Saturday':
        return 6;
      case 'Sunday':
        return 7;
      default:
        return 1;
    }
  }
}
