import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiTutorHistoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _threads = [];
  Set<String> _bookmarkedMessageIds = {};
  final Set<String> _unreadThreadIds = {};
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  List<Map<String, dynamic>> get threads => _threads;
  Set<String> get bookmarkedMessageIds => _bookmarkedMessageIds;
  int get unreadCount => _unreadThreadIds.length;
  bool get isLoading => _isLoading;
  DateTime? get lastFetchTime => _lastFetchTime;

  String get _backendUrl {
    if (kIsWeb) {
      return 'https://agent.topscoreapp.ai';
    }
    if (Platform.isAndroid) {
      return 'https://agent.topscoreapp.ai';
    }
    return 'https://agent.topscoreapp.ai';
  }

  Future<void> fetchHistory(
    String userId, {
    bool forceRefresh = false,
    int? limit,
  }) async {
    if (!forceRefresh &&
        _threads.isNotEmpty &&
        limit == null && // Don't skip if we're doing a specific limit fetch
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    if (userId == 'guest') {
      _threads = [];
      notifyListeners();
      return;
    }

    // Only set loading if it's the first fetch or a force refresh
    if (_threads.isEmpty || forceRefresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final uri = Uri.parse('$_backendUrl/api/history/$userId').replace(
        queryParameters: limit != null ? {'limit': limit.toString()} : null,
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newThreads = data.map((item) {
          return {
            'thread_id': item['thread_id'],
            'title': item['title'],
            'updated_at': item['updated_at'],
            'model': item['model'],
          };
        }).toList();

        if (limit != null) {
          // If it's a limited fetch, we merge or replace
          // For initial fast load, we replace if empty, or merge carefully
          if (_threads.isEmpty) {
            _threads = newThreads;
          } else {
            // Merge logic: add only if doesn't exist
            for (var thread in newThreads) {
              if (!_threads.any((t) => t['thread_id'] == thread['thread_id'])) {
                _threads.add(thread);
              }
            }
          }
        } else {
          // Full fetch: replace
          _threads = newThreads;
          _lastFetchTime = DateTime.now();
        }

        _sortThreads();
      } else {
        debugPrint('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortThreads() {
    _threads.sort((a, b) {
      final aTime = a['updated_at'] ?? 0;
      final bTime = b['updated_at'] ?? 0;
      if (aTime is int && bTime is int) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });
  }

  void addThread(Map<String, dynamic> thread) {
    // Check if exists
    final index = _threads.indexWhere(
      (t) => t['thread_id'] == thread['thread_id'],
    );
    if (index != -1) {
      _threads[index] = thread;
    } else {
      _threads.add(thread);
    }
    _sortThreads();
    notifyListeners();
  }

  Future<bool> deleteThread(String userId, String threadId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_backendUrl/threads/$threadId'),
      );

      if (response.statusCode == 200) {
        _threads.removeWhere((t) => t['thread_id'] == threadId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting thread: $e');
    }
    return false;
  }

  Future<bool> deleteAllThreads(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_backendUrl/api/history/$userId/clear'),
      );

      if (response.statusCode == 200) {
        _threads.clear();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting all threads: $e');
    }
    return false;
  }

  void setBookmarks(Set<String> ids) {
    _bookmarkedMessageIds = ids;
    notifyListeners();
  }

  void toggleBookmark(String messageId, bool isBookmarked) {
    if (isBookmarked) {
      _bookmarkedMessageIds.add(messageId);
    } else {
      _bookmarkedMessageIds.remove(messageId);
    }
    notifyListeners();
  }

  void markAsRead(String threadId) {
    if (_unreadThreadIds.remove(threadId)) {
      notifyListeners();
    }
  }

  void markAllAsRead() {
    if (_unreadThreadIds.isNotEmpty) {
      _unreadThreadIds.clear();
      notifyListeners();
    }
  }

  void addUnreadThread(String threadId) {
    _unreadThreadIds.add(threadId);
    notifyListeners();
  }
}
