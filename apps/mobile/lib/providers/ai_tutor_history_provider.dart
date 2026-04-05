import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_headers.dart';
import '../services/isar_service.dart';
import '../tutor_client/message_model.dart';

class AiTutorHistoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _threads = [];
  Set<String> _bookmarkedMessageIds = {};
  final Set<String> _unreadThreadIds = {};
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);
  final IsarService _isarService = IsarService();

  List<Map<String, dynamic>> get threads => _threads;
  Set<String> get bookmarkedMessageIds => _bookmarkedMessageIds;
  int get unreadCount => _unreadThreadIds.length;
  bool get isLoading => _isLoading;
  DateTime? get lastFetchTime => _lastFetchTime;

  String get _backendUrl => ApiConfig.baseUrl;

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
      final headers = await AuthHeaders.getHeaders();
      final response = await http.get(uri, headers: headers);

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
        if (kDebugMode) debugPrint('API Error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();

      // TRIGGER BACKGROUND SYNC for recent threads if they have no local messages
      if (userId != 'guest' && _threads.isNotEmpty) {
        _syncRecentThreads(userId);
      }
    }
  }

  Future<void> _syncRecentThreads(String userId) async {
    // Only sync the top 5 (most recent) threads on startup/refresh
    final topThreads = _threads.take(5).toList();
    for (var thread in topThreads) {
      final threadId = thread['thread_id'];
      if (threadId != null) {
        final count = await _isarService.getMessageCount(threadId);
        if (count == 0) {
          if (kDebugMode) debugPrint('ðŸ”„ Background Syncing thread: $threadId');
          await syncThreadMessages(threadId, userId);
        }
      }
    }
  }

  Future<void> syncThreadMessages(String threadId, String userId) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/chat/$threadId');
      final headers = await AuthHeaders.getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((m) {
          final map = m as Map<String, dynamic>;
          return ChatMessage(
            id: map['id']?.toString() ?? '',
            text: map['content']?.toString() ?? '',
            isUser: map['role'] == 'user',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              map['timestamp'] is int ? map['timestamp'] : 0,
            ),
            imageUrl: map['image_url'],
            audioUrl: map['audio_url'],
            feedback: map['feedback'],
            threadId: threadId,
            status: MessageStatus.sent,
            isTemporary: false,
            isComplete: true,
            reasoning: map['reasoning'],
            quizDataJson: map['quiz_data'] is Map ? jsonEncode(map['quiz_data']) : map['quiz_data'],
            flashcardDataJson: map['flashcards'] is Map ? jsonEncode(map['flashcards']) : map['flashcards'],
            mnemonicDataJson: map['mnemonics'] is Map ? jsonEncode(map['mnemonics']) : map['mnemonics'],
            desmosDataJson: map['desmos_data'] is Map ? jsonEncode(map['desmos_data']) : map['desmos_data'],
            graphDataJson: map['graph_data'] is Map ? jsonEncode(map['graph_data']) : map['graph_data'],
            mathSteps: map['math_steps'] is List ? List<String>.from(map['math_steps']) : null,
            mathAnswer: map['math_answer'],
            isKicdCertified: map['is_kicd_certified'] == true,
          );
        }).toList();

        await _isarService.saveMessages(messages);
        if (kDebugMode) debugPrint('âœ… Synced ${messages.length} messages for $threadId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('âŒ Sync error for $threadId: $e');
    }
  }

  /// Fetches messages from the backend and returns them directly (no Isar).
  /// Used on web where Isar is unavailable.
  Future<List<ChatMessage>> fetchThreadMessages(
      String threadId, String userId) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/chat/$threadId');
      final headers = await AuthHeaders.getHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((m) {
          final map = m as Map<String, dynamic>;
          return ChatMessage(
            id: map['id']?.toString() ?? '',
            text: map['content']?.toString() ?? '',
            isUser: map['role'] == 'user',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              map['timestamp'] is int ? map['timestamp'] : 0,
            ),
            imageUrl: map['image_url'],
            audioUrl: map['audio_url'],
            feedback: map['feedback'],
            threadId: threadId,
            status: MessageStatus.sent,
            isTemporary: false,
            isComplete: true,
            reasoning: map['reasoning'],
            quizDataJson: map['quiz_data'] is Map ? jsonEncode(map['quiz_data']) : map['quiz_data'],
            flashcardDataJson: map['flashcards'] is Map ? jsonEncode(map['flashcards']) : map['flashcards'],
            mnemonicDataJson: map['mnemonics'] is Map ? jsonEncode(map['mnemonics']) : map['mnemonics'],
            desmosDataJson: map['desmos_data'] is Map ? jsonEncode(map['desmos_data']) : map['desmos_data'],
            graphDataJson: map['graph_data'] is Map ? jsonEncode(map['graph_data']) : map['graph_data'],
            mathSteps: map['math_steps'] is List ? List<String>.from(map['math_steps']) : null,
            mathAnswer: map['math_answer'],
            isKicdCertified: map['is_kicd_certified'] == true,
          );
        }).toList();
        if (kDebugMode) debugPrint('âœ… Fetched ${messages.length} messages for $threadId');
        return messages;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('âŒ Fetch error for $threadId: $e');
    }
    return [];
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
      final headers = await AuthHeaders.getHeaders();
      final response = await http.delete(
        Uri.parse('$_backendUrl/threads/$threadId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        _threads.removeWhere((t) => t['thread_id'] == threadId);
        await _isarService.clearHistory(threadId); // Clear Local Isar
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting thread: $e');
    }
    return false;
  }

  Future<bool> deleteAllThreads(String userId) async {
    try {
      final headers = await AuthHeaders.getHeaders();
      final response = await http.delete(
        Uri.parse('$_backendUrl/api/history/$userId/clear'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        for (var t in _threads) {
          await _isarService.clearHistory(t['thread_id']);
        }
        _threads.clear();
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting all threads: $e');
    }
    return false;
  }

  void renameThread(String threadId, String newTitle) {
    final index = _threads.indexWhere((t) => t['thread_id'] == threadId);
    if (index != -1) {
      _threads[index]['title'] = newTitle;
      notifyListeners();
    }
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
