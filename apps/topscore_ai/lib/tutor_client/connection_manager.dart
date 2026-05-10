import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Connection states for the app
enum ConnectionState {
  connected,
  connecting,
  disconnected,
  reconnecting,
  offline, // No internet
}

/// Manages connection state and provides retry logic
class ConnectionStateManager {
  static final ConnectionStateManager _instance =
      ConnectionStateManager._internal();
  factory ConnectionStateManager() => _instance;
  ConnectionStateManager._internal();

  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();

  ConnectionState _currentState = ConnectionState.disconnected;
  bool _hasInternet = true;
  StreamSubscription? _connectivitySubscription;
  Timer? _reachabilityTimer;
  DateTime? _lastCheckTime;
  bool _isChecking = false;

  // Per-source connectivity. The aggregated state is "connected" if either
  // is up; we only flip to offline when reachability actively fails.
  bool _chatUp = false;
  bool _voiceUp = false;

  Stream<ConnectionState> get stateStream => _stateController.stream;
  ConnectionState get currentState => _currentState;
  bool get hasInternet => _hasInternet;
  bool get isConnected => _currentState == ConnectionState.connected;
  bool get chatUp => _chatUp;
  bool get voiceUp => _voiceUp;

  /// Initialize the connection state manager
  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      // Only check reachability, don't trigger reconnections
      forceCheck();
    });

    // Check connectivity every 60 seconds (reduced from 30s)
    _reachabilityTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => forceCheck());
    forceCheck();
  }

  /// Active check to see if we actually have internet reachability
  Future<bool> checkReachability() async {
    try {
      if (kIsWeb) {
        // On Web, active health checks to the backend often fail due to CORS
        // during local development, leading to false 'offline' states.
        // We rely on the hardware connectivity check instead.
        return true;
      }

      // Try multiple hosts to avoid false negatives if one DNS is slow
      final hosts = ['google.com', 'agent.topscoreapp.ai'];
      for (final host in hosts) {
        try {
          final result = await InternetAddress.lookup(host)
              .timeout(const Duration(seconds: 3));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Manually trigger a reachability check and state update
  Future<void> forceCheck() async {
    if (_isChecking) return;

    final now = DateTime.now();
    // Increased debounce from 5s to 10s to reduce check frequency
    if (_lastCheckTime != null &&
        now.difference(_lastCheckTime!).inSeconds < 10) {
      return;
    }

    _isChecking = true;
    _lastCheckTime = now;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasHardware = connectivity.any((r) => r != ConnectivityResult.none);

      if (!hasHardware && !kIsWeb) {
        // On Web, assume hardware is present if we are on localhost
        _hasInternet = false;
        _updateState(ConnectionState.offline);
        return;
      }

      final isReachable = await checkReachability();
      _hasInternet = isReachable;

      if (!isReachable) {
        _updateState(ConnectionState.offline);
      } else if (_chatUp || _voiceUp) {
        _updateState(ConnectionState.connected);
      }
      // REMOVED: Auto-transition to reconnecting state
      // Let the WebSocket service handle reconnection logic
    } finally {
      _isChecking = false;
    }
  }

  void _updateState(ConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  /// Recompute aggregate state from _chatUp/_voiceUp, respecting reachability.
  void _recomputeAggregate({bool transitioningDown = false}) {
    if (!_hasInternet) {
      _updateState(ConnectionState.offline);
      return;
    }
    if (_chatUp || _voiceUp) {
      _updateState(ConnectionState.connected);
    } else if (transitioningDown ||
        _currentState == ConnectionState.connecting) {
      // If we were connecting and failed, or were connected and dropped, move to reconnecting
      _updateState(ConnectionState.reconnecting);
    } else {
      _updateState(ConnectionState.disconnected);
    }
  }

  /// Chat socket reports its state. Preferred over setConnected/setDisconnected.
  void setChatConnected(bool up) {
    final was = _chatUp;
    _chatUp = up;
    _recomputeAggregate(transitioningDown: was && !up);
  }

  /// Voice socket reports its state.
  void setVoiceConnected(bool up) {
    final was = _voiceUp;
    _voiceUp = up;
    _recomputeAggregate(transitioningDown: was && !up);
  }

  // Backward-compatible API — all existing callers are chat paths.
  void setConnected() => setChatConnected(true);
  void setConnecting() {
    if (_chatUp || _voiceUp) return;
    _updateState(ConnectionState.connecting);
  }

  void setDisconnected() => setChatConnected(false);
  void setReconnecting() {
    if (_chatUp || _voiceUp) return;
    _updateState(ConnectionState.reconnecting);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _reachabilityTimer?.cancel();
    _stateController.close();
  }
}

/// Retry configuration
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });

  Duration getDelay(int attempt) {
    final delay = initialDelay * (backoffMultiplier * attempt);
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Handles retry logic with exponential backoff
class RetryHandler<T> {
  final RetryConfig config;
  final Future<T> Function() operation;
  final bool Function(Object error)? shouldRetry;
  final void Function(int attempt, Object error)? onRetry;

  int _currentAttempt = 0;
  bool _cancelled = false;

  RetryHandler({
    required this.operation,
    this.config = const RetryConfig(),
    this.shouldRetry,
    this.onRetry,
  });

  /// Execute the operation with retry logic
  Future<T> execute() async {
    _cancelled = false;
    _currentAttempt = 0;

    while (!_cancelled) {
      try {
        _currentAttempt++;
        return await operation();
      } catch (error) {
        if (_cancelled) rethrow;

        final canRetry = shouldRetry?.call(error) ?? true;

        if (!canRetry || _currentAttempt >= config.maxAttempts) {
          rethrow;
        }

        onRetry?.call(_currentAttempt, error);

        final delay = config.getDelay(_currentAttempt);
        await Future.delayed(delay);
      }
    }

    throw Exception('Retry cancelled');
  }

  void cancel() {
    _cancelled = true;
  }

  int get currentAttempt => _currentAttempt;
}

/// Message queue for offline support
class OfflineMessageQueue {
  static final OfflineMessageQueue _instance = OfflineMessageQueue._internal();
  factory OfflineMessageQueue() => _instance;
  OfflineMessageQueue._internal();

  final List<QueuedMessage> _queue = [];
  final StreamController<int> _queueSizeController =
      StreamController<int>.broadcast();

  Stream<int> get queueSizeStream => _queueSizeController.stream;
  int get queueSize => _queue.length;
  bool get hasQueuedMessages => _queue.isNotEmpty;

  /// Add a message to the queue
  void enqueue(QueuedMessage message) {
    _queue.add(message);
    _queueSizeController.add(_queue.length);
  }

  /// Get all queued messages
  List<QueuedMessage> dequeueAll() {
    final messages = List<QueuedMessage>.from(_queue);
    _queue.clear();
    _queueSizeController.add(0);
    return messages;
  }

  /// Remove a specific message
  void remove(String messageId) {
    _queue.removeWhere((m) => m.id == messageId);
    _queueSizeController.add(_queue.length);
  }

  void dispose() {
    _queueSizeController.close();
  }
}

/// A message waiting to be sent
class QueuedMessage {
  final String id;
  final String content;
  final String userId;
  final String threadId;
  final DateTime queuedAt;
  final Map<String, dynamic>? extraData;

  QueuedMessage({
    required this.id,
    required this.content,
    required this.userId,
    required this.threadId,
    DateTime? queuedAt,
    this.extraData,
  }) : queuedAt = queuedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'user_id': userId,
        'thread_id': threadId,
        'queued_at': queuedAt.toIso8601String(),
        'extra_data': extraData,
      };
}
