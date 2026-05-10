import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';

class NotificationProvider with ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    // On web, we don't have Isar persistence for notifications yet
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  Future<void> markAsRead(dynamic id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  Future<void> removeNotification(dynamic id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
  }
}
