import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../tutor_client/message_model.dart';
import 'firestore_artifact_service.dart';
import 'offline_service.dart';

/// Forwards finalized [ChatMessage]s into Firestore on a fire-and-forget
/// basis. Held by [IsarService] during a signed-in session; cleared on
/// sign-out so the singleton doesn't leak the previous user's uid.
class ChatMirror {
  ChatMirror({
    required this.uid,
    required FirestoreArtifactService firestore,
  }) : _firestore = firestore;

  final String uid;
  final FirestoreArtifactService _firestore;

  void mirrorMessage(ChatMessage m) {
    if (uid.isEmpty) return;
    if (OfflineService().getLiteMode()) return;

    final threadId = m.threadId;
    if (threadId == null || threadId.isEmpty) return;

    final payload = _toPayload(m);

    unawaited(_firestore
        .upsertChatMessage(
      uid: uid,
      threadId: threadId,
      messageId: m.id,
      payload: payload,
      lastMessageText: m.text,
      lastMessageIsUser: m.isUser,
    )
        .catchError((Object e) {
      if (kDebugMode) {
        debugPrint('[ChatMirror] mirror failed for ${m.id}: $e');
      }
    }));
  }

  Map<String, dynamic> _toPayload(ChatMessage m) {
    return <String, dynamic>{
      'id': m.id,
      'text': m.text,
      'isUser': m.isUser,
      'timestamp': m.timestamp.toUtc().toIso8601String(),
      'audioUrl': m.audioUrl,
      'imageUrl': m.imageUrl,
      'feedback': m.feedback,
      'sources': m.sources
          ?.map((s) => {
                'title': s.title,
                'url': s.url,
                'author': s.author,
                'type': s.type,
              })
          .toList(),
      'reasoning': m.reasoning,
      'quizDataJson': m.quizDataJson,
      'flashcardDataJson': m.flashcardDataJson,
      'mathSteps': m.mathSteps,
      'mathAnswer': m.mathAnswer,
      'isBookmarked': m.isBookmarked,
      'videos': m.videos
          ?.map((v) => {
                'id': v.id,
                'title': v.title,
                'thumbnailUrl': v.thumbnailUrl,
                'videoUrl': v.videoUrl,
                'duration': v.duration,
                'source': v.source,
              })
          .toList(),
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
      // Convenience: pre-encoded size estimate so callers can budget retries.
      'payloadEncodedSize': jsonEncode(<String, dynamic>{
        'id': m.id,
        'text': m.text,
      }).length,
    };
  }
}
