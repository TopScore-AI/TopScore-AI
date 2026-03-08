import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String _productionBaseUrl = 'https://agent.topscoreapp.ai';
  static const String _localBaseUrl =
      'http://localhost:8000'; // FastAPI local default

  static String get baseUrl {
    const String dartDefineUrl = String.fromEnvironment('API_BASE_URL');
    if (dartDefineUrl.isNotEmpty) return dartDefineUrl;

    if (kReleaseMode) return _productionBaseUrl;
    final envUrl = kIsWeb ? null : dotenv.env['API_BASE_URL'];
    return envUrl ?? _localBaseUrl;
  }

  static String getGeminiLiveTokenUrl(String userId) =>
      '$baseUrl/livekit/token?user_id=$userId';

  static String get wsUrl {
    final base = baseUrl;
    final scheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/ws';
  }

  static String getChatWsUrl(String sessionId, String userId) {
    final base = baseUrl;
    final scheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/ws/chat/$sessionId?user_id=$userId';
  }

  static String get paystackInitialize => '$baseUrl/paystack/initialize';
  static String get paystackVerify => '$baseUrl/paystack/verify';

  /// URL Paystack redirects to after payment. The in-app WebView
  /// intercepts this redirect to trigger auto-verification.
  static String get paystackCallback => '$baseUrl/paystack/callback';

  // History Endpoints
  static String getHistoryUrl(String userId) => '$baseUrl/api/history/$userId';
  static String getThreadDeleteUrl(String threadId) =>
      '$baseUrl/threads/$threadId';
  static String getClearHistoryUrl(String userId) =>
      '$baseUrl/api/history/$userId/clear';
}
