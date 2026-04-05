import '../tutor_client/message_model.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  // Use dynamic to allow property access on web (will be null at runtime)
  late Future<dynamic> db = Future.value(null);

  void init() {}

  Future<dynamic> openDB() async => null;

  Future<void> saveMessage(ChatMessage message) async {}

  Future<void> saveMessages(List<ChatMessage> messages) async {}

  Future<void> updateMessageStatus(String id, MessageStatus status) async {}

  Stream<List<ChatMessage>> watchMessages(String threadId) async* {
    yield [];
  }

  Future<List<ChatMessage>> getMessages(String threadId,
      {int limit = 50, int offset = 0}) async => [];

  Future<void> clearHistory(String threadId) async {}

  Future<void> deleteThread(String threadId) async {}

  Future<void> deleteMessage(String messageId) async {}

  Future<int> getMessageCount(String threadId) async => 0;
}
