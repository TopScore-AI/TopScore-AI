class AppConfig {
  /// The base URL for the backend API.
  static const String backendBaseUrl = 'https://agent.topscoreapp.ai';

  /// Derives WebSocket URL from the base URL.
  static String get wsUrl {
    final scheme = backendBaseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = backendBaseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return '$scheme://$host/ws';
  }

  // --- API ENDPOINTS ---
  static String get geminiLiveTokenUrl => '$backendBaseUrl/gemini-live/token';
  static String get liveVoiceUrl => '$wsUrl/voice';
  static String get gradeComposition =>
      '$backendBaseUrl/api/study/grade-composition';
  static String get paystackInitialize => '$backendBaseUrl/paystack/initialize';
  static String get paystackVerify => '$backendBaseUrl/paystack/verify';

  /// URL Paystack redirects to after payment.
  static const String paystackCallback =
      'https://topscoreapp.ai/payment/callback';

  // --- STORE LINKS ---
  /// The official Google Play Store URL for the app.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=ai.topscore.app';

  /// The official Apple App Store URL for the app.
  static const String appStoreUrl =
      'https://apps.apple.com/app/topscore-ai/id000000000';

  /// Polling interval for update checks (Native).
  static const Duration updateCheckInterval = Duration(minutes: 30);
}
