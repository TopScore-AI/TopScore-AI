import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'device_id_service.dart';

class AuthHeaders {
  /// Helper to get headers with Firebase Auth Bearer token.
  /// The backend requires:
  ///   Authorization: Bearer [idToken]  (verified by verify_student)
  static Future<Map<String, String>> getHeaders({
    Map<String, String>? existingHeaders,
    bool forceRefresh = false,
  }) async {
    final headers = existingHeaders != null
        ? Map<String, String>.from(existingHeaders)
        : <String, String>{};

    // Set content type if not present
    if (!headers.containsKey('Content-Type')) {
      headers['Content-Type'] = 'application/json';
    }

    // Firebase Auth Bearer token
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Use forceRefresh if requested to bypass local cache
        final idToken = await user.getIdToken(forceRefresh);
        if (idToken != null) {
          if (kDebugMode) {
            final snippet = idToken.length > 20 
                ? "${idToken.substring(0, 10)}...${idToken.substring(idToken.length - 10)}"
                : "short";
            debugPrint("Auth: Attaching ID token ($snippet), length: ${idToken.length}");
          }
          headers['Authorization'] = 'Bearer $idToken';
        } else {
          if (kDebugMode) debugPrint("Auth: ID token is NULL for user ${user.uid}");
        }
      } catch (e) {
        if (kDebugMode) debugPrint("Auth: Failed to get ID token: $e");
      }
    } else {
      if (kDebugMode) debugPrint("Auth: No current user found in FirebaseAuth");
    }
    // Device ID for tracking guest/free limits
    try {
      final deviceId = await DeviceIdService.get();
      headers['X-Device-ID'] = deviceId;
    } catch (e) {
      if (kDebugMode) debugPrint("Auth: Failed to get Device ID: $e");
    }

    return headers;
  }
}
