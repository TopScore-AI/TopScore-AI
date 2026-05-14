// ignore_for_file: invalid_use_of_protected_member
part of '../chat_controller.dart';

// ===========================================================================
// Speech-to-Text (dictation mic button)
// ===========================================================================

extension ChatControllerSTT on ChatController {
  Future<void> startDictation(BuildContext? context) async {
    if (_stt.isListening) return;

    final available = await _stt.initialize(
      onError: (error) {
        developer.log('STT error: $error', name: 'ChatController');
        _isRecording = false;
        notify();
      },
      onStatus: (status) {
        developer.log('STT status: $status', name: 'ChatController');
        if (status == 'done' || status == 'notListening') {
          if (_isRecording) {
            _isRecording = false;
            notify();
          }
        }
      },
    );

    if (!available) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone not available')),
        );
      }
      return;
    }

    final baseText = _textController.text.trimRight();
    _isRecording = true;
    notify();

    final localeId = _getSpeechLocaleId();
    developer.log('Starting dictation with locale: $localeId (subject: ${subject ?? chatThread?['subject']})', name: 'ChatController');

    _stt.listen(
      localeId: localeId,
      onResult: (result) {
        final words = result.recognizedWords;
        final updated = baseText.isEmpty ? words : '$baseText $words';
        _textController.value = TextEditingValue(
          text: updated,
          selection: TextSelection.collapsed(offset: updated.length),
        );
        if (result.finalResult) {
          _isRecording = false;
          _stt.stop();
          notify();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  String? _getSpeechLocaleId() {
    final sub = (subject ?? chatThread?['subject'] ?? '').toString().toLowerCase();
    if (sub.contains('french') || sub.contains('français')) return 'fr-FR';
    if (sub.contains('german') || sub.contains('deutsch')) return 'de-DE';
    if (sub.contains('spanish') || sub.contains('español')) return 'es-ES';
    if (sub.contains('mandarin') || sub.contains('chinese') || sub.contains('普通话')) return 'zh-CN';
    if (sub.contains('swahili') || sub.contains('kiswahili')) return 'sw-KE';
    if (sub.contains('arabic')) return 'ar-AE';
    if (sub.contains('italian')) return 'it-IT';
    return null; // Fallback to default system language (English / Swahili)
  }

  Future<void> stopDictationAndSend(BuildContext context) async {
    await _stt.stop();
    _isRecording = false;
    notify();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!context.mounted) return;
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      sendUserMessage(context, text: text);
    }
  }
}
