import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../config/api_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // bool _googleSignInInitialized = false; // No longer needed for redirect flow

  static const Set<String> _defaultBlockedEmailDomains = {
    'mailinator.com',
    '10minutemail.com',
    'tempmail.com',
    'guerrillamail.com',
    'yopmail.com',
    'dispostable.com',
    'sharklasers.com',
    'trashmail.com',
    'getnada.com',
    'mohmal.com',
    'maildrop.cc',
    'fakeinbox.com',
    'temp-mail.org',
    'temp-mail.io',
    'burnermail.io',
    'mailnesia.com',
    'minutemail.com',
    'mailtemp.net',
    'spambog.com',
    'spambox.us',
    'spamgourmet.com',
    'mailcatch.com',
    'emailondeck.com',
    'inboxbear.com',
    'tempr.email',
    'dropmail.me',
  };

  Set<String> _blockedEmailDomains = {};
  bool _blockedEmailDomainsLoaded = false;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> ensureBlockedEmailDomainsLoaded() async {
    if (_blockedEmailDomainsLoaded) return;
    try {
      final data = await rootBundle
          .loadString('assets/config/blocked_email_domains.json');
      final decoded = jsonDecode(data);
      if (decoded is List) {
        _blockedEmailDomains = decoded
            .whereType<String>()
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      } else {
        _blockedEmailDomains = _defaultBlockedEmailDomains;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load blocked email domains: $e');
      _blockedEmailDomains = _defaultBlockedEmailDomains;
    } finally {
      _blockedEmailDomainsLoaded = true;
    }
  }

  bool isEmailDomainBlocked(String email) {
    final domain = email.split('@').last.toLowerCase().trim();
    if (domain.isEmpty) return true;
    return _blockedEmailDomains.contains(domain);
  }

  /* No longer needed for redirect flow
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await _googleSignIn.initialize();
      _googleSignInInitialized = true;
    }
  }
  */

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
      });

      if (kIsWeb) {
        // Use Popup on Web for better reliability and UX
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // Use Redirect flow on Mobile as requested
        await _auth.signInWithRedirect(googleProvider);
        return null; // Signals to caller that direct sign-in isn't finished
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Google Sign In Error: $e');
      
      // Specific error handling for certificate hash mismatches
      if (e.toString().contains('invalid-cert-hash')) {
        throw Exception('Sign-in blocked: Your app\'s SHA-1 fingerprint is not registered in the Firebase Console. Please add your SHA-1 for the release variant in Project Settings.');
      }
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    await ensureBlockedEmailDomainsLoaded();
    if (isEmailDomainBlocked(email)) {
      throw Exception(
          'Disposable or fraudulent email providers are not allowed.');
    }
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    try {
    } finally {
      await _auth.signOut();
      // _googleSignInInitialized = false;
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null; // Explicitly missing
    } on FirebaseException catch (e) {
      if (kDebugMode) debugPrint('Firebase error fetching user profile ($uid): $e');
      rethrow; // Propagate error so we don't assume the user is "new"
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected error fetching user profile ($uid): $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating user profile: $e');
      // On web during local debug, this might fail due to App Check rules.
      // We catch it so it doesn't crash the auth flow.
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> registerFCMToken(String token) async {
    if (currentUser == null) return false;
    
    try {
      final idToken = await currentUser!.getIdToken();
      // Use the proper backend URL from ApiConfig
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fcm_token': token}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Error registering FCM token: $e");
      return false;
    }
  }

  /// Reassigns chat threads from an old user (guest) to a new one.
  Future<bool> transferGuestHistory(String oldUserId, String newUserId) async {
    if (currentUser == null) return false;
    
    try {
      final idToken = await currentUser!.getIdToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/history/transfer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'X-User-ID': currentUser!.uid, 
        },
        body: jsonEncode({
          'old_user_id': oldUserId,
          'new_user_id': newUserId,
        }),
      );
      
      if (kDebugMode) {
        debugPrint("🔄 History transfer result (${response.statusCode}): ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Error transferring guest history: $e");
      return false;
    }
  }
}
