// ignore_for_file: invalid_use_of_protected_member
part of '../chat_controller.dart';

// ===========================================================================
// Text-to-Speech (TTS) — ai speech, audio player integration
// ===========================================================================

extension ChatControllerTTS on ChatController {
  void initTts() {
    _audioPlayer.onDurationChanged.listen((d) {
      _audioDuration = d;
      notify();
    });
    _audioPlayer.onPositionChanged.listen((p) {
      _audioPosition = p;
      notify();
    });
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.playing) {
        _isPlayingAudio = true;
      } else if (s == PlayerState.paused) {
        _isPlayingAudio = false;
      } else if (s == PlayerState.completed) {
        _isPlayingAudio = false;
        _playingAudioMessageId = null;
      }
      notify();
    });

    // --- TTS Service Integration ---
    _ttsService.onStart = () {
      _isTtsSpeaking = true;
      _isTtsPaused = false;
      notify();
    };
    _ttsService.onComplete = () {
      _isTtsSpeaking = false;
      _isTtsPaused = false;
      _speakingMessageId = null;
      notify();
    };
    _ttsService.onCancel = () {
      _isTtsSpeaking = false;
      _isTtsPaused = false;
      _speakingMessageId = null;
      notify();
    };
    _ttsService.onPause = () {
      _isTtsPaused = true;
      notify();
    };
    _ttsService.onResume = () {
      _isTtsPaused = false;
      notify();
    };
  }

  Future<void> playVoiceMessage(String messageId, String url) async {
    if (_isPlayingAudio && _playingAudioMessageId == messageId) {
      await pauseVoiceMessage();
      return;
    }
    _playingAudioMessageId = messageId;
    await _audioPlayer.play(UrlSource(url));
    notify();
  }

  Future<void> pauseVoiceMessage() async {
    await _audioPlayer.pause();
    notify();
  }

  Future<void> resumeVoiceMessage() async {
    await _audioPlayer.resume();
    notify();
  }

  Future<void> stopVoiceMessage() async {
    await _audioPlayer.stop();
    _playingAudioMessageId = null;
    _isPlayingAudio = false;
    notify();
  }

  Future<void> speak(String text, {String? messageId}) async {
    _speakingMessageId = messageId;
    _isTtsSpeaking = true;
    _isTtsPaused = false;
    notify();
    
    // Sanitize text for speech:
    // 1. Remove technical metadata tags
    final cleaned = postFormatAIResponse(text);
    // 2. Strip formatting, newlines, images
    final plainText = stripMarkdown(cleaned);
    
    if (plainText.isEmpty) {
      _isTtsSpeaking = false;
      _speakingMessageId = null;
      notify();
      return;
    }

    await _ttsService.speak(plainText);
  }

  Future<void> stopTts() async {
    await _ttsService.stop();
    _isTtsSpeaking = false;
    _isTtsPaused = false;
    _speakingMessageId = null;
    notify();
  }

  Future<void> pauseTts() async {
    await _ttsService.pause();
    _isTtsPaused = true;
    notify();
  }

  Future<void> resumeTts() async {
    await _ttsService.resume();
    _isTtsPaused = false;
    notify();
  }
}
