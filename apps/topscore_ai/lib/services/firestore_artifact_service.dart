import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Unified Firestore surface for user-owned artifacts (quizzes, flashcards,
/// pdf summaries, chat sessions/messages, meeting recaps).
///
/// Source of truth in Firestore. Local Isar/SharedPreferences mirror is the
/// offline-first read path; writes go to Isar synchronously and Firestore
/// fire-and-forget (the Firestore SDK retries durably while offline).
///
/// Doc IDs are deterministic (derived from the local Isar `id` as a string)
/// so re-running the migration is idempotent.
class FirestoreArtifactService {
  FirestoreArtifactService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  static const int _maxMessagePayloadBytes = 900 * 1000;

  CollectionReference<Map<String, dynamic>> _materialsCol(
      String uid, String type) {
    return _firestore.collection('users').doc(uid).collection(_collFor(type));
  }

  String _collFor(String type) {
    switch (type) {
      case 'quiz':
        return 'quizzes';
      case 'flashcard':
        return 'flashcard_sets';
      case 'summary':
      case 'pdf_summary':
        return 'pdf_summaries';
      case 'meeting_recap':
        return 'meeting_recaps';
      case 'image':
        return 'user_images';
      case 'graph':
      case 'plot':
      case 'chart':
        return 'user_graphs';
      case 'mnemonic':
        return 'user_mnemonics';
      default:
        return 'study_materials_$type';
    }
  }

  /// Upsert a study material (quiz/flashcard/pdf_summary/meeting_recap).
  /// `clientId` is the deterministic doc ID — pass the Isar row id as string.
  Future<void> upsertStudyMaterial({
    required String uid,
    required String clientId,
    required String type,
    required String topic,
    required String curriculum,
    required String grade,
    required String jsonData,
    String? title,
    int? questionCount,
    int? cardCount,
    DateTime? createdAt,
  }) async {
    final col = _materialsCol(uid, type);
    final List<String> subtypes = (type == 'summary' || type == 'pdf_summary')
        ? <String>['summary', 'pdf_summary']
        : <String>[type];

    final data = <String, dynamic>{
      'clientId': clientId,
      'type': type,
      'subtypes': subtypes,
      'topic': topic,
      'curriculum': curriculum,
      'grade': grade,
      'jsonData': jsonData,
      'title': title ?? topic,
      if (questionCount != null) 'questionCount': questionCount,
      if (cardCount != null) 'cardCount': cardCount,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };

    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      await col.doc(clientId).set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirestoreArtifactService] upsertStudyMaterial error: $e');
      }
      rethrow;
    }
  }

  /// Stream of materials for a given type, newest first.
  Stream<List<Map<String, dynamic>>> watchByType(String uid, String type) {
    Query<Map<String, dynamic>> query = _materialsCol(uid, type);
    if (type == 'summary' || type == 'pdf_summary') {
      query = query.where('subtypes', arrayContains: 'pdf_summary');
    }
    return query.orderBy('createdAt', descending: true).snapshots().map(
      (snap) {
        return snap.docs.map((d) {
          final m = d.data();
          m['_docId'] = d.id;
          return m;
        }).toList();
      },
    );
  }

  /// Stream of raw doc changes — useful when the listener needs to apply
  /// add/update/delete operations to a local Isar mirror.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchByTypeRaw(
      String uid, String type) {
    Query<Map<String, dynamic>> query = _materialsCol(uid, type);
    if (type == 'summary' || type == 'pdf_summary') {
      query = query.where('subtypes', arrayContains: 'pdf_summary');
    }
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> deleteStudyMaterial({
    required String uid,
    required String clientId,
    required String type,
  }) async {
    try {
      await _materialsCol(uid, type).doc(clientId).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirestoreArtifactService] deleteStudyMaterial error: $e');
      }
      rethrow;
    }
  }

  /// Batch-write helper used by the migration runner. Splits into sub-batches
  /// of [chunkSize] to stay safely under Firestore's 500-op cap.
  Future<void> batchUpsertMaterials({
    required String uid,
    required String type,
    required List<Map<String, dynamic>> rows,
    int chunkSize = 400,
  }) async {
    if (rows.isEmpty) return;
    final col = _materialsCol(uid, type);
    final List<String> subtypes = (type == 'summary' || type == 'pdf_summary')
        ? <String>['summary', 'pdf_summary']
        : <String>[type];

    for (var i = 0; i < rows.length; i += chunkSize) {
      final end =
          (i + chunkSize < rows.length) ? i + chunkSize : rows.length;
      final batch = _firestore.batch();
      for (var j = i; j < end; j++) {
        final row = rows[j];
        final clientId = row['clientId'] as String;
        final createdAt = row['createdAt'];
        final payload = <String, dynamic>{
          'clientId': clientId,
          'type': type,
          'subtypes': subtypes,
          'topic': row['topic'],
          'curriculum': row['curriculum'],
          'grade': row['grade'],
          'jsonData': row['jsonData'],
          'title': row['title'] ?? row['topic'],
          if (row['questionCount'] != null) 'questionCount': row['questionCount'],
          if (row['cardCount'] != null) 'cardCount': row['cardCount'],
          'updatedAt': FieldValue.serverTimestamp(),
          'schemaVersion': 1,
          'createdAt': createdAt is DateTime
              ? Timestamp.fromDate(createdAt)
              : FieldValue.serverTimestamp(),
        };
        batch.set(col.doc(clientId), payload, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  // ── Chat helpers (used by Phase C; safe to land now) ──────────────────────

  CollectionReference<Map<String, dynamic>> _threadsCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('chat_sessions');

  CollectionReference<Map<String, dynamic>> _messagesCol(
          String uid, String threadId) =>
      _threadsCol(uid).doc(threadId).collection('messages');

  Future<void> upsertChatMessage({
    required String uid,
    required String threadId,
    required String messageId,
    required Map<String, dynamic> payload,
    String? threadTitle,
    String? lastMessageText,
    bool? lastMessageIsUser,
  }) async {
    final encoded = jsonEncode(payload);
    final truncated = encoded.length > _maxMessagePayloadBytes;
    final safePayload = Map<String, dynamic>.from(payload);
    if (truncated) {
      safePayload['uiWidgetsJson'] = null;
      safePayload['payloadTruncated'] = true;
    }

    final batch = _firestore.batch();
    batch.set(
      _messagesCol(uid, threadId).doc(messageId),
      safePayload,
      SetOptions(merge: true),
    );

    final threadUpdate = <String, dynamic>{
      'lastMessageAt': FieldValue.serverTimestamp(),
      if (lastMessageText != null)
        'lastMessageText': lastMessageText.length > 200
            ? lastMessageText.substring(0, 200)
            : lastMessageText,
      if (lastMessageIsUser != null) 'lastMessageIsUser': lastMessageIsUser,
      if (threadTitle != null) 'title': threadTitle,
      'messageCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    batch.set(
      _threadsCol(uid).doc(threadId),
      threadUpdate,
      SetOptions(merge: true),
    );

    // --- ARTIFACT EXTRACTION ---
    // If the message contains a Quiz or Flashcard, also save it to the dedicated collection
    // so it appears in the User's library/history views.
    
    final commonMeta = {
      'clientId': messageId,
      'topic': threadTitle ?? lastMessageText ?? 'Chat Artifact',
      'curriculum': 'General',
      'grade': 'N/A',
      'title': threadTitle ?? lastMessageText ?? 'Chat Artifact',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'sourceThreadId': threadId,
      'schemaVersion': 1,
    };

    // Quiz
    if (payload['quizDataJson'] != null) {
      batch.set(
        _materialsCol(uid, 'quiz').doc(messageId),
        {
          ...commonMeta,
          'type': 'quiz',
          'jsonData': payload['quizDataJson'],
        },
        SetOptions(merge: true),
      );
    }

    // Flashcards
    if (payload['flashcardDataJson'] != null) {
      batch.set(
        _materialsCol(uid, 'flashcard').doc(messageId),
        {
          ...commonMeta,
          'type': 'flashcard',
          'jsonData': payload['flashcardDataJson'],
        },
        SetOptions(merge: true),
      );
    }

    // Mnemonics
    if (payload['mnemonicDataJson'] != null) {
      batch.set(
        _materialsCol(uid, 'mnemonic').doc(messageId),
        {
          ...commonMeta,
          'type': 'mnemonic',
          'jsonData': payload['mnemonicDataJson'],
        },
        SetOptions(merge: true),
      );
    }


    // Images (Direct URL)
    final imageUrl = payload['imageUrl'];
    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      batch.set(
        _materialsCol(uid, 'image').doc(messageId),
        {
          ...commonMeta,
          'type': 'image',
          'url': imageUrl,
        },
        SetOptions(merge: true),
      );
    }

    // Images (Attachments)
    final attachments = payload['attachments'] as List?;
    if (attachments != null) {
      for (var i = 0; i < attachments.length; i++) {
        final a = attachments[i];
        if (a is Map && a['type']?.toString().startsWith('image/') == true && a['url'] != null) {
          batch.set(
            _materialsCol(uid, 'image').doc('${messageId}_$i'),
            {
              ...commonMeta,
              'clientId': '${messageId}_$i',
              'type': 'image',
              'url': a['url'],
            },
            SetOptions(merge: true),
          );
        }
      }
    }

    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
      String uid, String threadId,
      {int limit = 50}) {
    return _messagesCol(uid, threadId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChatThreads(String uid) {
    return _threadsCol(uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }
}
