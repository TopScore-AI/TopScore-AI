import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../tutor_client/message_model.dart';
import '../tutor_client/message_model_native.dart'; // Import native specifically to get Schema

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  late Future<Isar?> db;

  void init() {
    db = openDB();
  }

  Future<Isar?> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [ChatMessageSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Isar.getInstance()!;
  }

  Future<void> saveMessage(ChatMessage message) async {
    final isar = await db;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.chatMessages.put(message);
    });
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    final isar = await db;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.chatMessages.putAll(messages);
    });
  }

  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    final isar = await db;
    if (isar == null) return;
    final results = await isar.chatMessages.filter().idEqualTo(id).findAll();
    final message = results.isEmpty ? null : results.first;
    if (message != null) {
      final updated = message.copyWith(status: status);
      await isar.writeTxn(() async {
        await isar.chatMessages.put(updated);
      });
    }
  }

  Stream<List<ChatMessage>> watchMessages(String threadId) async* {
    final isar = await db;
    if (isar == null) {
      yield [];
      return;
    }
    yield* isar.chatMessages
        .filter()
        .threadIdEqualTo(threadId)
        .sortByTimestamp()
        .watch(fireImmediately: true);
  }

  Future<List<ChatMessage>> getMessages(String threadId,
      {int limit = 50, int offset = 0}) async {
    final isar = await db;
    if (isar == null) return [];
    return await isar.chatMessages
        .filter()
        .threadIdEqualTo(threadId)
        .sortByTimestampDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<void> clearHistory(String threadId) async {
    final isar = await db;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.chatMessages.filter().threadIdEqualTo(threadId).deleteAll();
    });
  }

  Future<void> deleteThread(String threadId) async {
    final isar = await db;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.chatMessages.filter().threadIdEqualTo(threadId).deleteAll();
    });
  }

  Future<void> deleteMessage(String messageId) async {
    final isar = await db;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.chatMessages.filter().idEqualTo(messageId).deleteAll();
    });
  }

  Future<int> getMessageCount(String threadId) async {
    final isar = await db;
    if (isar == null) return 0;
    return await isar.chatMessages.filter().threadIdEqualTo(threadId).count();
  }
}
