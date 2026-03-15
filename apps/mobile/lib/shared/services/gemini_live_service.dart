import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

enum GeminiLiveStatus { disconnected, connecting, connected, setupComplete, error }

class GeminiLiveService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  final _statusController = StreamController<GeminiLiveStatus>.broadcast();
  Stream<GeminiLiveStatus> get statusStream => _statusController.stream;
  
  final _audioController = StreamController<String>.broadcast();
  Stream<String> get audioStream => _audioController.stream;
  
  final _transcriptionController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get transcriptionStream => _transcriptionController.stream;

  final _interruptionController = StreamController<void>.broadcast();
  Stream<void> get interruptionStream => _interruptionController.stream;

  GeminiLiveStatus _status = GeminiLiveStatus.disconnected;
  GeminiLiveStatus get status => _status;

  Future<void> connect(String url, String token, String systemInstruction, {String model = 'gemini-2.5-flash-native-audio-preview-12-2025'}) async {
    if (_status != GeminiLiveStatus.disconnected) return;

    _updateStatus(GeminiLiveStatus.connecting);

    try {
      final uri = Uri.parse('$url?access_token=$token');
      _channel = WebSocketChannel.connect(uri);
      
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          developer.log('GeminiLive WebSocket error: $error', name: 'GeminiLiveService');
          _updateStatus(GeminiLiveStatus.error);
        },
        onDone: () {
          developer.log('GeminiLive WebSocket closed', name: 'GeminiLiveService');
          _updateStatus(GeminiLiveStatus.disconnected);
        },
      );

      _updateStatus(GeminiLiveStatus.connected);
      _sendSetup(model, systemInstruction);
    } catch (e) {
      developer.log('GeminiLive connection failed: $e', name: 'GeminiLiveService');
      _updateStatus(GeminiLiveStatus.error);
    }
  }

  void _updateStatus(GeminiLiveStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      
      if (data['setupComplete'] != null) {
        _updateStatus(GeminiLiveStatus.setupComplete);
        return;
      }

      final serverContent = data['serverContent'];
      if (serverContent != null) {
        if (serverContent['interrupted'] == true) {
          _interruptionController.add(null);
        }
        if (serverContent['modelTurn'] != null) {
          final parts = serverContent['modelTurn']['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final part = parts[0];
            if (part['inlineData'] != null) {
              final audioBase64 = part['inlineData']['data'];
              _audioController.add(audioBase64);
            } else if (part['text'] != null) {
              _transcriptionController.add({'type': 'output', 'text': part['text']});
            }
          }
        }
        
                if (serverContent['outputTranscription'] != null) {
          _transcriptionController.add({
            'type': 'output',
            'text': serverContent['outputTranscription']['text']
          });
        }
        if (serverContent['inputTranscription'] != null) {
          _transcriptionController.add({
            'type': 'input', 
            'text': serverContent['inputTranscription']['text'],
            'finished': serverContent['inputTranscription']['finished']
          });
        }
      }
    } catch (e) {
      developer.log('Error parsing GeminiLive message: $e', name: 'GeminiLiveService');
    }
  }

  void _sendSetup(String model, String systemInstruction) {
    final setupMessage = {
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'enableAffectiveDialog': true,
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': 'Puck',
              }
            }
          }
        },
        'systemInstruction': {
          'parts': [{'text': systemInstruction}]
        },
        'tools': [
          {'googleSearch': {}}
        ],
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
        'proactivity': {
          'proactiveAudio': true,
        },
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'disabled': false,
            'silenceDurationMs': 2000,
          }
        }
      }
    };
    
    _sendMessage(setupMessage);
  }

  void sendAudio(String base64Pcm) {
    final message = {
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=16000',
          'data': base64Pcm
        }
      }
    };
    _sendMessage(message);
  }

  void sendVideoFrame(String base64Jpeg) {
    final message = {
      'realtimeInput': {
        'video': {
          'mimeType': 'image/jpeg',
          'data': base64Jpeg
        }
      }
    };
    _sendMessage(message);
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _updateStatus(GeminiLiveStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _audioController.close();
    _transcriptionController.close();
    _interruptionController.close();
  }
}







