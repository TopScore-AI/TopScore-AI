/// Web stub — Isar is not supported on web.
class AppNotification {
  int id = 0;
  String title = '';
  String body = '';
  String type = '';
  bool isRead = false;
  DateTime createdAt = DateTime.now();
  String? payloadJson;
}
