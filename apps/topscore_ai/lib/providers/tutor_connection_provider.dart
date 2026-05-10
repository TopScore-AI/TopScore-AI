import 'package:flutter/foundation.dart';
import '../tutor_client/enhanced_websocket_service.dart';

class TutorConnectionProvider with ChangeNotifier {
  EnhancedWebSocketService? _wsService;
  String? _currentUserId;
  bool _isInitialized = false;

  EnhancedWebSocketService? get wsService => _wsService;
  bool get isConnected => _wsService?.isConnected ?? false;
  bool get isInitialized => _isInitialized;

  /// Initialize or update the connection for a specific user
  Future<void> updateUserId(String? userId) async {
    if (userId == _currentUserId && _wsService != null) {
      // If the user hasn't changed, ensure the existing connection is resumed
      // (Handles background -> foreground transitions)
      _wsService?.resume();
      return;
    }

    _currentUserId = userId;

    // Dispose old service if exists
    _wsService?.dispose();
    _wsService = null;

    if (userId != null) {
      if (kDebugMode) {
        debugPrint(
            '[TutorConnection] Initializing global connection for: $userId');
      }
      _wsService = EnhancedWebSocketService(userId: userId);

      // Listen for connection changes to notify UI
      _wsService!.isConnectedStream.listen((connected) {
        notifyListeners();
      });

      // Initialize storage/listeners, then connect.
      await _wsService!.initialize();
      await _wsService!.connect();
      _isInitialized = true;
    } else {
      _isInitialized = false;
    }

    notifyListeners();
  }

  /// Pre-connect using the device ID before the user signs in.
  /// This ensures the WebSocket is ready as soon as the app launches.
  Future<void> preconnect(String deviceId) async {
    if (_wsService != null && _currentUserId == deviceId) return;
    
    if (kDebugMode) {
      debugPrint('[TutorConnection] Pre-connecting with Device ID: $deviceId');
    }
    
    // Use deviceId as the initial identity
    _currentUserId = deviceId;
    _wsService?.dispose();
    _wsService = EnhancedWebSocketService(userId: deviceId);
    
    _wsService!.isConnectedStream.listen((connected) {
      notifyListeners();
    });
    
    await _wsService!.initialize();
    await _wsService!.connect();
    _isInitialized = true;
    notifyListeners();
  }

  void reconnect() {
    _wsService?.resetConnection();
  }

  void resume() {
    _wsService?.resume();
  }

  void pause() {
    _wsService?.pause();
  }

  @override
  void dispose() {
    _wsService?.dispose();
    super.dispose();
  }
}
