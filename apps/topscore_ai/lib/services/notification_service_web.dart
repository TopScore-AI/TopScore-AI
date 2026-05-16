import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web_pkg;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize({bool isBackground = false}) async {
    // We only request permissions upon explicit user interaction to respect
    // modern browser policies (especially Safari on MacOS/iOS).
    if (kDebugMode) {
      debugPrint('[NotificationService] Web initialized');
    }
  }

  Future<String?> getToken() async {
    try {
      // NOTE: For production, you should pass a vapidKey here.
      // return await _messaging.getToken(vapidKey: 'YOUR_VAPID_KEY');
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed to get token: $e');
      }
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> handleAppLaunchDetails() async {
    // No-op on Web
  }

  Future<void> requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kIsWeb) {
      web_pkg.Notification.requestPermission();
    }
  }

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String type = 'system',
  }) async {
    if (kIsWeb) {
      if (web_pkg.Notification.permission == 'granted') {
        web_pkg.Notification(
            title,
            web_pkg.NotificationOptions(
              body: body,
              icon: '/favicon.png',
            ));
      } else {
        if (kDebugMode) {
          debugPrint(
              '[NotificationService] Notification permission not granted');
        }
      }
    }
  }

  Future<void> applyPreferences({
    required bool morningReminders,
    required bool studyReminders,
    required bool streakReminders,
    int morningHour = 16,
    int morningMinute = 0,
    int eveningHour = 19,
    int eveningMinute = 0,
  }) async {
    // Scheduled notifications are not supported on standard Web without a Service Worker
    // and complex setup. We skip local scheduling on Web for now.
  }

  Future<void> cancelAllScheduled() async {
    // No-op on Web
  }

  Future<void> cancelNotification(int id) async {
    // No-op on Web
  }
}
