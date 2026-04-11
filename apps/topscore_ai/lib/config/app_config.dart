class AppConfig {
  /// The base URL for the backend API.
  static const String backendBaseUrl = 'https://agent.topscoreapp.ai';

  /// The official Google Play Store URL for the app.
  /// TODO: Replace with the final production URL when available.
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=ai.topscore.app';

  /// The official Apple App Store URL for the app.
  /// TODO: Replace with the final production URL when available.
  static const String appStoreUrl = 'https://apps.apple.com/app/topscore-ai/id000000000';
  
  /// Polling interval for update checks (Native).
  static const Duration updateCheckInterval = Duration(minutes: 30);
}
