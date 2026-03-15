import 'package:flutter/foundation.dart';
import '../tutor_client/enhanced_websocket_service.dart';
import 'ai_tutor_history_provider.dart';

class TutorConnectionProvider with ChangeNotifier {
  EnhancedWebSocketService? _wsService;
  String? _currentUserId;
  bool _isInitialized = false;

  EnhancedWebSocketService? get wsService => _wsService;
  bool get isConnected => _wsService?.isConnected ?? false;
  bool get isInitialized => _isInitialized;

  // ignore: unused_field
  AiTutorHistoryProvider? _historyProvider;

  void attachHistoryProvider(AiTutorHistoryProvider provider) {
    _historyProvider = provider;
  }

  void updateUserId(String? userId) {
    if (userId == _currentUserId) return;

    _currentUserId = userId;

    // Dispose old service if exists
    _wsService?.dispose();
    _wsService = null;

    if (userId != null) {
      debugPrint(
          '[TutorConnection] Initializing global connection for: $userId');
      _wsService = EnhancedWebSocketService(userId: userId);

      // Listen for connection changes to notify UI
      _wsService!.isConnectedStream.listen((connected) {
        notifyListeners();
      });

      // Connect immediately with safety catch
      try {
        _wsService!.connect();
      } catch (e) {
        debugPrint('[TutorConnection] Failed to connect safely: $e');
      }
      _isInitialized = true;
    } else {
      _isInitialized = false;
    }

    notifyListeners();
  }

  void reconnect() {
    _wsService?.resetConnection();
  }

  @override
  void dispose() {
    _wsService?.dispose();
    super.dispose();
  }
}
