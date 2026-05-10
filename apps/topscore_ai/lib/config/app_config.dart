class AppConfig {
  /// The base URL for the backend API. Override at build time with
  /// `--dart-define=BACKEND_BASE_URL=https://staging.example.com` for
  /// staging/dev builds.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://agent.topscoreapp.ai',
  );

  /// URL Paystack redirects to after payment. Override with
  /// `--dart-define=PAYSTACK_CALLBACK_URL=...`.
  static const String paystackCallback = String.fromEnvironment(
    'PAYSTACK_CALLBACK_URL',
    defaultValue: 'https://agent.topscoreapp.ai/payment/callback',
  );

  /// OAuth 2.0 Web client ID from the Firebase / Google Cloud project.
  /// Required as `serverClientId` on Android with google_sign_in v7+ so the
  /// returned idToken is accepted by Firebase Auth. Also used as `clientId`
  /// on Web. Override with `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '974459699084-3upotvccrivu1qcvneft7fi0op2ljnte.apps.googleusercontent.com',
  );

  /// iOS OAuth client ID (client_type 2 in GoogleService-Info.plist).
  /// Override with `--dart-define=GOOGLE_IOS_CLIENT_ID=...`.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '974459699084-0mf994asih1e8btm3ks889g12kuorodc.apps.googleusercontent.com',
  );

  /// Derives WebSocket URL from the base URL.
  static String get wsUrl {
    final uri = Uri.parse(backendBaseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host;
    // Explicitly set port to avoid Dart's Uri.parse defaulting to 0 for wss/ws
    final port =
        uri.hasPort ? ':${uri.port}' : (scheme == 'wss' ? ':443' : ':80');
    return '$scheme://$host$port/ws';
  }

  // --- API ENDPOINTS ---
  static String get geminiLiveTokenUrl => '$backendBaseUrl/gemini-live/token';
  static String get liveVoiceUrl => '$wsUrl/voice';
  static String get paystackInitialize => '$backendBaseUrl/paystack/initialize';
  static String get paystackVerify => '$backendBaseUrl/paystack/verify';

  // --- STORE LINKS ---
  /// The official Google Play Store URL for the app.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.topscoreapp.ai';

  /// The official Apple App Store URL for the app.
  /// Uses the bundle-ID lookup URL so it works even before the numeric ID is confirmed.
  static const String appStoreUrl =
      'https://apps.apple.com/app/apple-store/id6744042680';

  /// Polling interval for update checks (Native).
  static const Duration updateCheckInterval = Duration(minutes: 30);
}
