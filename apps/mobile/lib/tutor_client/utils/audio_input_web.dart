import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:waveform_flutter/waveform_flutter.dart' as wf;
import 'dart:developer' as developer;

/// Web-specific audio input using the Web Audio API to capture raw PCM16
/// at 16kHz — the format required by TopScore AI.
///
/// Key design decisions for Android Chrome compatibility:
/// - [requestPermission] must be called directly from a user gesture (tap handler)
///   before any other async work, because Android Chrome revokes the gesture
///   context after ~1 second of async activity.
/// - The MediaStream is kept alive across sessions (tracks are never stopped)
///   so subsequent calls to [startRecordingStream] don't need getUserMedia again.
class AudioInput extends ChangeNotifier {
  bool isRecording = false;

  web.MediaStream? _stream;
  web.AudioContext? _audioCtx;
  web.ScriptProcessorNode? _processor;
  web.MediaStreamAudioSourceNode? _source;

  StreamController<Uint8List>? _audioDataController;
  StreamController<wf.Amplitude>? _amplitudeStreamController;

  Stream<wf.Amplitude>? amplitudeStream;

  static const int _sampleRate = 16000;
  static const int _bufferSize = 2048; // Reduced for lower latency (128ms)

  /// Call this FIRST, directly from the button's onPressed handler,
  /// before any other async work. Stores the MediaStream for reuse.
  Future<void> requestPermission() async {
    if (_stream != null) return; // Already have permission

    // Detailed constraints for high-quality live voice
    final constraints = web.MediaStreamConstraints(
      audio: {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      }.jsify()!,
      video: false.toJS,
    );

    _stream = await web.window.navigator.mediaDevices
        .getUserMedia(constraints)
        .toDart;
  }

  /// Called during setup — just ensures permission was granted.
  Future<void> init() async {
    // Permission is requested eagerly via requestPermission().
    // If _stream is null here it means requestPermission() wasn't called
    // in time — try anyway (may fail on Android if gesture context is gone).
    if (_stream == null) {
      await requestPermission();
    }
  }

  Future<Stream<Uint8List>?> startRecordingStream() async {
    // Tear down previous AudioContext but keep the MediaStream alive
    await _teardownAudioGraph();

    _audioDataController = StreamController<Uint8List>.broadcast();
    _amplitudeStreamController = StreamController<wf.Amplitude>.broadcast();
    amplitudeStream = _amplitudeStreamController!.stream;

    try {
      // Reuse existing stream — avoids needing getUserMedia again
      if (_stream == null) {
        await requestPermission();
      }

      _audioCtx = web.AudioContext(
        web.AudioContextOptions(sampleRate: _sampleRate),
      );
      await _audioCtx!.resume().toDart;

      final stream = _stream;
      final ctx = _audioCtx;
      if (stream == null || ctx == null) {
        throw Exception('Audio input stream or context not available');
      }

      _source = ctx.createMediaStreamSource(stream);
      _processor = _audioCtx!.createScriptProcessor(_bufferSize, 1, 1);

      _processor!.addEventListener(
        'audioprocess',
        (web.Event event) {
          if (_audioDataController == null || _audioDataController!.isClosed) {
            return;
          }
          final audioEvent = event as web.AudioProcessingEvent;
          final channelData = audioEvent.inputBuffer.getChannelData(0);
          _audioDataController!.add(_float32ToPcm16(channelData.toDart));

          // Amplitude for waveform visualizer
          double maxAmp = 0;
          final data = channelData.toDart;
          for (int i = 0; i < data.length; i++) {
            final v = data[i].abs();
            if (v > maxAmp) maxAmp = v;
          }
          final dbfs = maxAmp > 0 ? 20 * (maxAmp.clamp(1e-10, 1.0)) : -160.0;
          _amplitudeStreamController?.add(
            wf.Amplitude(current: dbfs, max: 0),
          );
        }.toJS,
      );

      _source!.connect(_processor!);
      _processor!.connect(_audioCtx!.destination);

      isRecording = true;
      notifyListeners();

      return _audioDataController!.stream;
    } catch (e) {
      if (kDebugMode) debugPrint('Web audio input error: $e');
      rethrow;
    }
  }

  Uint8List _float32ToPcm16(Float32List float32) {
    final pcm = ByteData(float32.length * 2);
    for (int i = 0; i < float32.length; i++) {
      final clamped = float32[i].clamp(-1.0, 1.0);
      final sample = (clamped * 32767).round();
      pcm.setInt16(i * 2, sample, Endian.little);
    }
    return pcm.buffer.asUint8List();
  }

  /// Tears down the AudioContext graph without stopping the MediaStream tracks.
  /// This allows the stream to be reused on the next [startRecordingStream] call.
  Future<void> _teardownAudioGraph() async {
    try {
      _processor?.disconnect();
      _source?.disconnect();
      await _audioCtx?.close().toDart;
    } catch (_) {}
    _processor = null;
    _source = null;
    _audioCtx = null;

    await _amplitudeStreamController?.close();
    _amplitudeStreamController = null;
    amplitudeStream = null;

    await _audioDataController?.close();
    _audioDataController = null;
  }

  Future<void> stopRecording() async {
    isRecording = false;
    await _teardownAudioGraph();
    
    // Explicitly release the hardware lock (Red Dot Removal)
    if (_stream != null) {
      final tracks = _stream!.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
        developer.log('🎙️ Audio track stopped: ${track.label}', name: 'AudioInput');
      }
      _stream = null;
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    stopRecording();
    // Only stop tracks on full dispose
    _stream?.getTracks().toDart.forEach((track) => track.stop());
    _stream = null;
    super.dispose();
  }
}
