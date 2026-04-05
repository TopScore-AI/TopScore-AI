

class ApiConfig {
  static String get _defaultBaseUrl {
    return 'https://agent.topscoreapp.ai';
  }

  static String get baseUrl {
    return _defaultBaseUrl;
  }

  static String get geminiLiveTokenUrl => '$baseUrl/gemini-live/token';

  static String get wsUrl {
    final base = baseUrl;
    final scheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/ws';
  }

  static String get liveVoiceUrl => '$wsUrl/voice';

  static String get gradeComposition => '$baseUrl/api/study/grade-composition';

  static String get paystackInitialize => '$baseUrl/paystack/initialize';
  static String get paystackVerify => '$baseUrl/paystack/verify';

  /// URL Paystack redirects to after payment. The in-app WebView
  /// intercepts this redirect to trigger auto-verification.
  static const String paystackCallback =
      'https://topscoreapp.ai/payment/callback';
}
