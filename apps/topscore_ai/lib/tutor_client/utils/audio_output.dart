// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioOutput {
  bool initialized = false;
  AudioSource? stream;
  SoundHandle? handle;
  final int sampleRate = 24000;
  final Channels channels = Channels.mono;
  final BufferType format = BufferType.s16le; // pcm16bits

  Future<void> init() async {
    if (initialized) {
      return;
    }

    try {
      /// Initialize the player (singleton).
      await SoLoud.instance.init(sampleRate: sampleRate, channels: channels);
      initialized = true;
      log('AudioOutput initialized successfully');
    } catch (e) {
      log('Failed to initialize AudioOutput: $e');
      // On web, flutter_soloud may fail to initialize
      // We'll handle this gracefully by not setting initialized to true
      if (kIsWeb) {
        log('AudioOutput initialization failed on web - this is expected if audio permissions are not granted');
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (initialized) {
      try {
        await SoLoud.instance.disposeAllSources();
        SoLoud.instance.deinit();
        initialized = false;
        log('AudioOutput disposed successfully');
      } catch (e) {
        log('Error disposing AudioOutput: $e');
        initialized = false;
      }
    }
  }

  SoLoud get instance => SoLoud.instance;

  AudioSource? setupNewStream() {
    if (!initialized || !SoLoud.instance.isInitialized) {
      log('Cannot setup stream - AudioOutput not initialized');
      return null;
    }

    try {
      stream = SoLoud.instance.setBufferStream(
        bufferingType: BufferingType.released,
        bufferingTimeNeeds:
            0.04, // 40ms — low enough for real-time, high enough to avoid underruns
        sampleRate: sampleRate,
        channels: channels,
        format: format,
        onBuffering: (isBuffering, handle, time) {
          log('Buffering: $isBuffering, Time: $time');
        },
      );
      log('New audio output stream buffer created.');
      return stream;
    } catch (e) {
      log('Error setting up audio stream: $e');
      return null;
    }
  }

  Future<AudioSource?> playStream() async {
    if (!initialized) {
      log('Cannot play stream - AudioOutput not initialized');
      return null;
    }

    try {
      var myStream = setupNewStream();
      if (!SoLoud.instance.isInitialized || myStream == null) {
        return null;
      }
      // Play audio stream
      handle = await SoLoud.instance.play(myStream);
      return stream = myStream;
    } catch (e) {
      log('Error playing audio stream: $e');
      return null;
    }
  }

  void addDataToAudioStream(Uint8List audioChunk) {
    if (!initialized) {
      return;
    }

    var currentStream = stream;
    if (currentStream != null) {
      try {
        SoLoud.instance.addAudioDataStream(currentStream, audioChunk);
      } catch (e) {
        log('Error adding data to audio stream: $e');
      }
    }
  }

  /// Returns true if the audio output stream is actively playing.
  bool get isPlaying {
    if (!initialized || handle == null || stream == null) {
      return false;
    }
    try {
      return SoLoud.instance.getIsValidVoiceHandle(handle!);
    } catch (e) {
      log('Error checking if playing: $e');
      return false;
    }
  }

  /// Instantly flushes the current audio buffer (barge-in).
  /// Stops the current stream and creates a fresh one so new AI audio
  /// can start immediately without audible artifacts.
  Future<void> flushBuffer() async {
    if (!initialized) {
      return;
    }

    var currentStream = stream;
    var currentHandle = handle;

    if (currentStream == null || currentHandle == null) return;

    try {
      if (SoLoud.instance.getIsValidVoiceHandle(currentHandle)) {
        SoLoud.instance.setDataIsEnded(currentStream);
        await SoLoud.instance.stop(currentHandle);
      }
    } catch (e) {
      log('Error flushing audio buffer: $e');
    }

    // Immediately create a fresh stream so the next AI turn can play
    stream = null;
    handle = null;
    await playStream();
  }

  Future<void> stopStream() async {
    if (!initialized) {
      stream = null;
      handle = null;
      return;
    }

    var currentStream = stream;
    var currentHandle = handle;

    // Stream doesn't exist or handle is not valid - so nothing to stop.
    if (currentStream == null || currentHandle == null) {
      stream = null;
      handle = null;
      return;
    }

    try {
      if (SoLoud.instance.getIsValidVoiceHandle(currentHandle)) {
        // End data to stream & stop currently playing sound from handle
        SoLoud.instance.setDataIsEnded(currentStream);
        await SoLoud.instance.stop(currentHandle);
      }
    } catch (e) {
      log('Error stopping audio stream: $e');
    } finally {
      stream = null;
      handle = null;
    }
  }
}
