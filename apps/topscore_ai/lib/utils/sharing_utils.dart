import 'dart:convert';
import 'package:flutter/foundation.dart';

class SharingUtils {
  static const String appDomain = 'https://app.topscoreapp.ai';

  /// Generates a clean sharing URL for a Firebase Storage URL.
  /// URL format: e.g. https://app.topscoreapp.ai/share/aW1hZ2VzL2NoYXJ0LnBuZw==
  static String generateShareLink(String storageUrl) {
    try {
      final decodedUrl = Uri.decodeFull(storageUrl);
      String? path;

      // firebasestorage.googleapis.com format
      if (decodedUrl.contains('firebasestorage.googleapis.com/')) {
        final oMarker = '/o/';
        final oIndex = decodedUrl.indexOf(oMarker);
        if (oIndex != -1) {
          final pathAndQuery = decodedUrl.substring(oIndex + oMarker.length);
          path = pathAndQuery.split('?').first;
        }
      }
      // storage.googleapis.com format
      else if (decodedUrl.contains('storage.googleapis.com/')) {
        final uri = Uri.parse(decodedUrl);
        if (uri.pathSegments.length > 1) {
          path = uri.pathSegments.sublist(1).join('/');
        }
      }

      if (path == null) return storageUrl; // Fallback

      // Encode path to base64 for the URL slug
      final bytes = utf8.encode(path);
      final slug = base64Url.encode(bytes);

      return '$appDomain/share/$slug';
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating share link: $e');
      return storageUrl;
    }
  }

  /// Decodes a share slug back into a storage path.
  static String? decodeShareSlug(String slug) {
    try {
      final bytes = base64Url.decode(slug);
      return utf8.decode(bytes);
    } catch (e) {
      if (kDebugMode) debugPrint('Error decoding share slug: $e');
      return null;
    }
  }
}
