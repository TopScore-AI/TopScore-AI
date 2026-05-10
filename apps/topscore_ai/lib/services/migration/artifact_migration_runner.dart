import 'package:flutter/foundation.dart';

import '../../repositories/study_repository.dart';
import '../firestore_artifact_service.dart';
import '../offline_service.dart';

/// One-time migration of locally-stored study materials into Firestore.
///
/// Markers are stored per (uid, type) under the SharedPreferences key
/// `firestore_artifact_migration_v1`. Each marker is one of:
///   - `pending`  : never started (or absent)
///   - `in_progress`: started but interrupted — safe to resume (deterministic IDs)
///   - `done`     : already completed for this user/type
///
/// Per-type algorithm:
/// 1. If marker is `done`, return.
/// 2. Set marker to `in_progress`.
/// 3. Read all local rows for that type.
/// 4. Batch-upsert in chunks of 400.
/// 5. On full success, set marker to `done`.
/// 6. On failure, leave `in_progress`; next launch resumes (idempotent).
class ArtifactMigrationRunner {
  ArtifactMigrationRunner({
    required StudyRepository repo,
    required FirestoreArtifactService firestore,
  })  : _repo = repo,
        _firestore = firestore;

  static const String _markerKey = 'firestore_artifact_migration_v1';
  static const String _statusPending = 'pending';
  static const String _statusInProgress = 'in_progress';
  static const String _statusDone = 'done';

  final StudyRepository _repo;
  final FirestoreArtifactService _firestore;

  /// Run migration for the given [types] (e.g. ['pdf_summary'] for Phase A).
  /// Returns the total number of rows successfully migrated this call.
  Future<int> runForTypes({
    required String uid,
    required List<String> types,
  }) async {
    if (uid.isEmpty) return 0;
    if (OfflineService().getLiteMode()) return 0;

    var migrated = 0;
    for (final type in types) {
      try {
        migrated += await _runOne(uid: uid, type: type);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ArtifactMigration] $type failed (will retry next launch): $e');
        }
      }
    }
    return migrated;
  }

  Future<int> _runOne({required String uid, required String type}) async {
    final status = _readStatus(uid, type);
    if (status == _statusDone) return 0;

    _writeStatus(uid, type, _statusInProgress);

    final List<Map<String, dynamic>> localRows;
    if (type == 'pdf_summary' || type == 'summary') {
      // Existing dual-save stores some rows under either alias — merge them
      // and de-dupe by `id` so we don't write the same doc twice.
      final List<Map<String, dynamic>> a =
          await _repo.getMaterialsByType('pdf_summary');
      final List<Map<String, dynamic>> b =
          await _repo.getMaterialsByType('summary');
      final Map<int, Map<String, dynamic>> byId = {};
      for (final r in [...a, ...b]) {
        final id = r['id'];
        if (id is int) byId[id] = r;
      }
      localRows = byId.values.toList();
    } else {
      localRows = await _repo.getMaterialsByType(type);
    }

    if (localRows.isEmpty) {
      await _writeStatus(uid, type, _statusDone);
      return 0;
    }

    final firestoreType =
        (type == 'summary') ? 'pdf_summary' : type;

    final rows = localRows.map((row) {
      final createdAtRaw = row['createdAt'];
      DateTime? createdAt;
      if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      } else if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      }
      return <String, dynamic>{
        'clientId': row['id'].toString(),
        'topic': row['topic'] ?? '',
        'curriculum': row['curriculum'] ?? '',
        'grade': row['grade'] ?? '',
        'jsonData': row['jsonData'] ?? '',
        'title': row['topic'] ?? '',
        'createdAt': createdAt,
      };
    }).toList();

    await _firestore.batchUpsertMaterials(
      uid: uid,
      type: firestoreType,
      rows: rows,
    );

    await _writeStatus(uid, type, _statusDone);
    return rows.length;
  }

  String _readStatus(String uid, String type) {
    final list = OfflineService().getStringList(_markerKey);
    final prefix = '$uid::$type::';
    for (final entry in list) {
      if (entry.startsWith(prefix)) {
        return entry.substring(prefix.length);
      }
    }
    return _statusPending;
  }

  Future<void> _writeStatus(String uid, String type, String status) async {
    final list = OfflineService().getStringList(_markerKey);
    final prefix = '$uid::$type::';
    final next = <String>[];
    for (final entry in list) {
      if (!entry.startsWith(prefix)) next.add(entry);
    }
    next.add('$prefix$status');
    await OfflineService().setStringList(_markerKey, next);
  }

  /// Test/debug helper: reset migration markers for a user.
  Future<void> resetMarkersForUser(String uid) async {
    final list = OfflineService().getStringList(_markerKey);
    final next =
        list.where((e) => !e.startsWith('$uid::')).toList(growable: false);
    await OfflineService().setStringList(_markerKey, next);
  }
}
