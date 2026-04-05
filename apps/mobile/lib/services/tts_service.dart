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
      _isSpeaking = false;
      _isPaused = false;
      onComplete?.call();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _isPaused = false;
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
      onCancel?.call();
      if (kDebugMode) debugPrint('[TtsService] Error: $msg');
    });
  }

  Future<void> speak(String text) async {
    await init();
    if (text.trim().isEmpty) return;
    // Stop any current speech before starting new
    if (_isSpeaking) await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
    _isPaused = false;
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
