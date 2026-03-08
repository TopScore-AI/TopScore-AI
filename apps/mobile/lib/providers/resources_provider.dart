import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firebase_file.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/offline_service.dart';
import 'dart:convert';

enum ResourceState { initial, loading, loaded, error, empty }

class ResourcesProvider extends ChangeNotifier {
  final Map<String, List<FirebaseFile>> _tabCache = {};
  final Map<String, DocumentSnapshot?> _lastDocumentCache = {};
  final Map<String, bool> _hasMoreCache = {};

  ResourceState _state = ResourceState.initial;
  String _searchQuery = '';
  String _currentCategory = 'All Files';

  // Helper methodologies for translating UI tabs into query scopes
  String? _getCollectionScope(String tabName) {
    if (tabName == 'All Files') return null;
    if (tabName == '844 Files') return '844_files';
    // CBC Files, Notes, Lesson Plans, Schemes Of Work all target cbc_files
    return 'cbc_files';
  }

  String? _getPathPrefix(String tabName) {
    if (tabName == 'Notes') return 'resources/Notes/';
    if (tabName == 'Lesson Plans') return 'resources/Lesson Plans/';
    // Standardize 'Schemes of Work' / 'Schemes Of Work' edge-cases from DB paths
    if (tabName == 'Schemes Of Work' || tabName == 'Schemes of Work') {
      return 'resources/Schemes_Of_Work/';
    }

    // Everything else ('All Files', 'CBC Files', '844 Files') fetches entire collections
    return null;
  }

  // Getters
  List<FirebaseFile> get files => _tabCache[_currentCategory] ?? [];
  ResourceState get state => _state;
  bool get hasMore => _hasMoreCache[_currentCategory] ?? true;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    final trimmed = query.trim();
    if (_searchQuery == trimmed) return;
    _searchQuery = trimmed;
    // Clear cached results for all tabs so the new query fetches fresh data.
    _tabCache.clear();
    _lastDocumentCache.clear();
    _hasMoreCache.clear();
    _state = ResourceState.initial;
    notifyListeners();
  }

  void setCategory(String category) {
    if (_currentCategory == category) {
      return;
    }
    _currentCategory = category;

    // If we haven't loaded this category yet, it will be initial.
    if (!_tabCache.containsKey(_currentCategory)) {
      _state = ResourceState.initial;
    } else {
      _state = files.isEmpty ? ResourceState.empty : ResourceState.loaded;
    }
    notifyListeners();
  }

  Future<void> fetchFiles({
    required UserModel user,
    bool isRefresh = false,
  }) async {
    // Avoid multiple simultaneous loads for the same category (unless refreshing)
    if (_state == ResourceState.loading && !isRefresh) {
      return;
    }

    // If not refreshing and no more data, stop (only applies to pagination, not search)
    if (!isRefresh &&
        _hasMoreCache[_currentCategory] == false &&
        _searchQuery.isEmpty) {
      return;
    }

    if (isRefresh) {
      _tabCache.remove(_currentCategory);
      _lastDocumentCache.remove(_currentCategory);
      _hasMoreCache.remove(_currentCategory);
    }

    _state = ResourceState.loading;
    notifyListeners();

    // Snapshot the query at the start so we can detect if it changed mid-flight.
    final queryAtStart = _searchQuery;

    try {
      List<FirebaseFile> newFiles;

      if (_searchQuery.isNotEmpty) {
        // Search logic — always replaces results (no pagination)
        newFiles = await StorageService.searchFiles(
          _searchQuery,
          curriculum: user.educationLevel ?? user.curriculum,
          grade: user.grade,
          role: user.role,
          collectionScope: _getCollectionScope(_currentCategory),
        );
        _hasMoreCache[_currentCategory] = false;
      } else {
        // Pagination logic — appends to existing results
        newFiles = await StorageService.getPaginatedFiles(
          curriculum: user.educationLevel ?? user.curriculum,
          grade: user.grade,
          role: user.role,
          pathPrefix: _getPathPrefix(_currentCategory),
          collectionScope: _getCollectionScope(_currentCategory),
          lastDocument: _lastDocumentCache[_currentCategory],
          limit: 20,
        );
        _hasMoreCache[_currentCategory] = newFiles.length >= 20;
        if (newFiles.isNotEmpty) {
          _lastDocumentCache[_currentCategory] = newFiles.last.snapshot;
        }
      }

      // Discard results if the query changed while we were fetching.
      if (_searchQuery != queryAtStart) return;

      if (queryAtStart.isNotEmpty) {
        // Search: replace results entirely
        _tabCache[_currentCategory] = newFiles;
      } else {
        // Pagination: append
        _tabCache[_currentCategory] ??= [];
        _tabCache[_currentCategory]!.addAll(newFiles);
      }

      _state = (_tabCache[_currentCategory] ?? []).isEmpty
          ? ResourceState.empty
          : ResourceState.loaded;
    } catch (e) {
      _state = ResourceState.error;
      debugPrint("Error fetching files: $e");
    }
    notifyListeners();
  }

  // ==========================================
  // Recently Opened Files Tracking
  // ==========================================
  List<FirebaseFile> _recentlyOpened = [];
  List<FirebaseFile> get recentlyOpened => _recentlyOpened;
  static const String _recentFilesPrefKey = 'recently_opened_v2';
  final OfflineService _offlineService = OfflineService();

  Future<void> loadRecentlyOpened() async {
    try {
      final recentJsonList = _offlineService.getStringList(_recentFilesPrefKey);

      _recentlyOpened = recentJsonList.map((jsonStr) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return FirebaseFile.fromMap(data);
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading recently opened: $e");
    }
  }

  Future<void> trackFileOpen(FirebaseFile file) async {
    try {
      // Add to front, remove duplicates based on path
      _recentlyOpened.removeWhere((r) => r.path == file.path);
      _recentlyOpened.insert(0, file);

      // Keep only last 10
      if (_recentlyOpened.length > 10) {
        _recentlyOpened = _recentlyOpened.take(10).toList();
      }

      // Save to OfflineService (Hive)
      final jsonList =
          _recentlyOpened.map((f) => jsonEncode(f.toMap())).toList();
      await _offlineService.setStringList(_recentFilesPrefKey, jsonList);

      // Invalidate recommendations so they refresh next time
      _recommendations = [];
      _recommendationsLoaded = false;

      notifyListeners();
    } catch (e) {
      debugPrint("Error tracking file open: $e");
    }
  }

  // ==========================================
  // Recommendations Based on History
  // ==========================================
  List<FirebaseFile> _recommendations = [];
  bool _recommendationsLoaded = false;
  bool _recommendationsLoading = false;

  List<FirebaseFile> get recommendations => _recommendations;
  bool get recommendationsLoaded => _recommendationsLoaded;
  bool get recommendationsLoading => _recommendationsLoading;

  /// Build file recommendations based on the user's recently opened files.
  ///
  /// Strategy:
  /// 1. Extract subjects and categories from recently opened files
  /// 2. Query Firestore for files matching those subjects/categories
  /// 3. Exclude files the user already opened
  /// 4. Return up to [limit] recommendations
  Future<void> fetchRecommendations({
    required UserModel user,
    int limit = 6,
  }) async {
    if (_recommendationsLoading) return;
    if (_recommendationsLoaded && _recommendations.isNotEmpty) return;

    _recommendationsLoading = true;
    // Don't notify here to avoid unnecessary rebuilds during load

    try {
      final recentFiles = _recentlyOpened;
      final openedPaths = recentFiles.map((f) => f.path).toSet();

      // Extract the subjects and categories the user gravitates toward
      final subjectCounts = <String, int>{};
      final categoryCounts = <String, int>{};
      for (final file in recentFiles) {
        if (file.subject != null && file.subject!.isNotEmpty) {
          subjectCounts[file.subject!] =
              (subjectCounts[file.subject!] ?? 0) + 1;
        }
        if (file.category != null && file.category!.isNotEmpty) {
          categoryCounts[file.category!] =
              (categoryCounts[file.category!] ?? 0) + 1;
        }
      }

      // Sort by frequency — most accessed first
      final topSubjects = (subjectCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key)
          .take(3)
          .toList();

      final topCategories = (categoryCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key)
          .take(2)
          .toList();

      final List<FirebaseFile> candidates = [];
      final seenPaths = <String>{...openedPaths};

      // Fetch by top subjects
      for (final subject in topSubjects) {
        if (candidates.length >= limit * 2) break;
        final results = await StorageService.filterBySubjectLevel(
          subject: subject,
          limit: limit,
        );
        for (final f in results) {
          if (!seenPaths.contains(f.path)) {
            candidates.add(f);
            seenPaths.add(f.path);
          }
        }
      }

      // Fetch by top categories if we need more
      if (candidates.length < limit) {
        for (final category in topCategories) {
          if (candidates.length >= limit * 2) break;
          final collections = ['cbc_files', '844_files'];
          for (final col in collections) {
            try {
              final snapshot = await FirebaseFirestore.instance
                  .collection(col)
                  .where('category', isEqualTo: category)
                  .limit(limit)
                  .get();
              for (final doc in snapshot.docs) {
                final file = FirebaseFile.fromFirestore(doc);
                if (!seenPaths.contains(file.path)) {
                  candidates.add(file);
                  seenPaths.add(file.path);
                }
              }
            } catch (_) {}
          }
        }
      }

      // If still no candidates (new user with no history), fall back to
      // user's grade/curriculum
      if (candidates.isEmpty) {
        final curriculum = user.educationLevel ?? user.curriculum;
        final collectionScope =
            (curriculum?.toUpperCase().contains('844') == true ||
                    curriculum?.toUpperCase().contains('KCSE') == true)
                ? '844_files'
                : 'cbc_files';

        try {
          Query query =
              FirebaseFirestore.instance.collection(collectionScope);

          if (user.grade != null) {
            query = query.where('grade', isEqualTo: user.grade);
          }

          final snapshot = await query.limit(limit).get();
          for (final doc in snapshot.docs) {
            final file = FirebaseFile.fromFirestore(doc);
            if (!seenPaths.contains(file.path)) {
              candidates.add(file);
              seenPaths.add(file.path);
            }
          }
        } catch (e) {
          debugPrint("Error fetching fallback recommendations: $e");
        }
      }

      // Score and rank candidates
      candidates.sort((a, b) {
        int scoreA = _recommendationScore(a, topSubjects, topCategories, user);
        int scoreB = _recommendationScore(b, topSubjects, topCategories, user);
        return scoreB.compareTo(scoreA);
      });

      _recommendations = candidates.take(limit).toList();
      _recommendationsLoaded = true;
    } catch (e) {
      debugPrint("Error fetching recommendations: $e");
    } finally {
      _recommendationsLoading = false;
      notifyListeners();
    }
  }

  /// Score a file for recommendation ranking.
  /// Higher score = more relevant to the user.
  int _recommendationScore(
    FirebaseFile file,
    List<String> topSubjects,
    List<String> topCategories,
    UserModel user,
  ) {
    int score = 0;

    // Subject match (strongest signal)
    if (file.subject != null && topSubjects.contains(file.subject)) {
      score += 10 * (topSubjects.length - topSubjects.indexOf(file.subject!));
    }

    // Category match
    if (file.category != null && topCategories.contains(file.category)) {
      score += 5;
    }

    // Grade match
    if (file.grade != null && file.grade == user.grade) {
      score += 8;
    }

    // Curriculum match
    final userCurriculum =
        (user.educationLevel ?? user.curriculum)?.toUpperCase() ?? '';
    final fileCurriculum = file.curriculum?.toUpperCase() ?? '';
    if (userCurriculum.isNotEmpty &&
        fileCurriculum.isNotEmpty &&
        fileCurriculum.contains(userCurriculum)) {
      score += 4;
    }

    // User's subject list match
    if (file.subject != null && user.subjects != null) {
      if (user.subjects!
          .any((s) => s.toLowerCase() == file.subject!.toLowerCase())) {
        score += 6;
      }
    }

    return score;
  }
}
