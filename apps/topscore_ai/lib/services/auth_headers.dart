import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthHeaders {
  /// Helper to get headers with Firebase Auth Bearer token.
  /// The backend requires:
  ///   Authorization: Bearer [idToken]  (verified by verify_student)
  static Future<Map<String, String>> getHeaders([Map<String, String>? existingHeaders]) async {
    final headers = existingHeaders != null ? Map<String, String>.from(existingHeaders) : <String, String>{};
    
    // Set content type if not present
    if (!headers.containsKey('Content-Type')) {
      headers['Content-Type'] = 'application/json';
    }

    // Firebase Auth Bearer token
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          headers['Authorization'] = 'Bearer $idToken';
        }
      } catch (e) {
        if (kDebugMode) debugPrint("Auth: Failed to get ID token: $e");
      }
    }
    
    return headers;
  }
}
