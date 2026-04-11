import 'package:flutter/foundation.dart' show kIsWeb;

/// Helper class for handling CORS issues with external images on web platform
class CorsProxyHelper {
  /// List of domains that are safe to load directly without proxy
  static const List<String> safeDomains = [
    'localhost',
    '127.0.0.1',
    'firebasestorage.googleapis.com',
    'storage.googleapis.com',
    'googleusercontent.com',
    'youtube.com',
    'ytimg.com',
    'ggpht.com',
  ];

  /// Checks if the URL is from an external domain that might have CORS issues
  static bool isExternalUrl(String url) {
    if (!url.startsWith('http')) return false;
    
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      
      // Check if it's a safe domain
      for (final domain in safeDomains) {
        if (host.contains(domain)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Converts external URL to use a CORS proxy on web platform
  /// Returns the original URL on native platforms or for safe domains
  static String getCorsProxyUrl(String url) {
    if (!kIsWeb || !isExternalUrl(url)) {
      return url;
    }
    
    // Use allOrigins proxy for external images on web
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
  }

  /// Standard HTTP headers to help with CORS and image loading
  static const Map<String, String> standardHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  /// Add a custom safe domain to the list (useful for your own CDN)
  static void addSafeDomain(String domain) {
    if (!safeDomains.contains(domain)) {
      // Note: This is a const list, so in practice you'd need to maintain
      // a separate mutable list or rebuild the app with the new domain
      // For now, this is a placeholder for documentation
    }
  }
}

// Made with Bob
