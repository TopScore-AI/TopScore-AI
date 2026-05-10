import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../firestore_artifact_service.dart';
import '../isar_service.dart';
import '../offline_service.dart';
import '../../tutor_client/message_model_native.dart';

/// One-time migration of locally-stored chat messages into Firestore.
/// 
/// Follows the same marker-based idempotent pattern as [ArtifactMigrationRunner].
class ChatMigrationRunner {
  ChatMigrationRunner({
    required IsarService isar,
    required FirestoreArtifactService firestore,
  })  : _isar = isar,
        _firestore = firestore;

  static const String _markerKey = 'firestore_chat_migration_v1';
  static const String _statusPending = 'pending';
  static const String _statusInProgress = 'in_progress';
  static const String _statusDone = 'done';

  final IsarService _isar;
  final FirestoreArtifactService _firestore;

  Future<void> run({required String uid}) async {
    if (uid.isEmpty) return;
    if (OfflineService().getLiteMode()) return;

    final status = _readStatus(uid);
    if (status == _statusDone) return;

    _writeStatus(uid, _statusInProgress);

    try {
      final isar = await _isar.db;
      if (isar == null) return;

      // 1. Fetch all local messages
      final allMessages = await isar.chatMessages.where().findAll();
      if (allMessages.isEmpty) {
        await _writeStatus(uid, _statusDone);
        return;
      }

      // 2. Group by threadId for batching (Firestore limits)
      final Map<String, List<ChatMessage>> byThread = {};
      for (final m in allMessages) {
        final tid = m.threadId;
        if (tid == null || tid.isEmpty) continue;
        byThread.putIfAbsent(tid, () => []).add(m);
      }

      // 3. Migrate each thread
      for (final tid in byThread.keys) {
        final messages = byThread[tid]!;
        // Sort by timestamp to ensure lastMessage fields in Firestore are correct
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        for (final m in messages) {
          // Skip temporary/incomplete/thinking messages
          if (m.isTemporary || !m.isComplete || m.isThinking) continue;

          // Mirror to Firestore (uses internal batching)
          await _firestore.upsertChatMessage(
            uid: uid,
            threadId: tid,
            messageId: m.id,
            payload: _toPayload(m),
            lastMessageText: m.text,
            lastMessageIsUser: m.isUser,
          );
        }
      }

      await _writeStatus(uid, _statusDone);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatMigration] Failed: $e');
      }
      // Leave as in_progress to retry next time
    }
  }

  Map<String, dynamic> _toPayload(ChatMessage m) {
    // This should match ChatMirror._toPayload logic
    return <String, dynamic>{
      'id': m.id,
      'text': m.text,
      'isUser': m.isUser,
      'timestamp': m.timestamp.toUtc().toIso8601String(),
      'audioUrl': m.audioUrl,
      'imageUrl': m.imageUrl,
      'feedback': m.feedback,
      'sources': m.sources?.map((s) => s.toJson()).toList(),
      'reasoning': m.reasoning,
      'quizDataJson': m.quizDataJson,
      'flashcardDataJson': m.flashcardDataJson,
      'mathSteps': m.mathSteps,
      'mathAnswer': m.mathAnswer,
      'isBookmarked': m.isBookmarked,
      'videos': m.videos?.map((v) => v.toJson()).toList(),
      'mnemonicDataJson': m.mnemonicDataJson,
      'punnettDataJson': m.punnettDataJson,
      'uiWidgetsJson': m.uiWidgetsJson,
      'uiWidgets': m.uiWidgets?.map((w) => w.toJson()).toList(),
      'attachments': m.attachments?.map((a) => a.toJson()).toList(),
      'replyToId': m.replyToId,
      'replyToText': m.replyToText,
      'isThought': m.isThought,
      'isKicdCertified': m.isKicdCertified,
      'isComplete': m.isComplete,
      'status': m.status.name,
      'threadId': m.threadId,
      'fileId': m.fileId,
      'fileName': m.fileName,
      'fileType': m.fileType,
    };
  }

  String _readStatus(String uid) {
    final list = OfflineService().getStringList(_markerKey);
    final prefix = '$uid::';
    for (final entry in list) {
      if (entry.startsWith(prefix)) {
        return entry.substring(prefix.length);
      }
    }
    return _statusPending;
  }

  Future<void> _writeStatus(String uid, String status) async {
    final list = OfflineService().getStringList(_markerKey);
    final prefix = '$uid::';
    final next = <String>[];
    for (final entry in list) {
      if (!entry.startsWith(prefix)) next.add(entry);
    }
    next.add('$prefix$status');
    await OfflineService().setStringList(_markerKey, next);
  }
}
