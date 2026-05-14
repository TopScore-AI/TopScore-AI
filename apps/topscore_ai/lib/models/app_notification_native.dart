import 'package:isar_community/isar.dart';

part 'app_notification_native.g.dart';

@collection
class AppNotification {
  Id id = Isar.autoIncrement;

  late String title;
  late String body;
  late String type; // e.g., 'system', 'summary_ready', 'reminder'

  @Index()
  bool isRead = false;

  @Index()
  late DateTime createdAt;

  String? payloadJson; // Hidden routing data
}
