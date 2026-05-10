/// Web stub — push notifications and local notifications are not supported on web.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {}
  Future<String?> getToken() async => null;
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
  Future<void> requestPermissions() async {}
  Future<void> scheduleClassReminder({
    required int id,
    required String title,
    required String body,
    required String dayName,
    required String timeString,
  }) async {}
  Future<void> cancelNotification(int id) async {}

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String type = 'system',
  }) async {}

  Future<void> applyPreferences({
    required bool morningReminders,
    required bool studyReminders,
    required bool streakReminders,
    int morningHour = 16,
    int morningMinute = 0,
    int eveningHour = 19,
    int eveningMinute = 0,
  }) async {}

  Future<void> cancelAllScheduled() async {}
}
