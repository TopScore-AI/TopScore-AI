import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String _defaultBaseUrl = 'https://agent.topscoreapp.ai';

  static String get baseUrl {
    final envUrl = kIsWeb ? null : dotenv.env['API_BASE_URL'];
    return envUrl ?? _defaultBaseUrl;
  }

  static String get geminiLiveTokenUrl => '$baseUrl/gemini-live/token';

  static String get wsUrl {
    final base = baseUrl;
    final scheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/ws';
  }

  static String get paystackInitialize => '$baseUrl/paystack/initialize';
  static String get paystackVerify => '$baseUrl/paystack/verify';

  /// URL Paystack redirects to after payment. The in-app WebView
  /// intercepts this redirect to trigger auto-verification.
  static const String paystackCallback =
      'https://topscoreapp.ai/payment/callback';
}
