import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

enum GeminiLiveState {
  disconnected,
  connecting,
  connected,
  listening,
  aiSpeaking,
  error,
}

class GeminiLiveService {
  // Constants for Audio Configuration
  static const int _sampleRate = 16000;
  static const String _audioMimeType = 'audio/pcm;rate=$_sampleRate';

  static const String _geminiWsBase =
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent';

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;

  String? _accessToken;
  String? _voiceName;
  String? _systemInstruction;
  List<Map<String, dynamic>>? _tools;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  bool _disposed = false;
  bool _setupComplete = false;

  // Streams exposed to consumers
  final _audioOutController = StreamController<Uint8List>.broadcast();
  final _textController = StreamController<String>.broadcast();
  final _stateController = StreamController<GeminiLiveState>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _toolCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _actionController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Uint8List> get audioOutputStream => _audioOutController.stream;
  Stream<String> get textStream => _textController.stream;
  Stream<GeminiLiveState> get stateStream => _stateController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<Map<String, dynamic>> get toolCallStream => _toolCallController.stream;
  Stream<Map<String, dynamic>> get actionStream => _actionController.stream;

  GeminiLiveState _state = GeminiLiveState.disconnected;
  GeminiLiveState get state => _state;

  // Buffer for accumulating audio chunks per turn
  final List<int> _audioBuffer = [];

  void _setState(GeminiLiveState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Fetch an ephemeral token from the backend.
  Future<String> fetchEphemeralToken(String firebaseIdToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.geminiLiveTokenUrl),
        headers: {'Authorization': 'Bearer $firebaseIdToken'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch Gemini Live token: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String;
    } catch (e) {
      debugPrint('[GeminiLive] Token fetch error: $e');
      rethrow;
    }
  }

  /// Connect to Gemini Live API.
  Future<void> connect({
    required String firebaseIdToken,
    String voiceName = 'Puck',
    String? systemInstruction,
    List<Map<String, dynamic>>? tools,
  }) async {
    if (_disposed) return;

    // Cancel any pending reconnects to avoid race conditions
    _reconnectTimer?.cancel();

    _voiceName = voiceName;
    _systemInstruction = systemInstruction;
    _tools = tools;
    _setState(GeminiLiveState.connecting);

    try {
      _accessToken = await fetchEphemeralToken(firebaseIdToken);

      final wsUri = Uri.parse('$_geminiWsBase?access_token=$_accessToken');

      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      _setupComplete = false;
      _listenToChannel();
      _sendSetupMessage();

      _reconnectAttempts = 0;
      _setState(GeminiLiveState.connected);

      debugPrint('[GeminiLive] WebSocket Connected');
    } catch (e) {
      debugPrint('[GeminiLive] Connection failed: $e');
      _setState(GeminiLiveState.error);
      _scheduleReconnect(firebaseIdToken);
    }
  }

  /// IMPORTANT: Google JSON API expects camelCase keys, not snake_case.
  void _sendSetupMessage() {
    final setup = <String, dynamic>{
      'setup': {
        'model': 'models/gemini-2.0-flash-exp',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': _voiceName ?? 'Puck',
              },
            },
          },
        },
      },
    };

    if (_tools != null && _tools!.isNotEmpty) {
      final setupMap = setup['setup'] as Map<String, dynamic>;
      setupMap['tools'] = _tools;
    }

    if (_systemInstruction != null && _systemInstruction!.isNotEmpty) {
      // Accessing deeply nested maps safely
      final setupMap = setup['setup'] as Map<String, dynamic>;
      setupMap['systemInstruction'] = {
        'parts': [
          {'text': _systemInstruction},
        ],
      };
    }

    _sendJson(setup);
    debugPrint('[GeminiLive] Setup message sent');
  }

  void _listenToChannel() {
    _channelSub?.cancel();
    _channelSub = _channel?.stream.listen(
      (message) => _handleMessage(message),
      onError: (error) {
        debugPrint('[GeminiLive] WebSocket stream error: $error');
        _setState(GeminiLiveState.error);
        // Depending on the error, you might want to trigger reconnect here
      },
      onDone: () {
        debugPrint('[GeminiLive] WebSocket closed by server');
        if (!_disposed) {
          _setState(GeminiLiveState.disconnected);
        }
      },
    );
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final String jsonString = rawMessage is String
          ? rawMessage
          : utf8.decode(rawMessage as List<int>);

      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // 1. Handle Setup Completion
      if (data.containsKey('setupComplete')) {
        _setupComplete = true;
        _setState(GeminiLiveState.listening);
        debugPrint('[GeminiLive] Setup complete');
        return;
      }

      // 2. Handle Server Content (Model Response)
      if (data.containsKey('serverContent')) {
        _handleServerContent(data['serverContent'] as Map<String, dynamic>);
        return;
      }

      // 3. Handle Tool Call
      if (data.containsKey('toolCall')) {
        final toolCall = data['toolCall'] as Map<String, dynamic>;
        final functionCalls = toolCall['functionCalls'] as List<dynamic>?;
        if (functionCalls != null) {
          for (final call in functionCalls) {
            _handleToolCall(call as Map<String, dynamic>);
          }
        }
      }
    } catch (e) {
      debugPrint('[GeminiLive] Error parsing message: $e');
    }
  }

  void _handleServerContent(Map<String, dynamic> content) {
    final turnComplete = content['turnComplete'] as bool? ?? false;
    final interrupted = content['interrupted'] as bool? ?? false;

    // Handle Interruption (User spoke while AI was speaking)
    if (interrupted) {
      debugPrint('[GeminiLive] Interrupted');
      _audioBuffer.clear();
      _setState(GeminiLiveState.listening);
      // Logic to stop audio player should be triggered in UI via state change
      return;
    }

    final modelTurn = content['modelTurn'] as Map<String, dynamic>?;

    if (modelTurn != null) {
      final parts = modelTurn['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          final partMap = part as Map<String, dynamic>;

          // A. Handle Audio
          if (partMap.containsKey('inlineData')) {
            if (_state != GeminiLiveState.aiSpeaking) {
              _setState(GeminiLiveState.aiSpeaking);
            }

            final inlineData = partMap['inlineData'] as Map<String, dynamic>;
            final b64Data = inlineData['data'] as String;
            final audioBytes = base64Decode(b64Data);

            _audioBuffer.addAll(audioBytes);

            if (!_audioOutController.isClosed) {
              _audioOutController.add(Uint8List.fromList(audioBytes));
            }
          }

          // B. Handle Text (Captions/Logs)
          if (partMap.containsKey('text')) {
            final text = partMap['text'] as String;

            // Extract [ACTION: TYPE args]
            final actionMatch =
                RegExp(r'\[ACTION:\s*(\w+)\s+([^\]]*)\]').firstMatch(text);
            if (actionMatch != null) {
              final type = actionMatch.group(1);
              final args = actionMatch.group(2);
              if (!_actionController.isClosed) {
                _actionController.add({'type': type, 'args': args});
              }
            }

            if (!_textController.isClosed) {
              _textController.add(text);
            }
          }
        }
      }
    }

    if (turnComplete) {
      if (_audioBuffer.isNotEmpty && !_transcriptController.isClosed) {
        _transcriptController.add('[Turn Complete]');
      }
      _audioBuffer.clear();
      // We don't necessarily switch back to 'listening' immediately if we want
      // to keep the "AI Speaking" UI active until the audio buffer finishes playing.
      // But for protocol state:
      _setState(GeminiLiveState.listening);
    }
  }

  void _handleToolCall(Map<String, dynamic> toolCall) {
    debugPrint('[GeminiLive] Tool Call Received: $toolCall');
    if (!_toolCallController.isClosed) {
      _toolCallController.add(toolCall);
    }
  }

  /// Sends tool outputs back to the model.
  void sendToolResponse(List<Map<String, dynamic>> toolResponses) {
    if (_channel == null || !_setupComplete || _disposed) return;

    final message = {
      'toolResponse': {
        'functionResponses': toolResponses,
      },
    };

    _sendJson(message);
    debugPrint('[GeminiLive] Tool response sent');
  }

  /// Send PCM audio chunk to Gemini.
  /// Ensure [pcmChunk] is 16kHz, 1 channel (Mono), Little Endian PCM.
  void sendAudio(Uint8List pcmChunk) {
    if (_channel == null || !_setupComplete || _disposed) return;

    final b64 = base64Encode(pcmChunk);

    final message = {
      'realtimeInput': {
        'mediaChunks': [
          {
            'data': b64,
            'mimeType': _audioMimeType,
          },
        ],
      },
    };

    _sendJson(message);
  }

  /// Send a text message (user typing instead of speaking).
  void sendText(String text) {
    if (_channel == null || !_setupComplete || _disposed) return;

    final message = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    };

    _sendJson(message);
  }

  void _sendJson(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('[GeminiLive] WebSocket Send Error: $e');
      _setState(GeminiLiveState.error);
    }
  }

  void _scheduleReconnect(String firebaseIdToken) {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) {
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        debugPrint('[GeminiLive] Max reconnect attempts reached');
        _setState(GeminiLiveState.error);
      }
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 16));
    debugPrint('[GeminiLive] Reconnecting in ${delay.inSeconds}s...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect(
        firebaseIdToken: firebaseIdToken,
        voiceName: _voiceName ?? 'Puck',
        systemInstruction: _systemInstruction,
        tools: _tools,
      );
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _channelSub?.cancel();

    // Send a standard close code (1000 = Normal Closure)
    await _channel?.sink.close(1000);

    _channel = null;
    _setupComplete = false;
    _audioBuffer.clear();
    _setState(GeminiLiveState.disconnected);
    debugPrint('[GeminiLive] Disconnected');
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _audioOutController.close();
    _textController.close();
    _stateController.close();
    _transcriptController.close();
    _toolCallController.close();
    _actionController.close();
  }
}
