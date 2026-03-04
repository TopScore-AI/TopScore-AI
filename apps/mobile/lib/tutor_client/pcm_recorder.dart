import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Records PCM 16-bit 16kHz mono audio and streams chunks
/// suitable for Gemini Live API input.
class PcmRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _streamSub;

  final _audioController = StreamController<Uint8List>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  Timer? _amplitudeTimer;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Stream of raw PCM 16kHz mono chunks.
  Stream<Uint8List> get audioStream => _audioController.stream;

  /// Stream of amplitude values (0.0 to 1.0) for UI visualization.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Start streaming PCM audio at 16kHz mono.
  Future<void> start() async {
    if (_isRecording) return;

    final hasPerms = await _recorder.hasPermission();
    if (!hasPerms) {
      throw Exception('Microphone permission denied');
    }

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );

    final stream = await _recorder.startStream(config);
    _isRecording = true;

    _streamSub = stream.listen(
      (chunk) {
        if (!_audioController.isClosed) {
          _audioController.add(chunk);
        }
      },
      onError: (error) {
        debugPrint('[PcmRecorder] Stream error: $error');
      },
      onDone: () {
        debugPrint('[PcmRecorder] Stream done');
        _isRecording = false;
      },
    );

    // Monitor amplitude for UI
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        if (!_isRecording) return;
        try {
          final amp = await _recorder.getAmplitude();
          // Normalize dBFS to 0.0-1.0 range (-60dB = silence, 0dB = max)
          final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(normalized);
          }
        } catch (_) {}
      },
    );

    debugPrint('[PcmRecorder] Started streaming PCM 16kHz mono');
  }

  /// Stop recording.
  Future<void> stop() async {
    if (!_isRecording) return;

    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _streamSub?.cancel();
    _streamSub = null;

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('[PcmRecorder] Stop error: $e');
    }

    _isRecording = false;
    debugPrint('[PcmRecorder] Stopped');
  }

  void dispose() {
    stop();
    _audioController.close();
    _amplitudeController.close();
    _recorder.dispose();
  }
}
