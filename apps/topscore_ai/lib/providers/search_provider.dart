import 'package:flutter/foundation.dart';
import '../services/offline_service.dart';

class SearchProvider with ChangeNotifier {
  List<String> _history = [];
  final List<String> _popularTopics = [
    'Mathematics',
    'Physics',
    'Biology',
    'KCSE Past Papers',
    'CBC Grade 7',
    'English Grammar',
    'Geography'
  ];

  List<String> get history => _history;
  List<String> get popularTopics => _popularTopics;

  SearchProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final saved = OfflineService().getStringList('search_history');
    if (saved.isNotEmpty) {
      _history = saved;
      notifyListeners();
    }
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Remove if already exists to move to top
    _history.remove(query.trim());
    _history.insert(0, query.trim());

    // Limit to 10 items
    if (_history.length > 10) {
      _history = _history.sublist(0, 10);
    }

    await OfflineService().setStringList('search_history', _history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history = [];
    await OfflineService().remove('search_history');
    notifyListeners();
  }

  List<String> getSuggestions(String pattern) {
    if (pattern.isEmpty) return [];

    final lowerPattern = pattern.toLowerCase();

    // Combine history and popular topics for suggestions
    final combined = {..._history, ..._popularTopics};

    return combined
        .where((s) => s.toLowerCase().contains(lowerPattern))
        .take(5)
        .toList();
  }
}
