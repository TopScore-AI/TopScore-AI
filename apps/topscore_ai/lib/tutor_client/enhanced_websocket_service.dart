import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Added firebase_auth

import 'connection_manager.dart';
import 'offline_storage.dart';
import '../config/app_config.dart';

/// Enhanced WebSocket Service with retry logic, offline support, and audio queue
class EnhancedWebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final StreamController<bool> _isConnectedController =
      StreamController.broadcast();

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _lastHasInternet = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  bool _isHandshakeSent = false;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;
  Timer? _pongTimeoutTimer;
  Timer? _connectingGuardTimer;
  Timer? _watchdogTimer;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<ConnectionState>? _connectionStateSub;
  final Random _random = Random();
  Completer<void>? _authenticatedCompleter;

  static const Duration _pongTimeout = Duration(seconds: 10);
  static const Duration _connectingGuard = Duration(seconds: 15);
  static const Duration _watchdogInterval = Duration(seconds: 60);

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
  String? userName;
  String sessionId = const Uuid().v4();
  String threadId = const Uuid().v4();

  EnhancedWebSocketService({required this.userId});

  /// Initialize storage, connectivity listeners, and auth stream. Must be
  /// awaited before [connect] or [sendMessage] are used.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _connectionManager.initialize();
    await _offlineStorage.initialize();
    await _syncManager.initialize();

    _lastHasInternet = _connectionManager.hasInternet;

    // React to connectivity transitions: when internet returns, resume.
    _connectionStateSub = _connectionManager.stateStream.listen((state) {
      if (_isDisposed || _isPaused) return;
      final hasNet = _connectionManager.hasInternet;
      final regained = !_lastHasInternet && hasNet;
      _lastHasInternet = hasNet;

      if (regained) {
        // Always reset attempts when net comes back, even if we previously
        // hit the max and gave up. This is the user's cue that the network
        // changed and a retry might now succeed.
        _reconnectAttempts = 0;
        if (!_isConnected && !_isConnecting) {
          connect();
        }
        return;
      }
      if (state == ConnectionState.reconnecting &&
          hasNet &&
          !_isConnected &&
          !_isConnecting) {
        connect();
      }
    });

    _authSubscription =
        FirebaseAuth.instance.idTokenChanges().listen((User? user) async {
      if (user != null && _channel != null) {
        try {
          final newToken = await user.getIdToken();
          if (newToken != null) {
            if (_isConnected) {
              // Already authenticated, just refreshing
              final payload = {"type": "token_refresh", "auth_token": newToken};
              _channel?.sink.add(jsonEncode(payload));
            } else if (!_isHandshakeSent) {
              // Channel is open but we haven't sent the initial handshake yet
              _sendHandshake(newToken);
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('WebSocket token refresh error: $e');
        }
      }
    });
  }

  String get _wsUrl {
    // Clean up AppConfig.wsUrl
    var base = AppConfig.wsUrl;
    // Remove trailing slash if present
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    // Backend expects /ws/chat/{session_id}
    // If AppConfig.wsUrl already ends in /ws, we don't want /ws/ws/chat
    if (base.endsWith('/ws')) {
      return '$base/chat/$sessionId?user_id=$userId';
    } else {
      return '$base/ws/chat/$sessionId?user_id=$userId';
    }
  }

  void setThreadId(String newThreadId) => threadId = newThreadId;
  void setSessionId(String newSessionId) => sessionId = newSessionId;

  /// Connect with automatic retry and offline fallback. Safe to call
  /// repeatedly — concurrent calls coalesce.
  Future<void> connect() async {
    if (_isDisposed || _isPaused) return;
    if (!_isInitialized) {
      if (kDebugMode) {
        debugPrint(
            'WebSocket: connect() called before initialize() — ignoring');
      }
      return;
    }
    if (_isConnected && _channel != null) return;
    if (_isConnecting) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _connectionManager.setDisconnected();
      return;
    }

    if (!hasInternet) {
      _connectionManager.setDisconnected();
      return;
    }

    _isConnecting = true;
    _connectionManager.setConnecting();
    _authenticatedCompleter = Completer<void>();
    _isHandshakeSent = false;

    // Safety net: if connect() hangs mid-flight (token fetch stalled, channel
    // open never resolves), force-clear the guard so future connect() calls
    // aren't permanently blocked. Independent of the OS-level connect timeout.
    _connectingGuardTimer?.cancel();
    _connectingGuardTimer = Timer(_connectingGuard, () {
      if (_isConnecting && !_isConnected) {
        if (kDebugMode) {
          debugPrint('WebSocket: connecting guard fired — forcing reconnect');
        }
        _isConnecting = false;
        _handleDisconnection();
      }
    });

    // Close any orphaned channel from a previous attempt before opening a new one.
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    String? idToken;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        if (kDebugMode) {
          debugPrint('WebSocket: Fetching fresh Firebase ID Token...');
        }
        idToken = await user.getIdToken(false);
        if (kDebugMode) {
          debugPrint('WebSocket: Token fetched (length: ${idToken?.length})');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('WebSocket: Failed to get auth token: $e');
        }
      }
    }

    try {
      final uri = Uri.parse(_wsUrl);
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // Attach stream listener FIRST so any async errors arriving before
      // ready/handshake completes are captured by onError instead of escaping
      // to the zone as a fatal WebSocketChannelException.
      channel.stream.listen(
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
          if (identical(_channel, channel)) {
            _handleDisconnection();
          }
        },
        onDone: () {
          if (identical(_channel, channel)) {
            _handleDisconnection();
          }
        },
        cancelOnError: true,
      );

      // Handle async connection errors from the ready future to prevent top-level crashes
      channel.ready.then((_) {
        if (!identical(_channel, channel)) return;
        if (idToken != null) {
          if (kDebugMode) {
            debugPrint('WebSocket: ready, sending handshake with token...');
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                'WebSocket: ready, sending handshake with identity: $userId');
          }
        }
        _sendHandshake(idToken);
      }).catchError((error) {
        if (kDebugMode) {
          debugPrint('WebSocket: connection ready error: $error');
        }
        if (identical(_channel, channel)) {
          _handleDisconnection();
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('WebSocket: Failed to connect: $e');
      _isConnected = false;
      if (!_isConnectedController.isClosed) {
        _isConnectedController.add(false);
      }
      _connectionManager.setDisconnected();
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _sendHandshake(String? token) {
    if (_channel == null) {
      if (kDebugMode) {
        debugPrint('WebSocket: Cannot send handshake, channel is null');
      }
      return;
    }
    if (_isHandshakeSent) {
      if (kDebugMode) {
        debugPrint('WebSocket: Handshake already sent, skipping duplicate');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('WebSocket: Preparing init handshake for user $userId...');
      }
      final handshakePayload = {
        "type": "init",
        "user_id": userId,
        "thread_id": threadId,
        if (token != null) "auth_token": token,
      };
      final encoded = jsonEncode(handshakePayload);
      if (kDebugMode) {
        debugPrint('WebSocket: Sending init payload to sink...');
      }
      _channel!.sink.add(encoded);
      _isHandshakeSent = true;
      if (kDebugMode) {
        debugPrint('WebSocket: Init handshake sent successfully');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('WebSocket: Error sending handshake: $e\n$stack');
      }
    }
  }

  void _markConnected() {
    if (_isConnected) return;
    _isConnected = true;
    _reconnectAttempts = 0;
    _connectingGuardTimer?.cancel();
    _watchdogTimer?.cancel();
    if (!_isDisposed && !_isConnectedController.isClosed) {
      _isConnectedController.add(true);
    }
    _connectionManager.setConnected();
    _startKeepAliveTimer();
    _syncPendingMessages();
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    if (_isDisposed || _messageController.isClosed) return;
    final type = data['type'];

    // Any message from the server is a liveness signal — half-open TCP can't
    // deliver bytes. Reset the pong watchdog regardless of message type.
    _pongTimeoutTimer?.cancel();

    if (type == 'pong') {
      // Server-acknowledged keep-alive. Don't surface to UI.
      return;
    }

    switch (type) {
      case 'connected':
        // Transport established, but wait for 'authenticated' before marking ready
        if (kDebugMode) {
          debugPrint(
              'WebSocket: Transport connected (session: ${data['session_id']}), waiting for auth...');
        }
        break;

      case 'system':
        if (data['status'] == 'authenticated') {
          if (kDebugMode) {
            debugPrint('WebSocket: Session authenticated successfully.');
          }
          _markConnected();
          if (_authenticatedCompleter != null &&
              !_authenticatedCompleter!.isCompleted) {
            _authenticatedCompleter!.complete();
          }
        } else {
          _messageController.add(data);
        }
        break;

      case 'ping':
        _sendPong();
        break;

      // ─── STREAMING AI RESPONSE HANDLING ───────────────────────────────────
      case 'response_start':
        // Marks the beginning of a streaming response
        if (kDebugMode) {
          debugPrint(
              'WebSocket: Streaming response started (id: ${data['id']})');
        }
        _messageController.add(data);
        break;

      case 'chunk':
        // Incremental text content from AI
        _messageController.add(data);
        break;

      case 'table':
        // Table content (formatted separately)
        _messageController.add(data);
        break;

      case 'tool_call':
        // AI is using a tool (e.g., search, in-app browser)
        if (kDebugMode) {
          debugPrint('WebSocket: Tool call - ${data['tool']}');
        }
        _messageController.add(data);
        break;

      case 'status':
        // Status updates (e.g., "Thinking...", "Analyzing...")
        _messageController.add(data);
        break;

      case 'done':
        // End of streaming response
        if (kDebugMode) {
          debugPrint('WebSocket: Streaming response completed');
        }
        // Cache the complete message if available
        if (data.containsKey('full_response')) {
          _cacheMessage(data);
        }
        _messageController.add(data);
        break;

      case 'error':
        // Error during streaming
        if (kDebugMode) {
          debugPrint('WebSocket: Streaming error - ${data['content']}');
        }
        _messageController.add(data);
        break;

      case 'is_kicd_certified':
        // KICD certification flag for curriculum-verified content
        _messageController.add(data);
        break;

      // ─── LEGACY RESPONSE HANDLING ─────────────────────────────────────────
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
    String? userName,
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
      if (userName != null) "user_name": userName,
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
      if (!_isDisposed && !_messageController.isClosed) {
        _messageController.add({
          'type': 'queued',
          'message_id': messageId,
          'message': message,
          'pending': true,
        });
      }
      return;
    }

    try {
      if (_isDisposed) return;
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

  /// Send a raw JSON payload — used for control messages like stop. Dropped
  /// silently when offline (the server-side generation isn't running anyway).
  void sendRaw(Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null) {
      if (kDebugMode) {
        debugPrint(
            'WebSocket: sendRaw dropped (disconnected): ${payload['type']}');
      }
      return;
    }
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
          // Arm a pong-timeout — if the server doesn't reply (or any other
          // message doesn't arrive) within _pongTimeout, treat the socket as
          // half-open and reconnect. Resets on any incoming message.
          _pongTimeoutTimer?.cancel();
          _pongTimeoutTimer = Timer(_pongTimeout, () {
            if (!_isConnected) return;
            if (kDebugMode) {
              debugPrint(
                  'WebSocket: pong timeout — connection appears half-open');
            }
            _handleDisconnection();
          });
        } catch (e) {
          if (kDebugMode) debugPrint('Keep-alive failed: $e');
          _handleDisconnection();
        }
      } else {
        _keepAliveTimer?.cancel();
      }
    });
  }

  /// Watchdog: when we've exhausted reconnect attempts, keep periodically
  /// retrying at a slow cadence instead of giving up forever. Cancelled as
  /// soon as we reconnect or net-regain triggers a fresh attempt.
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      if (_isDisposed || _isPaused) {
        _watchdogTimer?.cancel();
        return;
      }
      if (_isConnected || _isConnecting) {
        _watchdogTimer?.cancel();
        return;
      }
      if (!hasInternet) return;
      if (kDebugMode) {
        debugPrint('WebSocket: watchdog retry after max attempts');
      }
      _reconnectAttempts = 0;
      connect();
    });
  }

  void _scheduleReconnect() {
    if (_isDisposed || _isPaused) return;
    _reconnectAttempts++;
    if (_reconnectAttempts < _maxReconnectAttempts) {
      // Exponential backoff: min(60s, 2^attempt * 1s) + up-to-20% random jitter.
      final baseSeconds = (1 << _reconnectAttempts).clamp(1, 60);
      final maxJitterMs = (baseSeconds * 1000 * 0.2).toInt();
      final jitterMs = maxJitterMs > 0 ? _random.nextInt(maxJitterMs + 1) : 0;
      final delayMs = baseSeconds * 1000 + jitterMs;
      _connectionManager.setReconnecting();
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
        if (_isDisposed || _isPaused) return;
        connect();
      });
      if (kDebugMode) {
        debugPrint(
            'WebSocket: reconnect attempt $_reconnectAttempts in ${delayMs}ms');
      }
    } else {
      _connectionManager.setDisconnected();
      // Don't give up forever. Start the slow-cadence watchdog so a future
      // server recovery, OS network change, or proxy fix gets a retry.
      _startWatchdog();
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _pongTimeoutTimer?.cancel();
    _keepAliveTimer?.cancel();
    _connectingGuardTimer?.cancel();
    _isConnecting = false;
    if (!_isConnectedController.isClosed) {
      _isConnectedController.add(false);
    }
    _connectionManager.setDisconnected();
    if (_isDisposed || _isPaused) return;
    _scheduleReconnect();
  }

  /// Resume after [pause] and force a fresh connect.
  void resume() {
    if (_isDisposed) return;
    _isPaused = false;
    _reconnectAttempts = 0;
    connect();
  }

  void resetConnection() {
    if (_isDisposed) return;
    _isPaused = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    connect();
  }

  /// Pause timers and close the channel without destroying the service.
  /// Reconnects scheduled by onDone/onError are suppressed until [resume]
  /// (or [connect]/[resetConnection]) is called.
  void pause() {
    _isPaused = true;
    _keepAliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _connectingGuardTimer?.cancel();
    _watchdogTimer?.cancel();
    final channel = _channel;
    _channel = null;
    try {
      channel?.sink.close();
    } catch (_) {}
    _isConnected = false;
    if (!_isConnectedController.isClosed) {
      _isConnectedController.add(false);
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _isPaused = true;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _connectingGuardTimer?.cancel();
    _watchdogTimer?.cancel();
    await _authSubscription?.cancel();
    await _connectionStateSub?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (!_messageController.isClosed) await _messageController.close();
    if (!_isConnectedController.isClosed) await _isConnectedController.close();
    // Note: _connectionManager is a process-wide singleton — do not dispose it
    // here, otherwise its broadcast stream becomes unusable for the rest of
    // the app session.
  }
}
