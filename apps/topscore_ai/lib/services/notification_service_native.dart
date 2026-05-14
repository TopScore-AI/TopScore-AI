import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart' show studyDb;
import '../models/app_notification_native.dart';
import '../router.dart' as app_router;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const _channelId = 'high_importance_channel';
  static const _channelName = 'TopScore Reminders';
  static const _channelDesc = 'Study reminders and important notifications';

  // Stable IDs for scheduled notifications
  static const int _morningBoostId = 100;
  static const int _eveningReminderId = 101;
  static const int _streakReminderId = 102;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) debugPrint('[NotificationService] Initializing...');
      tz_data.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _local.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create Android notification channel
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          enableLights: true,
          ledColor: Color(0xFF6366F1),
        ),
      );

      // Request permissions (Android 13+ and iOS)
      await requestPermissions();

      _isInitialized = true;
      if (kDebugMode) debugPrint('[NotificationService] Initialized successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) debugPrint('Notification tapped: ${response.payload}');
    // Scheduled-notification payloads are bare app paths ('/ai-tutor',
    // '/subscription', ...). Route via GoRouter so the user lands on the right
    // screen instead of the default home.
    final payload = response.payload?.trim();
    if (payload == null || payload.isEmpty || !payload.startsWith('/')) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        app_router.router.go(payload);
      } catch (e) {
        if (kDebugMode) debugPrint('Notification nav failed for $payload: $e');
      }
    });
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> requestPermissions() async {
    // Firebase permission (iOS/Web)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Android 13+ permission
    if (!kIsWeb) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  // ---------------------------------------------------------------------------
  // Immediate notification
  // ---------------------------------------------------------------------------
  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String type = 'system',
  }) async {
    // 1. Show the OS notification
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
          category: AndroidNotificationCategory.reminder,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );

    // 2. Persist to internal Notification Center (Isar)
    try {
      final notif = AppNotification()
        ..title = title
        ..body = body
        ..type = type
        ..createdAt = DateTime.now()
        ..payloadJson = payload;

      await studyDb.isar.writeTxn(() async {
        await studyDb.isar.appNotifications.put(notif);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed to save to Isar: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Daily scheduled notifications (local — works offline)
  // ---------------------------------------------------------------------------

  /// Schedule a daily morning boost at [hour]:[minute] Nairobi time.
  Future<void> scheduleMorningBoost({int hour = 16, int minute = 0}) async {
    await _scheduleDaily(
      id: _morningBoostId,
      title: '📚 Afternoon study time!',
      body:
          'Ready for your afternoon study session? Let\'s make progress today!',
      hour: hour,
      minute: minute,
      payload: '/ai-tutor',
    );
  }

  /// Schedule a daily evening reminder at [hour]:[minute] Nairobi time.
  Future<void> scheduleEveningReminder({int hour = 19, int minute = 0}) async {
    await _scheduleDaily(
      id: _eveningReminderId,
      title: '🌙 Evening study time!',
      body: 'Your AI tutor is ready. Let\'s crush today\'s goals 🚀',
      hour: hour,
      minute: minute,
      payload: '/ai-tutor',
    );
  }

  /// Schedule a daily streak reminder at [hour]:[minute].
  Future<void> scheduleStreakReminder({int hour = 20, int minute = 0}) async {
    await _scheduleDaily(
      id: _streakReminderId,
      title: '🔥 Don\'t break your streak!',
      body: 'You\'re on a roll — keep it going with one more session today.',
      hour: hour,
      minute: minute,
      payload: '/ai-tutor',
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final nairobi = tz.getLocation('Africa/Nairobi');
    final now = tz.TZDateTime.now(nairobi);
    var scheduled =
        tz.TZDateTime(nairobi, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _local.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_launcher',
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      payload: payload,
    );
    if (kDebugMode) {
      debugPrint('Scheduled daily notification $id at $hour:$minute Nairobi');
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel helpers & Weekly Study Reminders Scheduling
  // ---------------------------------------------------------------------------
  Future<void> cancelNotification(int id) => _local.cancel(id);
  Future<void> cancelAllScheduled() => _local.cancelAll();

  Future<void> cancelMorningBoost() => _local.cancel(_morningBoostId);
  Future<void> cancelEveningReminder() => _local.cancel(_eveningReminderId);
  Future<void> cancelStreakReminder() => _local.cancel(_streakReminderId);

  /// Cancels all day-of-week scheduled reminders (IDs 10 to 80)
  Future<void> cancelAllScheduledReminders() async {
    await _local.cancel(_morningBoostId);
    await _local.cancel(_eveningReminderId);
    await _local.cancel(_streakReminderId);
    for (int id = 10; id <= 80; id++) {
      await _local.cancel(id);
    }
  }

  /// Schedules a weekly notification on a specific day of the week and time in the user's local timezone.
  Future<void> _scheduleWeekly({
    required int id,
    required int dayOfWeek,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload = '/ai-tutor',
  }) async {
    final location = tz.local; // Ensure we schedule using local system clock so it triggers precisely at the local time
    final now = tz.TZDateTime.now(location);
    
    var scheduled = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    await _local.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_launcher',
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
    
    if (kDebugMode) {
      debugPrint('Scheduled weekly notification $id for day $dayOfWeek at $hour:$minute local');
    }
  }

  // ---------------------------------------------------------------------------
  // Apply preferences (call after user saves settings)
  // ---------------------------------------------------------------------------
  Future<void> applyPreferences({
    required bool morningReminders,
    required bool studyReminders,
    required bool streakReminders,
    int morningHour = 16,
    int morningMinute = 0,
    int eveningHour = 19,
    int eveningMinute = 0,
  }) async {
    // 1. Clear any previously scheduled reminders
    await cancelAllScheduledReminders();

    // 2. Weekend Morning Boost (Saturday & Sunday at 9:00 AM)
    if (morningReminders) {
      for (int day in [DateTime.saturday, DateTime.sunday]) {
        await _scheduleWeekly(
          id: day * 10 + 1,
          dayOfWeek: day,
          hour: 9,
          minute: 0,
          title: '☀️ Morning Study Boost',
          body: 'Start your weekend right! A morning study session keeps you ahead of the curve.',
        );
      }
    }

    // 3. Regular Study Reminders:
    //    - Weekdays: 4:00 PM (16:00) & 6:00 PM (18:00)
    //    - Weekends: 1:00 PM (13:00) & 6:00 PM (18:00)
    if (studyReminders) {
      // Weekdays
      for (int day = DateTime.monday; day <= DateTime.friday; day++) {
        await _scheduleWeekly(
          id: day * 10 + 2,
          dayOfWeek: day,
          hour: 16,
          minute: 0,
          title: '📚 Afternoon Study Time',
          body: "Ready for your afternoon study session? Let's make progress today! 🚀",
        );
        await _scheduleWeekly(
          id: day * 10 + 3,
          dayOfWeek: day,
          hour: 18,
          minute: 0,
          title: '🧠 Brain Booster Time',
          body: 'Time for a quick study sprint! Keep your knowledge fresh with your AI Tutor.',
        );
      }
      // Weekends
      for (int day in [DateTime.saturday, DateTime.sunday]) {
        await _scheduleWeekly(
          id: day * 10 + 2,
          dayOfWeek: day,
          hour: 13,
          minute: 0,
          title: '⚡ Quick Afternoon Review',
          body: "Midday check-in! Let's do a fast review to lock in what you've learned.",
        );
        await _scheduleWeekly(
          id: day * 10 + 3,
          dayOfWeek: day,
          hour: 18,
          minute: 0,
          title: '🌙 Evening study time!',
          body: 'Ready to wrap up your day? Let\'s spend a few minutes with your AI Tutor.',
        );
      }
    }

    // 4. Streak Reminders:
    //    - Weekdays: 7:30 PM (19:30)
    //    - Weekends: 8:00 PM (20:00)
    if (streakReminders) {
      // Weekdays
      for (int day = DateTime.monday; day <= DateTime.friday; day++) {
        await _scheduleWeekly(
          id: day * 10 + 4,
          dayOfWeek: day,
          hour: 19,
          minute: 30,
          title: "🔥 Don't break your streak!",
          body: 'Complete a quick review now to keep your streak alive and crush your goals!',
        );
      }
      // Weekends
      for (int day in [DateTime.saturday, DateTime.sunday]) {
        await _scheduleWeekly(
          id: day * 10 + 4,
          dayOfWeek: day,
          hour: 20,
          minute: 0,
          title: '🔥 Daily Streak Check',
          body: "Don't go to sleep without checking in! Keep your study momentum burning bright.",
        );
      }
    }
  }
}
