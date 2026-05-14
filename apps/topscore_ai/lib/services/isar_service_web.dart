import '../tutor_client/message_model.dart';
import 'chat_mirror.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  // Use dynamic to allow property access on web (will be null at runtime)
  late Future<dynamic> db = Future.value(null);

  /// Set by [AuthProvider] post sign-in. Mirrors finalized messages to
  /// Firestore even though Isar isn't available on web.
  ChatMirror? mirror;

  Future<void> init() async {}

  Future<dynamic> openDB() async => null;

  Future<void> saveMessage(ChatMessage message) async {
    _maybeMirror(message);
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    for (final m in messages) {
      _maybeMirror(m);
    }
  }

  Future<void> updateMessageStatus(String id, MessageStatus status) async {}

  Stream<List<ChatMessage>> watchMessages(String threadId) async* {
    yield [];
  }

  Future<List<ChatMessage>> getMessages(String threadId,
      {int limit = 50, int offset = 0}) async =>
      [];

  Future<void> clearHistory(String threadId) async {}

  Future<void> deleteThread(String threadId) async {}

  Future<void> deleteMessage(String messageId) async {}

  Future<int> getMessageCount(String threadId) async => 0;

  Future<void> savePdfAnnotations(String docId, String json) async {}

  Future<String?> getPdfAnnotations(String docId) async => null;

  void _maybeMirror(ChatMessage m) {
    final mirror = this.mirror;
    if (mirror == null) return;
    if (m.isTemporary) return;
    if (!m.isComplete) return;
    if (m.isThinking) return;
    if (m.status == MessageStatus.error) return;
    if (m.threadId == null || m.threadId!.isEmpty) return;
    mirror.mirrorMessage(m);
  }
}
