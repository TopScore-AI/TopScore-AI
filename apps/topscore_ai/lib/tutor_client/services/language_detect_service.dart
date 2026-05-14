import 'dart:async';

import '../../services/ai_service.dart';

/// Debounced wrapper around POST /api/language/detect with in-memory LRU.
///
/// Used by ChatController on outbound messages to suggest learning a detected
/// non-English language via the Buddy banner. Designed to be cheap and quiet:
/// - 300ms debounce so rapid typing only fires one request
/// - LRU keyed by text hash so repeat sends return cached results
/// - Best-effort error swallowing: detection is purely additive UX
class LanguageDetectService {
  LanguageDetectService._();
  static final LanguageDetectService instance = LanguageDetectService._();

  final AIService _ai = AIService();
  final Map<int, _CacheEntry> _cache = {};
  static const int _maxCache = 64;
  Timer? _debounce;

  static const Map<String, String> _languageKeywords = {
    'french': 'French',
    'spanish': 'Spanish',
    'german': 'German',
    'italian': 'Italian',
    'portuguese': 'Portuguese',
    'swahili': 'Swahili',
    'kiswahili': 'Swahili',
  };

  static const List<String> _intentKeywords = [
    'learn',
    'teach',
    'speak',
    'study',
    'practice',
    'how to say',
    'translate',
  ];

  Future<DetectedLanguage?> detect(String text) async {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();

    // Fast-path: Check for explicit learning intent in English
    // e.g. "I want to learn French"
    bool hasIntent = _intentKeywords.any((k) => lower.contains(k));
    if (hasIntent) {
      for (var entry in _languageKeywords.entries) {
        if (lower.contains(entry.key)) {
          return DetectedLanguage(language: entry.value, confidence: 1.0);
        }
      }
    }

    if (trimmed.length < 12) return null;

    final key = trimmed.hashCode;
    final cached = _cache[key];
    if (cached != null) {
      // Promote to most-recent
      _cache.remove(key);
      _cache[key] = cached;
      return cached.value;
    }

    _debounce?.cancel();
    final completer = Completer<DetectedLanguage?>();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final resp = await _ai.detectLanguage(trimmed);
        final lang = resp['language'] as String?;
        final conf = (resp['confidence'] as num?)?.toDouble() ?? 0.0;
        final result =
            lang == null ? null : DetectedLanguage(language: lang, confidence: conf);
        _store(key, result);
        if (!completer.isCompleted) completer.complete(result);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    return completer.future;
  }

  void _store(int key, DetectedLanguage? value) {
    if (_cache.length >= _maxCache) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheEntry(value);
  }
}

class DetectedLanguage {
  final String language;
  final double confidence;
  const DetectedLanguage({required this.language, required this.confidence});
}

class _CacheEntry {
  final DetectedLanguage? value;
  _CacheEntry(this.value);
}
