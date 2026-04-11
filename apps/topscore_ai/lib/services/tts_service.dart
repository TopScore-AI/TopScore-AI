import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Centralized TTS service — platform-aware, singleton.
///
/// Handles the quirks of each platform:
/// - Web: browser speechSynthesis — faster default rate, no pause support
/// - iOS: requires shared audio session
/// - Android: awaitSpeakCompletion for reliable state tracking
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  bool _isSpeaking = false;
  bool _isPaused = false;

  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;

  // Callbacks — set by the consumer
  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onCancel;
  VoidCallback? onPause;
  VoidCallback? onResume;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Language & voice quality
    await _tts.setLanguage('en-US');
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Platform-specific speech rate
    // Web speechSynthesis default is 1.0 (words/sec), flutter_tts maps 0–1
    // iOS/Android: 0.5 is comfortable reading pace
    await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.5);

    if (kIsWeb) {
      // Browsers often load voices asynchronously. Wait a bit if none are available.
      int attempts = 0;
      while (attempts < 5) {
        final voices = await _tts.getVoices;
        if (voices.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
    }

    // iOS: configure audio session so TTS plays over silent mode
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }

    // Android: wait for each utterance to finish before returning
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _tts.awaitSpeakCompletion(true);
    }

    _tts.setStartHandler(() {
      _isSpeaking = true;
      _isPaused = false;
      onStart?.call();
    });

    _tts.setCompletionHandler(() {
      if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
        _utteranceCompleter!.complete();
      }
      // Note: We don't call onComplete?.call() here anymore because the 
      // sequential loop in speak() handles and calls it once after all chunks are done.
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _isPaused = false;
      if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
        _utteranceCompleter!.complete();
      }
      onCancel?.call();
    });

    _tts.setPauseHandler(() {
      _isPaused = true;
      onPause?.call();
    });

    _tts.setContinueHandler(() {
      _isPaused = false;
      onResume?.call();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _isPaused = false;
      if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
        _utteranceCompleter!.complete();
      }
      onCancel?.call();
      if (kDebugMode) debugPrint('[TtsService] Error: $msg');
    });
  }

  Completer<void>? _utteranceCompleter;
  bool _stopRequested = false;

  Future<void> speak(String text) async {
    if (!_initialized) await init();
    if (text.trim().isEmpty) return;
    
    _stopRequested = false;
    // Stop any current speech before starting new
    if (_isSpeaking) {
      await stop();
      // Give the engine a moment to reset
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Split text into chunks (sentences) to prevent "early exit" bugs on mobile
    // We split by punctuation followed by space
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    
    _isSpeaking = true;
    for (int i = 0; i < sentences.length; i++) {
      if (_stopRequested) break;
      
      final sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;

      _utteranceCompleter = Completer<void>();
      
      await _tts.speak(sentence);
      
      // Wait for this specific chunk to finish
      // On Android, awaitSpeakCompletion handles this.
      // On other platforms, we wait for the completer.
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        await _utteranceCompleter!.future;
      }

      // Small breather between sentences for naturalness
      if (!_stopRequested && i < sentences.length - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
    
    _isSpeaking = false;
    if (!_stopRequested) {
      onComplete?.call();
    }
  }

  Future<void> stop() async {
    _stopRequested = true;
    await _tts.stop();
    _isSpeaking = false;
    _isPaused = false;
    if (_utteranceCompleter != null && !_utteranceCompleter!.isCompleted) {
      _utteranceCompleter!.complete();
    }
  }

  Future<void> pause() async {
    // Web doesn't support pause — stop instead
    if (kIsWeb) {
      await stop();
    } else {
      await _tts.pause();
    }
  }

  Future<void> resume() async {
    if (kIsWeb || _isPaused == false) return;
    // flutter_tts resume is not reliable on all platforms — re-speak is safer
    // but we keep the API consistent
    await _tts.speak('');
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  Future<void> setLanguage(String lang) async {
    await _tts.setLanguage(lang);
  }

  Future<List<dynamic>> getLanguages() async {
    return await _tts.getLanguages;
  }
}
