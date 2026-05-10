import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

import '../services/firestore_artifact_service.dart';
import '../services/offline_service.dart';
import 'study_change_stream.dart';
import 'study_repository.dart';

/// Decorator that mirrors local study materials to Firestore.
///
/// - Reads still go to the underlying [StudyRepository] (Isar on native,
///   SharedPreferences on web) — always fast, always offline-first.
/// - Writes go to local first (synchronous), then a fire-and-forget Firestore
///   upsert. The Firestore SDK retries durably while offline.
/// - A separate listener writes incoming Firestore docs back into the local
///   repo. Use [attachListenerForType] / [detachListeners] from auth lifecycle.
class SyncedStudyRepository implements StudyRepository {
  SyncedStudyRepository({
    required StudyRepository inner,
    required FirestoreArtifactService firestore,
  })  : _inner = inner,
        _firestore = firestore;

  final StudyRepository _inner;
  final FirestoreArtifactService _firestore;

  String? _activeUid;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _typeListeners = {};

  @override
  Isar get isar => _inner.isar;

  StudyRepository get inner => _inner;
  FirestoreArtifactService get firestoreService => _firestore;

  @override
  Future<void> saveMaterial({
    required String type,
    required String topic,
    required String curriculum,
    required String grade,
    required String jsonData,
  }) async {
    await _inner.saveMaterial(
      type: type,
      topic: topic,
      curriculum: curriculum,
      grade: grade,
      jsonData: jsonData,
    );

    final uid = _activeUid;
    if (uid == null) return;
    if (OfflineService().getLiteMode()) return;

    // Look up the row we just wrote to recover its local id (clientId).
    try {
      final row = await _inner.getMaterialByTopic(type, topic);
      if (row == null) return;
      final clientId = row['id'].toString();
      final createdAtRaw = row['createdAt'];
      DateTime? createdAt;
      if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      } else if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      }

      // Fire-and-forget. Errors are logged but don't break the local save.
      unawaited(_firestore
          .upsertStudyMaterial(
            uid: uid,
            clientId: clientId,
            type: type,
            topic: topic,
            curriculum: curriculum,
            grade: grade,
            jsonData: jsonData,
            createdAt: createdAt,
          )
          .catchError((Object e) {
        if (kDebugMode) {
          debugPrint('[SyncedStudyRepository] mirror upsert failed: $e');
        }
      }));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncedStudyRepository] saveMaterial mirror error: $e');
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMaterialsByType(String type) =>
      _inner.getMaterialsByType(type);

  @override
  Future<Map<String, dynamic>?> getMaterialByTopic(String type, String topic) =>
      _inner.getMaterialByTopic(type, topic);

  @override
  Future<int> deleteMaterial(int id) async {
    // Capture row before delete so we know which Firestore doc to remove.
    Map<String, dynamic>? snapshot;
    try {
      snapshot = await _findById(id);
    } catch (_) {}

    final result = await _inner.deleteMaterial(id);

    final uid = _activeUid;
    if (uid != null && snapshot != null) {
      final type = snapshot['type'] as String? ?? _typeFromSnapshot(snapshot);
      if (type != null) {
        unawaited(_firestore
            .deleteStudyMaterial(
              uid: uid,
              clientId: id.toString(),
              type: type,
            )
            .catchError((Object e) {
          if (kDebugMode) {
            debugPrint('[SyncedStudyRepository] mirror delete failed: $e');
          }
        }));
      }
    }
    return result;
  }

  /// Best-effort lookup of a row by id across known types. Returns null if
  /// the underlying repo doesn't expose this efficiently.
  Future<Map<String, dynamic>?> _findById(int id) async {
    for (final t in const ['quiz', 'flashcard', 'summary', 'pdf_summary']) {
      final list = await _inner.getMaterialsByType(t);
      for (final m in list) {
        if (m['id'] == id) {
          return {...m, 'type': t};
        }
      }
    }
    return null;
  }

  String? _typeFromSnapshot(Map<String, dynamic> snap) =>
      snap['type'] as String?;

  /// Watch local materials of [type] as a reactive stream.
  Stream<List<Map<String, dynamic>>> watchMaterialsByType(String type) async* {
    yield await _inner.getMaterialsByType(type);

    if (kIsWeb) {
      return;
    }

    try {
      yield* watchStudyChanges(_inner)
          .asyncMap((_) => _inner.getMaterialsByType(type));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncedStudyRepository] watch fallback (no isar): $e');
      }
    }
  }

  // ── Listener lifecycle ────────────────────────────────────────────────────

  void setActiveUser(String? uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    if (uid == null) {
      detachListeners();
    }
  }

  /// Attach a Firestore listener for [type]. Incoming docs are merged into
  /// the local repo via [saveMaterial]/[deleteMaterial]. Last-write-wins:
  /// only overwrites the local row if the Firestore doc is newer.
  Future<void> attachListenerForType(String type) async {
    final uid = _activeUid;
    if (uid == null) return;
    if (OfflineService().getLiteMode()) return;
    if (_typeListeners.containsKey(type)) return;

    final sub = _firestore.watchByTypeRaw(uid, type).listen((snap) async {
      for (final change in snap.docChanges) {
        try {
          if (change.type == DocumentChangeType.removed) {
            final id = int.tryParse(change.doc.id);
            if (id != null) {
              await _inner.deleteMaterial(id);
            }
            continue;
          }
          final data = change.doc.data();
          if (data == null) continue;

          final topic = data['topic'] as String? ?? '';
          if (topic.isEmpty) continue;

          final existing = await _inner.getMaterialByTopic(type, topic);
          // Conflict resolution: only overwrite if remote is newer.
          if (existing != null) {
            final remoteUpdated = data['updatedAt'];
            DateTime? remoteTs;
            if (remoteUpdated is Timestamp) {
              remoteTs = remoteUpdated.toDate();
            }
            final localTsRaw = existing['createdAt'];
            DateTime? localTs;
            if (localTsRaw is String) {
              localTs = DateTime.tryParse(localTsRaw);
            }
            if (remoteTs != null &&
                localTs != null &&
                !remoteTs.isAfter(localTs)) {
              continue;
            }
          }

          await _inner.saveMaterial(
            type: type,
            topic: topic,
            curriculum: data['curriculum'] as String? ?? '',
            grade: data['grade'] as String? ?? '',
            jsonData: data['jsonData'] as String? ?? '',
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '[SyncedStudyRepository] listener apply error ($type): $e');
          }
        }
      }
    }, onError: (Object e) {
      if (kDebugMode) {
        debugPrint('[SyncedStudyRepository] listener error ($type): $e');
      }
    });

    _typeListeners[type] = sub;
  }

  void detachListeners() {
    for (final sub in _typeListeners.values) {
      sub.cancel();
    }
    _typeListeners.clear();
  }
}
