import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class BrowserUtils {
  /// Detects if the current web app is running inside an "In-App Browser" (IAB).
  /// These are built-in browsers like those in Facebook, Instagram, TikTok, etc.
  static bool get isInAppBrowser {
    if (!kIsWeb) return false;

    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      
      // Common IAB markers:
      // Facebook: FBAV (Facebook App Version), FBAN (Facebook App Name)
      // Instagram: Instagram
      // Messenger: FB_IAB/MESSENGER
      // TikTok: ByteLocale, Musicaly (old), TikTok
      // Snapchat: Snapchat
      // LinkedIn: LinkedInApp
      
      final iabMarkers = [
        'fbav',
        'fban',
        'instagram',
        'fbiab',
        'messenger',
        'tiktok',
        'snapchat',
        'linkedinapp',
        'micro messenger', // WeChat
        'pinterest',
      ];

      return iabMarkers.any((marker) => userAgent.contains(marker));
    } catch (e) {
      debugPrint('Error detecting In-App Browser: $e');
      return false;
    }
  }

  /// Returns a human-friendly name of the detected In-App Browser, if any.
  static String? get detectedIabName {
    if (!kIsWeb) return null;

    final userAgent = web.window.navigator.userAgent.toLowerCase();
    
    if (userAgent.contains('fbav') || userAgent.contains('fban')) return 'Facebook';
    if (userAgent.contains('instagram')) return 'Instagram';
    if (userAgent.contains('messenger')) return 'Messenger';
    if (userAgent.contains('tiktok')) return 'TikTok';
    if (userAgent.contains('snapchat')) return 'Snapchat';
    if (userAgent.contains('linkedinapp')) return 'LinkedIn';
    
    return isInAppBrowser ? 'In-App Browser' : null;
  }

  /// Reloads the current page on Web.
  static void reloadPage() {
    if (kIsWeb) {
      web.window.location.reload();
    }
  }
}
