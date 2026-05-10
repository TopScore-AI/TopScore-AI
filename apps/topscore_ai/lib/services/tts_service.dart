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

    // 1. Initial State
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // 2. Platform-specific Setup
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
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
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await _tts.awaitSpeakCompletion(true);
      }
    }

    // 3. Default Voice & Language
    await setLanguage('en-US');

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
    // Normalizing across platforms to achieve a consistent cadence.
    // 0.5 matches comfort on iOS, ~0.45 on Android, ~0.9 on Web.
    double platformRate = rate;
    if (kIsWeb) {
      platformRate = rate * 0.9;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      platformRate = rate * 0.45;
    } else {
      platformRate = rate * 0.5;
    }
    await _tts.setSpeechRate(platformRate);
  }

  Future<void> setLanguage(String lang) async {
    await _tts.setLanguage(lang);
    await _selectBestVoice(lang);
    // Refresh rate after language change as some engines reset it
    await setSpeechRate(1.0);
  }

  Future<void> _selectBestVoice(String langCode) async {
    try {
      final List<dynamic> voices = await _tts.getVoices;
      if (voices.isEmpty) return;

      // Prioritize "Natural", "Google", "Enhanced", or "Samantha" (iOS)
      final List<String> priorityKeywords = [
        'natural',
        'google',
        'enhanced',
        'premium',
        'samantha'
      ];

      Map<String, dynamic>? bestVoice;
      int highestPriority = -1;

      for (final v in voices) {
        final Map<String, dynamic> voice = Map<String, dynamic>.from(v);
        final name = (voice['name'] as String? ?? '').toLowerCase();
        final locale = (voice['locale'] as String? ?? '').toLowerCase();

        if (locale.contains(langCode.toLowerCase())) {
          int priority = 0;
          for (int i = 0; i < priorityKeywords.length; i++) {
            if (name.contains(priorityKeywords[i])) {
              priority = priorityKeywords.length - i;
              break;
            }
          }

          if (priority > highestPriority) {
            highestPriority = priority;
            bestVoice = voice;
          }
        }
      }

      if (bestVoice != null) {
        if (kDebugMode) {
          debugPrint('[TtsService] Selecting best voice: ${bestVoice['name']} ($langCode)');
        }
        await _tts.setVoice(
          bestVoice.map((k, v) => MapEntry(k, v?.toString() ?? '')),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TtsService] Error selecting voice: $e');
    }
  }

  Future<List<dynamic>> getLanguages() async {
    return await _tts.getLanguages;
  }
}
