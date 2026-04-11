import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../tutor_client/message_model.dart';
import '../tutor_client/message_model_native.dart';
import '../config/database_schemas.dart';
import '../models/pdf_annotation_native.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  late Future<Isar?> db;

  Future<void> init() async {
    db = openDB();
    await db;
  }

  Future<Isar?> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        appSchemas.cast<CollectionSchema<dynamic>>(),
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

  Future<void> savePdfAnnotations(String docId, String json) async {
    final isar = await db;
    if (isar == null) return;
    await isar.writeTxn(() async {
      final record = PdfAnnotationRecord()
        ..docId = docId
        ..annotationsJson = json
        ..lastModified = DateTime.now();
      await isar.pdfAnnotationRecords.put(record);
    });
  }

  Future<String?> getPdfAnnotations(String docId) async {
    final isar = await db;
    if (isar == null) return null;
    final record = await isar.pdfAnnotationRecords.filter().docIdEqualTo(docId).findFirst();
    return record?.annotationsJson;
  }
}
