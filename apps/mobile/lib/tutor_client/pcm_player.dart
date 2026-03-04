import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Plays raw PCM 24kHz 16-bit mono audio received from Gemini Live API.
///
/// Buffers incoming chunks and plays them as WAV when a turn completes.
/// For real-time streaming playback, chunks are accumulated and played
/// once enough data is buffered or the turn ends.
class PcmPlayer {
  final AudioPlayer _player = AudioPlayer();
  final List<int> _buffer = [];
  Timer? _playbackTimer;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  final _stateController = StreamController<bool>.broadcast();
  Stream<bool> get playingStream => _stateController.stream;

  static const int _sampleRate = 24000;
  static const int _bitsPerSample = 16;
  static const int _numChannels = 1;

  PcmPlayer() {
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      if (!_stateController.isClosed) {
        _stateController.add(false);
      }
    });
  }

  /// Add a PCM audio chunk to the buffer.
  void addChunk(Uint8List pcmData) {
    _buffer.addAll(pcmData);
  }

  /// Play all buffered audio as WAV. Call when turn is complete.
  Future<void> playBuffer() async {
    if (_buffer.isEmpty) return;

    final pcmData = Uint8List.fromList(_buffer);
    _buffer.clear();

    final wavBytes = _createWav(pcmData);

    _isPlaying = true;
    if (!_stateController.isClosed) {
      _stateController.add(true);
    }

    try {
      if (kIsWeb) {
        // On web, use bytes source
        await _player.play(BytesSource(wavBytes));
      } else {
        // On native, write to temp file
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/gemini_live_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        await file.writeAsBytes(wavBytes);
        await _player.play(DeviceFileSource(file.path));
      }
    } catch (e) {
      debugPrint('[PcmPlayer] Playback error: $e');
      _isPlaying = false;
      if (!_stateController.isClosed) {
        _stateController.add(false);
      }
    }
  }

  /// Stop current playback and clear buffer.
  Future<void> stop() async {
    _buffer.clear();
    _playbackTimer?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
    if (!_stateController.isClosed) {
      _stateController.add(false);
    }
  }

  /// Clear the buffer without stopping current playback.
  void clearBuffer() {
    _buffer.clear();
  }

  /// Create a WAV file from raw PCM data.
  Uint8List _createWav(Uint8List pcmData) {
    final dataLength = pcmData.length;
    final fileLength = dataLength + 36; // Total file size minus 8 bytes for RIFF header
    final byteRate = _sampleRate * _numChannels * (_bitsPerSample ~/ 8);
    final blockAlign = _numChannels * (_bitsPerSample ~/ 8);

    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileLength, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt sub-chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // Sub-chunk size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, _numChannels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);

    // data sub-chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);

    // Combine header + PCM data
    final wav = Uint8List(44 + dataLength);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataLength, pcmData);

    return wav;
  }

  void dispose() {
    stop();
    _player.dispose();
    _stateController.close();
  }
}
