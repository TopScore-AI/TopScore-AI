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

  Future<DetectedLanguage?> detect(String text) async {
    final trimmed = text.trim();
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
