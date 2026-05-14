import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import '../models/app_notification_native.dart';
import '../main.dart' show studyDb;

class NotificationProvider with ChangeNotifier {
  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _listenToNotifications();
  }

  void _listenToNotifications() {
    try {
      studyDb.isar.appNotifications
          .where()
          .sortByCreatedAtDesc()
          .watch(fireImmediately: true)
          .listen((notifications) {
        _notifications = notifications;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[NotificationProvider] Failed to listen: $e');
    }
  }

  Future<void> markAsRead(Id id) async {
    final notif = await studyDb.isar.appNotifications.get(id);
    if (notif != null && !notif.isRead) {
      notif.isRead = true;
      await studyDb.isar.writeTxn(() async {
        await studyDb.isar.appNotifications.put(notif);
      });
    }
  }

  Future<void> markAllAsRead() async {
    final unread = await studyDb.isar.appNotifications
        .filter()
        .isReadEqualTo(false)
        .findAll();
    if (unread.isEmpty) return;
    await studyDb.isar.writeTxn(() async {
      for (var n in unread) {
        n.isRead = true;
        await studyDb.isar.appNotifications.put(n);
      }
    });
  }

  Future<void> removeNotification(Id id) async {
    await studyDb.isar.writeTxn(() async {
      await studyDb.isar.appNotifications.delete(id);
    });
  }

  Future<void> clearAll() async {
    await studyDb.isar.writeTxn(() async {
      await studyDb.isar.appNotifications.clear();
    });
  }
}
