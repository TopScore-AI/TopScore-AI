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
    notify();
    // actual TTS implementation here (e.g. TtsService)
    await Future.delayed(const Duration(seconds: 1)); // Placeholder
    _isTtsSpeaking = false;
    _speakingMessageId = null;
    notify();
  }

  Future<void> stopTts() async {
    _isTtsSpeaking = false;
    _isTtsPaused = false;
    _speakingMessageId = null;
    notify();
  }

  Future<void> pauseTts() async {
    _isTtsPaused = true;
    notify();
  }

  Future<void> resumeTts() async {
    _isTtsPaused = false;
    notify();
  }
}
