import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:web_socket_channel/web_socket_channel.dart';

enum GeminiLiveEventType {
  user,
  gemini,
  turnComplete,
  interrupted,
  toolCall,
  error,
  message,
  status,
  quiz,
  flashcards,
  interactiveGraph,
  mnemonic,
  punnettSquare
}

class GeminiLiveEvent {
  final GeminiLiveEventType type;
  final String? text;
  final String? error;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final dynamic toolResult;
  final Map<String, dynamic>? raw;

  GeminiLiveEvent({
    required this.type,
    this.text,
    this.error,
    this.toolName,
    this.toolArgs,
    this.toolResult,
    this.raw,
  });

  factory GeminiLiveEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    
    switch (typeStr) {
      case 'user':
        return GeminiLiveEvent(type: GeminiLiveEventType.user, text: json['text']);
      case 'gemini':
        return GeminiLiveEvent(type: GeminiLiveEventType.gemini, text: json['text']);
      case 'turn_complete':
        return GeminiLiveEvent(type: GeminiLiveEventType.turnComplete);
      case 'interrupted':
        return GeminiLiveEvent(type: GeminiLiveEventType.interrupted);
      case 'tool_call':
        return GeminiLiveEvent(
          type: GeminiLiveEventType.toolCall,
          toolName: json['name'],
          toolArgs: json['args'],
          toolResult: json['result'],
        );
      case 'error':
        return GeminiLiveEvent(type: GeminiLiveEventType.error, error: json['error']);
      case 'message':
        return GeminiLiveEvent(type: GeminiLiveEventType.message, text: json['content'], raw: json);
      case 'status':
        return GeminiLiveEvent(type: GeminiLiveEventType.status, text: json['message'], raw: json);
      case 'quiz':
        return GeminiLiveEvent(type: GeminiLiveEventType.quiz, raw: json);
      case 'flashcards':
        return GeminiLiveEvent(type: GeminiLiveEventType.flashcards, raw: json);
      case 'interactive_graph':
        return GeminiLiveEvent(type: GeminiLiveEventType.interactiveGraph, raw: json);
      case 'mnemonic':
        return GeminiLiveEvent(type: GeminiLiveEventType.mnemonic, raw: json);
      case 'punnett_square':
        return GeminiLiveEvent(type: GeminiLiveEventType.punnettSquare, raw: json);
      default:
        // Fallback for unexpected types
        return GeminiLiveEvent(type: GeminiLiveEventType.error, error: 'Unknown event type: $typeStr', raw: json);
    }
  }
}


class GeminiLiveService {
  WebSocketChannel? _channel;
  final StreamController<GeminiLiveEvent> _eventController = StreamController<GeminiLiveEvent>.broadcast();
  final StreamController<Uint8List> _audioController = StreamController<Uint8List>.broadcast();
  
  Stream<GeminiLiveEvent> get events => _eventController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> connect(String url) async {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      developer.log('Gemini Live: Connected to $url', name: 'GeminiLiveService');
      
      _channel!.stream.listen(
        (message) {
          if (message is List<int>) {
            _audioController.add(Uint8List.fromList(message));
          } else if (message is String) {
            try {
              final json = jsonDecode(message);
              _eventController.add(GeminiLiveEvent.fromJson(json));
            } catch (e) {
              developer.log('Gemini Live: Error decoding JSON message: $e', name: 'GeminiLiveService');
              _eventController.add(GeminiLiveEvent(type: GeminiLiveEventType.error, error: 'JSON parse error: $e'));
            }
          }
        },
        onDone: () {
          final code = _channel?.closeCode;
          final reason = _channel?.closeReason;
          _isConnected = false;
          
          String errorMsg = _mapCloseCodeToMessage(code, reason);
          _eventController.add(GeminiLiveEvent(type: GeminiLiveEventType.error, error: errorMsg));
          developer.log('Gemini Live: Connection closed (code: $code, reason: $reason)', name: 'GeminiLiveService');
        },
        onError: (error) {
          _isConnected = false;
          _eventController.add(GeminiLiveEvent(type: GeminiLiveEventType.error, error: 'WebSocket error: $error'));
          developer.log('Gemini Live: WebSocket error: $error', name: 'GeminiLiveService');
        },
      );
    } catch (e) {
      _isConnected = false;
      _eventController.add(GeminiLiveEvent(type: GeminiLiveEventType.error, error: 'Failed to connect: $e'));
      developer.log('Gemini Live: Connection failure: $e', name: 'GeminiLiveService');
      rethrow;
    }
  }

  String _mapCloseCodeToMessage(int? code, String? reason) {
    if (code == null) return 'Connection lost unexpectedly';
    
    switch (code) {
      case 1000: return 'Session completed normally';
      case 1001: return 'Server is going away (restarting)';
      case 1002: return 'Protocol error in connection';
      case 1003: return 'Received incompatible data type';
      case 1007: return 'API Policy Violation (Check audio format or text injections)';
      case 1008: return 'Policy violation or authentication error';
      case 1009: return 'Message too large for the system';
      case 1011: return 'Internal server error (Gemini had a hiccup)';
      case 4000: return 'Rate limit exceeded for Gemini Live';
      default: 
        if (reason != null && reason.isNotEmpty) return 'Error $code: $reason';
        return 'Connection closed (Code: $code)';
    }
  }

  void sendAudio(Uint8List audioData) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(audioData);
    }
  }

  void sendVideoFrame(String base64Image) {
    if (_isConnected && _channel != null) {
      final message = jsonEncode({
        'type': 'video_frame',
        'data': 'data:image/jpeg;base64,$base64Image',
      });
      _channel!.sink.add(message);
    }
  }

  void sendText(String text) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(text);
    }
  }

  /// Sends a silent system context injection to the Live session.
  /// Used for: silence handler nudges, continuous context updates, navigation events.
  void sendSystemContext(String context) {
    if (_isConnected && _channel != null) {
      final message = jsonEncode({
        'type': 'system_injection',
        'text': context,
      });
      _channel!.sink.add(message);
    }
  }

  /// Sends a tool response back to the Gemini Live session after executing a function call.
  void sendToolResponse(String toolName, Map<String, dynamic> result) {
    if (_isConnected && _channel != null) {
      final message = jsonEncode({
        'type': 'tool_response',
        'name': toolName,
        'result': result,
      });
      _channel!.sink.add(message);
    }
  }

  void stop() {
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    stop();
    _eventController.close();
    _audioController.close();
  }
}
