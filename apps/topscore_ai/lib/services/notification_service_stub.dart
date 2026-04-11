/// Web stub — push notifications and local notifications are not supported on web.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {}
  Future<String?> getToken() async => null;
  Future<void> requestPermissions() async {}
  Future<void> scheduleClassReminder({
    required int id,
    required String title,
    required String body,
    required String dayName,
    required String timeString,
  }) async {}
  Future<void> cancelNotification(int id) async {}
}
