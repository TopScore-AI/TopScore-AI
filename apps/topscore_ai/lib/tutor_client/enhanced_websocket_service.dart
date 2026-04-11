import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Added firebase_auth

import 'connection_manager.dart';
import 'offline_storage.dart';
import '../config/api_config.dart';

/// Enhanced WebSocket Service with retry logic, offline support, and audio queue
class EnhancedWebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final StreamController<bool> _isConnectedController =
      StreamController.broadcast();

  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;
  StreamSubscription<User?>? _authSubscription; // NEW: Track auth stream

  // Connection manager for state tracking and retry logic
  final ConnectionStateManager _connectionManager = ConnectionStateManager();

  // Offline storage for message caching
  final OfflineStorage _offlineStorage = OfflineStorage();
  final OfflineSyncManager _syncManager = OfflineSyncManager();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get isConnectedStream => _isConnectedController.stream;
  Stream<ConnectionState> get connectionStateStream =>
      _connectionManager.stateStream;

  bool get isConnected => _isConnected;
  ConnectionState get connectionState => _connectionManager.currentState;
  bool get hasInternet => _connectionManager.hasInternet;

  final String userId;
  String sessionId = const Uuid().v4();
  String threadId = const Uuid().v4();

  EnhancedWebSocketService({required this.userId}) {
    _initialize();
  }

  Future<void> _initialize() async {
    _connectionManager.initialize();
    await _offlineStorage.initialize();
    await _syncManager.initialize();

    // Listen for connectivity changes
    _connectionManager.stateStream.listen((state) {
      if (state == ConnectionState.reconnecting && hasInternet) {
        // Try to reconnect and sync pending messages
        connect();
      }
    });

    // NEW: Listen for Firebase token rotation to keep session alive
    _authSubscription =
        FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
      if (user != null && _channel != null && _isConnected) {
        try {
          final newToken = await user.getIdToken();
          if (newToken != null) {
            final payload = {"type": "token_refresh", "auth_token": newToken};
            _channel?.sink.add(jsonEncode(payload));
          }
        } catch (e) {
          if (kDebugMode) debugPrint('WebSocket token refresh error: $e');
        }
      }
    });

    // Start connection immediately
    connect();
  }

  String get _wsUrl {
    // Clean up ApiConfig.wsUrl
    var base = ApiConfig.wsUrl;
    // Remove trailing slash if present
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    // Backend expects /ws/chat/{session_id}
    // If ApiConfig.wsUrl already ends in /ws, we don't want /ws/ws/chat
    if (base.endsWith('/ws')) {
      return '$base/chat/$sessionId?user_id=$userId';
    } else {
      return '$base/ws/chat/$sessionId?user_id=$userId';
    }
  }

  void setThreadId(String newThreadId) => threadId = newThreadId;
  void setSessionId(String newSessionId) => sessionId = newSessionId;

  /// Connect with automatic retry and offline fallback
  Future<void> connect() async {
    if (_isConnected && _channel != null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _connectionManager.setDisconnected();
      return;
    }

    if (!hasInternet) {
      _connectionManager.setDisconnected();
      return;
    }

    _connectionManager.setConnecting();
    String? idToken;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        idToken = await user.getIdToken(false);
      } catch (e) {
        if (kDebugMode) debugPrint('WebSocket: Failed to get auth token: $e');
        // Continue anyway, backend may allow limited access or fallback to guest
      }
    }

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      if (idToken != null) {
        final handshakePayload = {
          "type": "init",
          "auth_token": idToken,
          "thread_id": threadId,
        };
        _channel!.sink.add(jsonEncode(handshakePayload));
      }

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _handleIncomingMessage(data);
          } catch (e) {
            if (kDebugMode) debugPrint('WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint('WebSocket: Connection error: $error');
          _handleDisconnection();
        },
        onDone: () {
          _handleDisconnection();
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('WebSocket: Failed to connect: $e');
      _isConnected = false;
      _isConnectedController.add(false);
      _connectionManager.setDisconnected();
      _scheduleReconnect();
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'connected':
        _isConnected = true;
        _reconnectAttempts = 0;
        _isConnectedController.add(true);
        _connectionManager.setConnected();
        _startKeepAliveTimer();
        _syncPendingMessages();
        break;

      case 'ping':
        _sendPong();
        break;

      case 'response':
        _cacheMessage(data);
        _messageController.add(data);
        break;

      default:
        _messageController.add(data);
    }
  }

  /// Send message with offline fallback
  Future<void> sendMessage({
    required String message,
    required String userId,
    String? threadId,
    String? modelPreference,
    List<String>? fileUrls,
    String? fileType,
    String? imageData,
    bool dataSaver = false,
    String? replyToId,
    String? replyToText,
    Map<String, dynamic>? extraData,
  }) async {
    final messageId = const Uuid().v4();
    final targetThreadId = threadId ?? this.threadId;

    final data = {
      "type": "message",
      "message_id": messageId,
      "message": message,
      "user_id": userId,
      "thread_id": targetThreadId,
      "model_preference": modelPreference ?? "smart",
      "data_saver": dataSaver,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      if (fileUrls != null && fileUrls.isNotEmpty) 'file_urls': fileUrls,
      if (fileUrls != null && fileUrls.isNotEmpty) 'file_url': fileUrls.first,
      if (fileType != null) 'file_type': fileType,
      if (imageData != null) 'image_data': imageData,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
      ...?extraData,
    };

    if (!_isConnected || _channel == null) {
      await _offlineStorage.savePendingMessage(
        PendingMessage(
          id: messageId,
          threadId: targetThreadId,
          userId: userId,
          content: message,
          createdAt: DateTime.now(),
          extraData: data,
        ),
      );
      // Still emit it locally for UI
      _messageController.add({
        'type': 'queued',
        'message_id': messageId,
        'message': message,
        'pending': true,
      });
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending message: $e');
      await _offlineStorage.savePendingMessage(
        PendingMessage(
          id: messageId,
          threadId: targetThreadId,
          userId: userId,
          content: message,
          createdAt: DateTime.now(),
          extraData: data,
        ),
      );
    }
  }

  /// Send real-time audio from TopScore AI mode
  void sendTopScoreAudioMessage({
    required String base64Audio,
    required String mimeType,
  }) {
    if (!_isConnected || _channel == null) return;

    try {
      final data = {
        "type": "audio",
        "audio": base64Audio,
        "mime_type": mimeType,
      };
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending audio message: $e');
    }
  }

  /// Send a raw JSON payload — used for control messages like stop
  void sendRaw(Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending raw message: $e');
    }
  }

  /// Sync pending messages when connection is restored
  Future<void> _syncPendingMessages() async {
    if (!_isConnected) return;

    final result = await _syncManager.syncPendingMessages(
      sendMessage: (pending) async {
        try {
          final data = pending.extraData ??
              {
                "type": "message",
                "message_id": pending.id,
                "message": pending.content,
                "user_id": pending.userId,
                "thread_id": pending.threadId,
                "timestamp": pending.createdAt.millisecondsSinceEpoch,
              };
          _channel!.sink.add(jsonEncode(data));
          return true;
        } catch (e) {
          return false;
        }
      },
    );

    if (result.synced > 0) {
      _messageController.add({
        'type': 'sync_complete',
        'synced': result.synced,
        'failed': result.failed,
      });
    }
  }

  /// Cache a message locally
  Future<void> _cacheMessage(Map<String, dynamic> data) async {
    final id = data['message_id'] ?? const Uuid().v4();
    final content = data['content'] ?? data['message'] ?? '';
    final role = data['role'] ?? 'assistant';

    await _offlineStorage.cacheMessage(
      CachedMessage(
        id: id,
        threadId: threadId,
        content: content,
        role: role,
        timestamp: DateTime.now(),
        synced: true,
      ),
    );
  }

  /// Get cached messages for offline display
  Future<List<CachedMessage>> getCachedMessages() async {
    return _offlineStorage.getCachedMessages(threadId);
  }

  /// Get pending messages count
  Future<int> getPendingMessagesCount() async {
    final pending = await _offlineStorage.getPendingMessages();
    return pending.length;
  }

  void _sendPong() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({'type': 'pong'}));
    }
  }

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          if (kDebugMode) debugPrint('Keep-alive failed: $e');
          _handleDisconnection();
        }
      } else {
        _keepAliveTimer?.cancel();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    if (_reconnectAttempts < _maxReconnectAttempts) {
      // Exponential backoff with jitter: min(60s, 2^attempt * 1s) + random(0–1s)
      final baseSeconds = (1 << _reconnectAttempts).clamp(1, 60);
      final jitterMs = (baseSeconds *
              1000 *
              0.2 *
              (DateTime.now().millisecondsSinceEpoch % 100) /
              100)
          .round();
      final delayMs = baseSeconds * 1000 + jitterMs;
      _connectionManager.setReconnecting();
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(milliseconds: delayMs), connect);
      if (kDebugMode) {
        debugPrint(
            'WebSocket: reconnect attempt $_reconnectAttempts in ${delayMs}ms');
      }
    } else {
      _connectionManager.setDisconnected();
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _isConnectedController.add(false);
    _connectionManager.setDisconnected();
    _scheduleReconnect();
  }

  void resetConnection() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    connect();
  }

  /// Pause timers and close the channel without destroying the service.
  /// Called when the app goes to background. Call [connect] to resume.
  void pause() {
    _keepAliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnectedController.add(false);
  }

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    _authSubscription?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _isConnectedController.close();
    _connectionManager.dispose();
  }
}
