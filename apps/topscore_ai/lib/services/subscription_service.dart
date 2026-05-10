import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart' as app_auth;

class SubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Checks if the current session has premium access
  Future<bool> isSessionPremium() async {
    // 1. Check the primary local model (Firestore source)
    // This is the most reactive way to unlock features after payment
    if (app_auth.AuthProvider.instance.hasActiveSubscription) {
      return true;
    }

    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      // 2. Fallback to JWT Claims (Security Token)
      // This catches cases where the user just joined on a new device but claims are synced
      IdTokenResult tokenResult =
          await user.getIdTokenResult(false); // Don't force refresh every time
      Map<String, dynamic>? claims = tokenResult.claims;

      if (claims?['plan'] == 'premium') {
        int expiry = claims?['expiry'] ?? 0;
        bool isActive = DateTime.now().millisecondsSinceEpoch / 1000 < expiry;
        return isActive;
      }

      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  /// Checks if the current session has premium access.
  /// TopScore AI does not offer free trials.
  Future<bool> isSessionPremiumOrTrial() async {
    return isSessionPremium();
  }

  /// Call this immediately after payment success.
  /// Refreshes the local user model from Firestore (primary source of truth)
  /// and updates the JWT claims in the background.
  Future<void> refreshSubscriptionStatus() async {
    final auth = app_auth.AuthProvider.instance;

    // 1. Pull the absolute latest state from Firestore
    // This bypasses the old JWT claim-based gate which caused the 'Trial' fallback
    await auth.refreshUser();

    // 2. Check if the database now shows a Pro status
    if (auth.hasActiveSubscription) {
      if (kDebugMode) debugPrint('Subscription confirmed in Firestore.');
      // Do NOT call updateSubscription here — the duration was already set
      // correctly by the payment flow. Calling it again with a hardcoded 30
      // would overwrite a weekly (7-day) purchase with a monthly one.
    }

    // 3. Background: Refresh JWT token claims (clean-up for future API sessions)
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.getIdTokenResult(true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('JWT Refresh warning (non-critical): $e');
    }
  }
}
