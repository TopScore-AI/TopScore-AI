import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;
import 'package:topscore_ai/shared/utils/markdown_stripper.dart';

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _ttsAvailable = false;
  bool get ttsAvailable => _ttsAvailable;

  Stream<Amplitude> get onAmplitudeChanged => _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  
  Future<void> initializeTts({
    String language = "en-US",
    double speechRate = 0.5,
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    if (kIsWeb) {
      _ttsAvailable = false;
      return;
    }

    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setPitch(pitch);
      _ttsAvailable = true;
    } catch (e) {
      developer.log('TTS init error: ', name: 'AudioService', level: 900);
      _ttsAvailable = false;
    }
  }

  void setTtsCompletionHandler(VoidCallback handler) {
    _flutterTts.setCompletionHandler(handler);
  }

  void setTtsCancelHandler(VoidCallback handler) {
    _flutterTts.setCancelHandler(handler);
  }

  Future<void> speak(String text) async {
    final cleanedText = MarkdownStripper.strip(text);
    if (cleanedText.isNotEmpty) {
      await _flutterTts.speak(cleanedText);
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<bool> hasRecordingPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<Stream<Uint8List>?> startPcmStream() async {
    if (await hasRecordingPermission()) {
      return await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
    }
    return null;
  }

  Future<void> stopPcmStream() async {
    await _audioRecorder.stop();
  }

  Future<void> startRecording() async {
    String path = '';
    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } else {
      path = 'audio_recording.m4a';
    }

    await _audioRecorder.start(const RecordConfig(), path: path);
  }

  Future<String?> stopRecording() async {
    return await _audioRecorder.stop();
  }

  Future<String?> getBase64FromRecording(String? path) async {
    if (path == null) return null;

    String? base64Audio;

    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200) {
          base64Audio = base64Encode(response.bodyBytes);
        }
      } catch (e) {
        developer.log('Error fetching blob: ', name: 'AudioService', level: 900);
      }
    } else {
      final file = File(path);
      if (await file.exists()) {
        final audioBytes = await file.readAsBytes();
        base64Audio = base64Encode(audioBytes);
      }
    }

    return base64Audio;
  }

  Future<void> playAudio(String url) async {
    try {
      if (kIsWeb) {
        await _audioPlayer.play(UrlSource(url));
      } else {
        if (!url.startsWith('http') && !url.startsWith('data:')) {
          await _audioPlayer.play(DeviceFileSource(url));
        } else {
          await _audioPlayer.play(UrlSource(url));
        }
      }
    } catch (e) {
      developer.log('Error playing audio: ', name: 'AudioService', level: 900);
    }
  }

  Future<void> playAudioFromBase64(String dataUri) async {
    try {
      final base64Str = dataUri.split(',').last;
      final bytes = base64Decode(base64Str);
      await playPcmAudio(bytes);
    } catch (e) {
      developer.log('Error playing base64 audio: ', name: 'AudioService', level: 900);
    }
  }

  Future<void> playPcmAudio(Uint8List pcmBytes) async {
    try {
      final channels = 1;
      final sampleRate = 24000;
      final byteRate = sampleRate * channels * 2;
      final blockAlign = channels * 2;
      
      final wavData = BytesBuilder();
      wavData.add(ascii.encode('RIFF'));
      final chunkSize = pcmBytes.length + 36;
      wavData.add(_int32ToBytes(chunkSize));
      wavData.add(ascii.encode('WAVE'));
      
      wavData.add(ascii.encode('fmt '));
      wavData.add(_int32ToBytes(16));
      wavData.add(_int16ToBytes(1));
      wavData.add(_int16ToBytes(channels));
      wavData.add(_int32ToBytes(sampleRate));
      wavData.add(_int32ToBytes(byteRate));
      wavData.add(_int16ToBytes(blockAlign));
      wavData.add(_int16ToBytes(16));
      
      wavData.add(ascii.encode('data'));
      wavData.add(_int32ToBytes(pcmBytes.length));
      wavData.add(pcmBytes);
      
      await _audioPlayer.play(BytesSource(wavData.toBytes()));
    } catch (e) {
      developer.log('Error playing PCM audio: ', name: 'AudioService', level: 900);
    }
  }

  List<int> _int32ToBytes(int value) {
    return [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];
  }

  List<int> _int16ToBytes(int value) {
    return [
      value & 0xff,
      (value >> 8) & 0xff,
    ];
  }

  void stop() {
    _audioPlayer.stop();
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
  }
}



