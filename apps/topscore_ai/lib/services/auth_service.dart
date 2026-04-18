import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsis;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../config/app_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _gsisInitialized = false;

  Future<void> _ensureGsisInitialized() async {
    if (_gsisInitialized) return;
    if (!kIsWeb) {
      gsis.GoogleSignIn.instance.initialize(
        serverClientId: '974459699084-3upotvccrivu1qcvneft7fi0op2ljnte.apps.googleusercontent.com',
      );
      _gsisInitialized = true;
    }
  }

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

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
      });

      if (kIsWeb) {
        // Use Popup on Web (standard Firebase flow)
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // Native Mobile Flow (Google Sign-In 7.x Migration)
        await _ensureGsisInitialized();
        
        final gsis.GoogleSignInAccount googleUser = await gsis.GoogleSignIn.instance.authenticate();

        // Get Authentication (idToken)
        final gsis.GoogleSignInAuthentication googleAuth = googleUser.authentication;
        
        // Get Authorization (accessToken) - Explicitly request scopes as required in 7.x
        final scopes = <String>['email', 'profile'];
        final clientAuth = await googleUser.authorizationClient.authorizeScopes(scopes);

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: clientAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
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
      return null;
    } on FirebaseException catch (e) {
      if (kDebugMode) debugPrint('Firebase error fetching user profile ($uid): $e');
      rethrow;
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
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/notifications/register-token'),
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

  Future<bool> transferGuestHistory(String oldUserId, String newUserId) async {
    if (currentUser == null) return false;
    
    try {
      final idToken = await currentUser!.getIdToken();
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/history/transfer'),
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
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Error transferring guest history: $e");
      return false;
    }
  }
}
