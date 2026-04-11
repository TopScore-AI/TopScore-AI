import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_io/io.dart';
import '../models/firebase_file.dart';

class StorageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _filesCollection =
      'cbc_files'; // Changed from 'resources' to a valid default

  /// Determines the Firestore collection based on curriculum.
  static String getCollectionName(String? curriculum) {
    if (curriculum == null) return 'cbc_files';
    final upper = curriculum.toUpperCase();
    if (upper.contains('IGCSE')) return 'igcse_files';
    if (upper.contains('844') || upper.contains('8.4.4') || upper.contains('KCSE')) return '844_files';
    return 'cbc_files';
  }

  // ============================================================
  // FIRESTORE-BASED METHODS (Recommended for search)
  // ============================================================

  /// Gets files uploaded by a specific user from Firestore.
  static Future<List<FirebaseFile>> getUserFiles(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_files')
          .where('userId', isEqualTo: userId)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => FirebaseFile.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching user files: $e');
      return [];
    }
  }

  /// Uploads a file to Firebase Storage and indexes it in Firestore.
  static Future<String?> uploadUserFile({
    required String userId,
    required String fileName,
    required String mimeType,
    Uint8List? bytes,
    String? filePath,
    Map<String, String>? customMetadata,
  }) async {
    try {
      // 1. Sanitize fileName
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'uploads/$userId/library/${timestamp}_$safeFileName';
      
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'userId': userId,
          'originalName': fileName,
          if (customMetadata != null) ...customMetadata,
        },
      );

      // 2. Perform Upload
      UploadTask uploadTask;
      if (kIsWeb) {
        if (bytes == null) throw Exception("Bytes required for Web upload");
        uploadTask = ref.putData(bytes, metadata);
      } else {
        if (filePath != null) {
          uploadTask = ref.putFile(File(filePath), metadata);
        } else if (bytes != null) {
          uploadTask = ref.putData(bytes, metadata);
        } else {
          throw Exception("Either filePath or bytes must be provided");
        }
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 3. Index in Firestore
      await _firestore.collection('user_files').add({
        'userId': userId,
        'name': fileName,
        'fileNameLower': fileName.toLowerCase(),
        'path': storagePath,
        'downloadUrl': downloadUrl,
        'type': fileName.split('.').last.toLowerCase(),
        'size': snapshot.totalBytes,
        'uploadedAt': FieldValue.serverTimestamp(),
        'mimeType': mimeType,
      });

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) debugPrint('Upload failed: $e');
      return null;
    }
  }


  /// Gets files from Firestore.
  static Future<List<FirebaseFile>> getAllFilesFromFirestore({
    int limit = 1000,
    int? grade,
    String? curriculum,
    String? role,
  }) async {
    try {
      List<FirebaseFile> files = [];
      // Query cbc_files first
      try {
        Query cbcQuery =
            _firestore.collection('cbc_files').orderBy('name').limit(limit);
        final cbcSnapshot = await cbcQuery.get();
        files = cbcSnapshot.docs
            .map((doc) => FirebaseFile.fromFirestore(doc))
            .toList();
      } catch (e) {
        if (kDebugMode) debugPrint('Error fetching cbc_files from Firestore: $e');
      }

      // If we haven't reached the limit, query 844_files
      if (files.length < limit) {
        try {
          int remainingLimit = limit - files.length;
          Query query844 = _firestore
              .collection('844_files')
              .orderBy('name')
              .limit(remainingLimit);
          final snapshot844 = await query844.get();
          files.addAll(snapshot844.docs
              .map((doc) => FirebaseFile.fromFirestore(doc))
              .toList());
        } catch (e) {
          if (kDebugMode) debugPrint('Error fetching 844_files from Firestore: $e');
        }
      }

      return files;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching files from Firestore: $e');
      return [];
    }
  }

  /// Paginated fetch prioritizing cbc_files then 844_files
  static Future<List<FirebaseFile>> getPaginatedFiles({
    int limit = 15,
    DocumentSnapshot? lastDocument,
    String? fileType,
    String? folder,
    int? grade,
    String? curriculum,
    String? category,
    String? pathPrefix,
    String? role, // Ignored now
    String? collectionScope, // Explicitly target 'cbc_files' or '844_files'
  }) async {
    try {
      // Determine which collection the lastDocument belongs to
      String currentCollection = 'cbc_files';
      if (collectionScope != null) {
        currentCollection = collectionScope;
      } else if (lastDocument != null) {
        final refPath = lastDocument.reference.path;
        if (refPath.contains('igcse_files')) {
          currentCollection = 'igcse_files';
        } else if (refPath.contains('844_files')) {
          currentCollection = '844_files';
        }
      }

      List<FirebaseFile> results = [];

      Query buildQuery(String collectionName) {
        Query query = _firestore.collection(collectionName);
        
        bool hasFilter = false;

        if (pathPrefix != null && pathPrefix.isNotEmpty) {
          final endPrefix = '$pathPrefix\uf8ff';
          query = query
              .where('path', isGreaterThanOrEqualTo: pathPrefix)
              .where('path', isLessThan: endPrefix);
          hasFilter = true;
        }
        if (category != null && category.isNotEmpty) {
          query = query.where('category', isEqualTo: category);
          hasFilter = true;
        }
        if (grade != null) {
          query = query.where('grade', isEqualTo: grade);
          hasFilter = true;
        }
        if (fileType != null) {
          final type =
              fileType.startsWith('.') ? fileType.substring(1) : fileType;
          query = query.where('type', isEqualTo: type.toLowerCase());
          hasFilter = true;
        }

        // To avoid mandatory composite indexes for every filter combination,
        // we only apply ordering if specific range filters aren't present,
        // or we prioritize the filtered field's order.
        if (pathPrefix != null && pathPrefix.isNotEmpty) {
          query = query.orderBy('path');
        } else if (!hasFilter) {
          // Only sort by name if we aren't filtering, to keep it simple and index-free
          query = query.orderBy('name');
        }
        
        return query;
      }

      Future<List<FirebaseFile>> fetchFromCollection(
          String name, DocumentSnapshot? cursor, int fetchLimit) async {
        try {
          Query q = buildQuery(name);
          if (cursor != null) q = q.startAfterDocument(cursor);
          final snap = await q.limit(fetchLimit).get();
          return snap.docs
              .map((doc) => FirebaseFile.fromFirestore(doc))
              .toList();
        } catch (e) {
          if (kDebugMode) debugPrint('Error fetching paginated $name: $e');
          return [];
        }
      }

      if (currentCollection == 'cbc_files') {
        results.addAll(
            await fetchFromCollection('cbc_files', lastDocument, limit));

        // If we exhausted cbc_files, seamlessly continue to 844_files then igcse_files
        if (results.length < limit && collectionScope == null) {
          results.addAll(
              await fetchFromCollection('844_files', null, limit - results.length));
        }
        if (results.length < limit && collectionScope == null) {
          results.addAll(
              await fetchFromCollection('igcse_files', null, limit - results.length));
        }
      } else if (currentCollection == '844_files') {
        results.addAll(
            await fetchFromCollection('844_files', lastDocument, limit));
        if (results.length < limit && collectionScope == null) {
          results.addAll(
              await fetchFromCollection('igcse_files', null, limit - results.length));
        }
      } else if (currentCollection == 'igcse_files') {
        results.addAll(
            await fetchFromCollection('igcse_files', lastDocument, limit));
      }

      return results;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching paginated files: $e');
      return [];
    }
  }

  /// Exhaustive search across file names, tags, and subjects.
  static Future<List<FirebaseFile>> searchFiles(
    String query, {
    int limit = 50,
    int? grade,
    String? curriculum,
    String? category,
    String? role,
    String? collectionScope,
  }) async {
    if (query.trim().isEmpty) {
      if (collectionScope != null) {
        try {
          final q = _firestore
              .collection(collectionScope)
              .orderBy('name')
              .limit(limit);
          final snap = await q.get();
          return snap.docs
              .map((doc) => FirebaseFile.fromFirestore(doc))
              .toList();
        } catch (e) {
          return [];
        }
      }
      return getAllFilesFromFirestore(limit: limit);
    }
    final searchTerm = query.toLowerCase().trim();
    final Map<String, FirebaseFile> resultsMap = {};

    Query buildBaseQuery(String collectionName) {
      Query q = _firestore.collection(collectionName);
      if (category != null && category.isNotEmpty) {
        q = q.where('category', isEqualTo: category);
      }
      return q;
    }

    Future<void> executeQueries(String collectionName) async {
      // Strategy 1: Prefix match
      try {
        final prefixQuery = buildBaseQuery(collectionName)
            .where('fileNameLower', isGreaterThanOrEqualTo: searchTerm)
            .where('fileNameLower', isLessThanOrEqualTo: '$searchTerm\uf8ff')
            .limit(limit);
        final snapshot = await prefixQuery.get();
        for (final doc in snapshot.docs) {
          resultsMap[doc.id] = FirebaseFile.fromFirestore(doc);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Search prefix query error ($collectionName): $e');
      }

      // Strategy 2: Tag-based search
      if (resultsMap.length < limit) {
        try {
          final tagQuery = buildBaseQuery(collectionName)
              .where('tags', arrayContains: searchTerm)
              .limit(limit);
          final snapshot = await tagQuery.get();
          for (final doc in snapshot.docs) {
            resultsMap.putIfAbsent(
                doc.id, () => FirebaseFile.fromFirestore(doc));
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Search tag query error ($collectionName): $e');
        }
      }

      // Strategy 3: Subject prefix match
      if (resultsMap.length < limit) {
        try {
          final subjectTerm =
              searchTerm[0].toUpperCase() + searchTerm.substring(1);
          final subjectQuery = buildBaseQuery(collectionName)
              .where('subject', isGreaterThanOrEqualTo: subjectTerm)
              .where('subject', isLessThanOrEqualTo: '$subjectTerm\uf8ff')
              .limit(limit);
          final snapshot = await subjectQuery.get();
          for (final doc in snapshot.docs) {
            resultsMap.putIfAbsent(
                doc.id, () => FirebaseFile.fromFirestore(doc));
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Search subject query error ($collectionName): $e');
        }
      }
    }

    if (collectionScope == 'cbc_files') {
      await executeQueries('cbc_files');
    } else if (collectionScope == '844_files') {
      await executeQueries('844_files');
    } else if (collectionScope == 'igcse_files') {
      await executeQueries('igcse_files');
    } else {
      await executeQueries('cbc_files');
      if (resultsMap.length < limit) {
        await executeQueries('844_files');
      }
      if (resultsMap.length < limit) {
        await executeQueries('igcse_files');
      }
    }

    // Sort results, prioritizing cbc_files
    final results = resultsMap.values.toList()
      ..sort((a, b) {
        bool aIsCbc = a.path.contains('cbc_files') ||
            a.curriculum?.toLowerCase() == 'cbc';
        bool bIsCbc = b.path.contains('cbc_files') ||
            b.curriculum?.toLowerCase() == 'cbc';
        if (aIsCbc && !bIsCbc) return -1;
        if (!aIsCbc && bIsCbc) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return results.take(limit).toList();
  }

  /// Filter files by subject and/or level (uses composite index)
  static Future<List<FirebaseFile>> filterBySubjectLevel({
    String? subject,
    String? level,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection(_filesCollection);

      if (subject != null && subject.isNotEmpty) {
        query = query.where('subject', isEqualTo: subject);
      }
      if (level != null && level.isNotEmpty) {
        query = query.where('level', isEqualTo: level);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc as DocumentSnapshot))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error filtering files: $e');
      return [];
    }
  }

  /// Search files by tag (array-contains query)
  static Future<List<FirebaseFile>> searchByTag(
    String tag, {
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_filesCollection)
          .where('tags', arrayContains: tag.toLowerCase())
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FirebaseFile.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error searching by tag: $e');
      return [];
    }
  }

  // ============================================================
  // MIGRATION SCRIPT (Run once to populate Firestore)
  // ============================================================

  /// Clears all indexed files from Firestore (from all known collections)
  static Future<void> clearAllIndexedFiles() async {
    final collections = [_filesCollection, 'cbc_files', '844_files', 'igcse_files'];

    for (final collection in collections) {
      await _clearCollection(collection);
    }
  }

  static Future<void> _clearCollection(String collectionName) async {
    try {
      if (kDebugMode) debugPrint('Starting to clear indexed files from $collectionName...');

      // Get all documents in the files collection
      final snapshot = await _firestore.collection(collectionName).get();
      final docs = snapshot.docs;

      if (kDebugMode) {
        debugPrint(
            'Found ${docs.length} indexed files to delete in $collectionName');
      }

      if (docs.isEmpty) {
        return;
      }

      // Firestore batch limit is 500 operations, use 400 to be safe
      const batchSize = 400;
      int processed = 0;

      // Process deletions in batches
      while (processed < docs.length) {
        final batch = _firestore.batch();
        final end = (processed + batchSize < docs.length)
            ? processed + batchSize
            : docs.length;

        for (int i = processed; i < end; i++) {
          batch.delete(docs[i].reference);
        }

        await batch.commit();
        processed = end;
        if (kDebugMode) {
          debugPrint(
              'Deleted batch from $collectionName: $processed/${docs.length} files');
        }
      }

      if (kDebugMode) debugPrint('Successfully cleared files from $collectionName');
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing indexed files from $collectionName: $e');
      rethrow;
    }
  }

  // Alias for user code compatibility
  static Future<void> deleteAllFileIndexes() => clearAllIndexedFiles();

  /// Migrates all files from Firebase Storage to Firestore metadata collection.
  /// Run this once via an admin button or command.
  static Future<MigrationResult> migrateStorageToFirestore({
    List<String>? allowedExtensions,
    bool forceUpdate = false,
  }) async {
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];

    try {
      // 1. Get all files from Storage
      final storageFiles = await listAllFiles();
      if (kDebugMode) debugPrint('Found ${storageFiles.length} files in Storage');

      // 2. Check existing files in Firestore to avoid duplicates

      // 3. Add each file to Firestore
      for (final file in storageFiles) {
        String? existingDocId;
        bool exists = false;

        // Extract metadata from path first to determine collection
        final metadata = FirebaseFile.extractMetadataFromPath(file.path);
        final curriculum = metadata['curriculum'];
        final collectionName = getCollectionName(curriculum);

        // Check if exists in the specific collection
        final existingQuery = await _firestore
            .collection(collectionName)
            .where('path', isEqualTo: file.path)
            .limit(1)
            .get();

        if (existingQuery.docs.isNotEmpty) {
          exists = true;
          existingDocId = existingQuery.docs.first.id;
        }

        if (exists && !forceUpdate) {
          if (kDebugMode) debugPrint('Skipping existing file: ${file.name}');
          continue;
        }

        // Apply Extension Filter
        if (allowedExtensions != null) {
          final ext = '.${file.name.split('.').last.toLowerCase()}';
          if (!allowedExtensions.contains(ext)) continue;
        }

        try {
          // Fetch High-fidelity Storage Metadata if possible (for size and downloadUrl)
          String? downloadUrl;
          int? size;
          try {
            if (file.ref != null) {
              downloadUrl = await file.ref!.getDownloadURL();
              final meta = await file.ref!.getMetadata();
              size = meta.size;
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                  'Could not fetch extra storage info for ${file.name}: $e');
            }
          }

          final Map<String, dynamic> docData = {
            'name': file.name,
            'fileNameLower': file.name.toLowerCase(),
            'path': file.path,
            'subject': metadata['subject'],
            'grade': metadata['grade'],
            'curriculum': metadata['curriculum'],
            'category': metadata['category'],
            'type': file.name.split('.').last.toLowerCase(),
            'size': size,
            'downloadUrl': downloadUrl,
            'uploadedAt': FieldValue.serverTimestamp(),
            'tags': _extractTags(
              file.name,
              metadata['subject'],
              metadata['grade']?.toString(),
              metadata['curriculum'],
              (metadata['tags'] as List<dynamic>?)?.cast<String>(),
            ),
          };

          if (exists && existingDocId != null) {
            await _firestore
                .collection(collectionName)
                .doc(existingDocId)
                .update(docData);
            if (kDebugMode) debugPrint('Updated in $collectionName: ${file.name}');
          } else {
            await _firestore.collection(collectionName).add(docData);
            if (kDebugMode) debugPrint('Migrated to $collectionName: ${file.name}');
          }
          successCount++;
        } catch (e) {
          errorCount++;
          errors.add('${file.name}: $e');
          if (kDebugMode) debugPrint('Error migrating ${file.name}: $e');
        }
      }

      return MigrationResult(
        totalFiles: storageFiles.length,
        successCount: successCount,
        errorCount: errorCount,
        errors: errors,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Migration failed: $e');
      return MigrationResult(
        totalFiles: 0,
        successCount: 0,
        errorCount: 1,
        errors: ['Migration failed: $e'],
      );
    }
  }

  /// Indexes all files under resources/IGCSE/ into the igcse_files collection.
  /// Designed for one-time use. Logs every step and the final total.
  static Future<MigrationResult> indexIGCSEFiles({
    bool forceUpdate = false,
  }) async {
    const collectionName = 'igcse_files';
    int successCount = 0;
    int errorCount = 0;
    final List<String> errors = [];

    try {
      debugPrint('[IGCSE Index] Starting — listing files under resources/IGCSE/');
      final storageFiles = await listAllFiles(path: 'resources/IGCSE');
      debugPrint('[IGCSE Index] Found ${storageFiles.length} files in Storage');

      for (int i = 0; i < storageFiles.length; i++) {
        final file = storageFiles[i];
        debugPrint('[IGCSE Index] (${i + 1}/${storageFiles.length}) Processing: ${file.path}');

        // Check for existing document
        try {
          final existingQuery = await _firestore
              .collection(collectionName)
              .where('path', isEqualTo: file.path)
              .limit(1)
              .get();

          if (existingQuery.docs.isNotEmpty && !forceUpdate) {
            debugPrint('[IGCSE Index]   Skipping (already indexed)');
            continue;
          }

          final existingDocId =
              existingQuery.docs.isNotEmpty ? existingQuery.docs.first.id : null;

          // Get download URL and size
          String? downloadUrl;
          int? size;
          try {
            if (file.ref != null) {
              downloadUrl = await file.ref!.getDownloadURL();
              final meta = await file.ref!.getMetadata();
              size = meta.size;
            }
          } catch (e) {
            debugPrint('[IGCSE Index]   Warning: could not fetch storage metadata: $e');
          }

          final metadata = FirebaseFile.extractMetadataFromPath(file.path);

          final Map<String, dynamic> docData = {
            'name': file.name,
            'fileNameLower': file.name.toLowerCase(),
            'path': file.path,
            'subject': metadata['subject'],
            'grade': metadata['grade'],
            'curriculum': 'IGCSE',
            'category': metadata['category'],
            'type': file.name.split('.').last.toLowerCase(),
            'size': size,
            'downloadUrl': downloadUrl,
            'uploadedAt': FieldValue.serverTimestamp(),
            'tags': _extractTags(
              file.name,
              metadata['subject'],
              metadata['grade']?.toString(),
              'IGCSE',
              (metadata['tags'] as List<dynamic>?)?.cast<String>(),
            ),
          };

          if (existingDocId != null) {
            await _firestore
                .collection(collectionName)
                .doc(existingDocId)
                .update(docData);
            debugPrint('[IGCSE Index]   Updated existing doc');
          } else {
            await _firestore.collection(collectionName).add(docData);
            debugPrint('[IGCSE Index]   Indexed successfully');
          }
          successCount++;
        } catch (e) {
          errorCount++;
          errors.add('${file.name}: $e');
          debugPrint('[IGCSE Index]   ERROR: $e');
        }
      }

      debugPrint('[IGCSE Index] Complete — $successCount indexed, $errorCount errors, ${storageFiles.length} total files');
      return MigrationResult(
        totalFiles: storageFiles.length,
        successCount: successCount,
        errorCount: errorCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('[IGCSE Index] Fatal error: $e');
      return MigrationResult(
        totalFiles: 0,
        successCount: 0,
        errorCount: 1,
        errors: ['IGCSE indexing failed: $e'],
      );
    }
  }

  /// Extract searchable tags from file name and metadata
  static List<String> _extractTags(
    String name,
    String? subject,
    String? level,
    String? curriculum, [
    List<String>? extraTags,
  ]) {
    final tags = <String>[];

    // Add subject, level, and curriculum as tags
    if (subject != null) tags.add(subject.toLowerCase());
    if (level != null) tags.add(level.toLowerCase());
    if (curriculum != null) tags.add(curriculum.toLowerCase());
    if (extraTags != null) {
      tags.addAll(extraTags.map((t) => t.toLowerCase()));
    }

    // Extract words from filename (excluding extension)
    final nameWithoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final words = nameWithoutExt.split(RegExp(r'[\s_\-]+'));
    for (final word in words) {
      if (word.length > 2) {
        tags.add(word.toLowerCase());
      }
    }

    return tags.toSet().toList(); // Remove duplicates
  }

  // ============================================================
  // LEGACY METHOD (Kept for fallback and migration)
  // ============================================================

  /// Recursively fetches all files from Firebase Storage (SLOW for large datasets)
  /// Use this only for migration or as fallback when Firestore is unavailable.
  static Future<List<FirebaseFile>> listAllFiles({String path = ''}) async {
    List<FirebaseFile> allFiles = [];

    final ref = FirebaseStorage.instance.ref(path);

    try {
      final result = await ref.listAll();

      // Add all files found in THIS folder
      for (final fileRef in result.items) {
        allFiles.add(FirebaseFile.fromStorageRef(fileRef));
      }

      // RECURSION: Find sub-folders and dive into them
      for (final folderRef in result.prefixes) {
        final subFolderFiles = await listAllFiles(path: folderRef.fullPath);
        allFiles.addAll(subFolderFiles);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error listing files at $path: $e");
    }

    return allFiles;
  }
}

/// Result of migration operation
class MigrationResult {
  final int totalFiles;
  final int successCount;
  final int errorCount;
  final List<String> errors;

  MigrationResult({
    required this.totalFiles,
    required this.successCount,
    required this.errorCount,
    required this.errors,
  });

  bool get isSuccess => errorCount == 0;

  @override
  String toString() =>
      'Migration: $successCount/$totalFiles succeeded, $errorCount errors';
}
