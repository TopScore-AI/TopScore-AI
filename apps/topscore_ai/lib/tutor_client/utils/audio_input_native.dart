import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:waveform_flutter/waveform_flutter.dart' as wf;

class AudioInput extends ChangeNotifier {
  AudioRecorder _recorder = AudioRecorder();
  final AudioEncoder _encoder = AudioEncoder.pcm16bits;

  bool isRecording = false;
  bool isPaused = false;

  StreamController<Uint8List>? _audioDataController;
  StreamSubscription? _recorderStreamSub;

  Stream<Uint8List>? get audioStream => _audioDataController?.stream;

  Stream<wf.Amplitude>? amplitudeStream;
  StreamSubscription? _amplitudeSubscription;
  StreamController<wf.Amplitude>? _amplitudeStreamController;

  Future<void> init() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('App does not have mic permissions');
    }
  }

  /// No-op on native — permission is handled by the OS dialog via hasPermission().
  Future<void> requestPermission() async {
    await init();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioDataController?.close();
    super.dispose();
  }

  Future<Stream<Uint8List>?> startRecordingStream() async {
    await _amplitudeSubscription?.cancel();
    await _amplitudeStreamController?.close();
    await _recorderStreamSub?.cancel();
    await _audioDataController?.close();

    _audioDataController = StreamController<Uint8List>();

    // Recreate recorder for a fresh stream each time
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('Error stopping recorder: $e');
    }
    await _recorder.dispose();
    _recorder = AudioRecorder();

    // Initialize platform channel on the new instance
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    // Device selection — mobile often returns []
    final devices = await _recorder.listInputDevices();
    InputDevice? selectedDevice;
    if (devices.isNotEmpty) {
      try {
        selectedDevice = devices.firstWhere(
          (d) {
            final l = d.label.toLowerCase();
            return !l.contains('blackhole') &&
                (l.contains('internal') ||
                    l.contains('built-in') ||
                    l.contains('macbook'));
          },
          orElse: () => devices.firstWhere(
            (d) => !d.label.toLowerCase().contains('blackhole'),
            orElse: () => devices.first,
          ),
        );
      } catch (_) {
        selectedDevice = devices.first;
      }
    }

    final config = RecordConfig(
      encoder: _encoder,
      sampleRate: 16000,
      device: selectedDevice,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
      androidConfig: const AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
      ),
    );

    final rawStream = await _recorder.startStream(config);

    // 16kHz, 16-bit, mono = 32000 bytes/sec → 100ms = 3200 bytes
    const chunkSize = 3200;
    final List<int> buffer = [];
    _recorderStreamSub = rawStream.listen(
      (data) {
        if (data.isEmpty) return;
        final ctrl = _audioDataController;
        if (ctrl == null || ctrl.isClosed) return;
        buffer.addAll(data);
        while (buffer.length >= chunkSize) {
          ctrl.add(Uint8List.fromList(buffer.sublist(0, chunkSize)));
          buffer.removeRange(0, chunkSize);
        }
      },
      onError: (e) {
        if (kDebugMode) debugPrint('Recorder stream error: $e');
        _audioDataController?.addError(e);
      },
    );

    _amplitudeStreamController = StreamController<wf.Amplitude>.broadcast();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      _amplitudeStreamController?.add(
        wf.Amplitude(current: amp.current, max: amp.max),
      );
    });
    amplitudeStream = _amplitudeStreamController?.stream;

    isRecording = true;
    notifyListeners();

    final ctrl = _audioDataController;
    if (ctrl == null || ctrl.isClosed) return null;
    return ctrl.stream;
  }

  Future<void> stopRecording() async {
    try {
      await _recorder.stop();
      // Dispose of the recorder to fully release hardware locks
      await _recorder.dispose();
      // Re-create it for the next session
      _recorder = AudioRecorder();
    } catch (e) {
      if (kDebugMode) debugPrint('Error stopping/disposing recorder: $e');
    }
    await _amplitudeSubscription?.cancel();
    await _amplitudeStreamController?.close();
    amplitudeStream = null;
    await _recorderStreamSub?.cancel();
    await _audioDataController?.close();
    _audioDataController = null;
    isRecording = false;
    notifyListeners();
  }

  Future<void> togglePause() async {
    if (isPaused) {
      await _recorder.resume();
      isPaused = false;
    } else {
      await _recorder.pause();
      isPaused = true;
    }
    notifyListeners();
  }
}
