import 'package:flutter/foundation.dart';

/// Web stub — Isar is not supported on web.
class NotificationProvider with ChangeNotifier {
  List<dynamic> get notifications => const [];
  int get unreadCount => 0;

  Future<void> markAsRead(int id) async {}
  Future<void> markAllAsRead() async {}
  Future<void> removeNotification(int id) async {}
  Future<void> clearAll() async {}
}
