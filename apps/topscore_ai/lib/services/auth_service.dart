import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsis;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../config/app_config.dart';
import 'device_id_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _gsisInitialized = false;

  /// google_sign_in v7+ uses a singleton with explicit `initialize(...)`.
  /// On Android, `serverClientId` (the Web OAuth client ID) is required so
  /// the idToken Credential Manager returns is signed with an audience that
  /// Firebase Auth accepts. Without it, `signInWithCredential` rejects the
  /// token and the user stays on the sign-in screen. iOS uses its own
  /// `clientId` from GoogleService-Info.plist.
  Future<void> _ensureGsisInitialized() async {
    if (_gsisInitialized) return;
    if (kIsWeb) {
      _gsisInitialized = true;
      return;
    }
    if (kDebugMode) debugPrint('[TOPSCORE] Initializing Google Sign-In v7...');
    await gsis.GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? AppConfig.googleIosClientId
          : null,
      serverClientId: AppConfig.googleWebClientId,
    );
    _gsisInitialized = true;
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

  Stream<User?> get authStateChanges => _auth.userChanges();
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
        final UserCredential userCredential =
            await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // Native Mobile Flow (Android Credential Manager / iOS).
        if (kDebugMode) debugPrint('[TOPSCORE] Native Google Sign-In Started');
        await _ensureGsisInitialized();

        final gsis.GoogleSignInAccount googleUser =
            await gsis.GoogleSignIn.instance.authenticate();

        if (kDebugMode) {
          debugPrint('[TOPSCORE] Google User acquired: ${googleUser.email}');
        }

        // idToken is the only thing Firebase Auth strictly needs. In v7+
        // it's available synchronously on the account once authentication
        // succeeds.
        final gsis.GoogleSignInAuthentication googleAuth =
            googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        if (idToken == null || idToken.isEmpty) {
          throw Exception(
              'Google sign-in did not return an idToken. Check that AppConfig.googleWebClientId matches the Web OAuth client in Firebase, and that the SHA-1/SHA-256 of the running build is registered in Firebase Console.');
        }

        // accessToken is optional for Firebase sign-in. Fetching it via
        // authorizeScopes can fail (or require a user gesture) on some
        // Android setups — don't let that block authentication.
        String? accessToken;
        try {
          final clientAuth = await googleUser.authorizationClient
              .authorizeScopes(<String>['email', 'profile']);
          accessToken = clientAuth.accessToken;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[TOPSCORE] authorizeScopes failed (non-fatal): $e');
          }
        }

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );

        if (kDebugMode) {
          debugPrint('[TOPSCORE] Signing in to Firebase with credential...');
        }
        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);

        if (kDebugMode) {
          debugPrint(
              '[TOPSCORE] Firebase Sign-In successful: ${userCredential.user?.uid}');
        }
        return userCredential.user;
      }
    } on gsis.GoogleSignInException catch (e) {
      if (e.code == gsis.GoogleSignInExceptionCode.canceled) {
        return null;
      }
      if (kDebugMode) debugPrint('Google Sign In Error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('Google Sign In Error: $e');

      // Specific error handling for certificate hash mismatches
      if (e.toString().contains('invalid-cert-hash')) {
        throw Exception(
            'Sign-in blocked: Your app\'s SHA-1 fingerprint is not registered in the Firebase Console. Please add your SHA-1 for the release variant in Project Settings.');
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
    try {} finally {
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
      if (kDebugMode) {
        debugPrint('Firebase error fetching user profile ($uid): $e');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unexpected error fetching user profile ($uid): $e');
      }
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

  ActionCodeSettings _buildActionCodeSettings({String? email}) {
    // Use the Firebase Dynamic Links domain for email links.
    // This domain is already configured in AndroidManifest.xml with autoVerify=true
    // and will open the app directly instead of the browser.
    final continueUrl = email != null
        ? 'https://elimisha-90787.firebaseapp.com/__/auth/action?email=${Uri.encodeComponent(email)}'
        : 'https://elimisha-90787.firebaseapp.com/__/auth/action';

    return ActionCodeSettings(
      url: continueUrl,
      handleCodeInApp: true,
      androidPackageName: 'com.topscoreapp.ai',
      androidInstallApp: true,
      androidMinimumVersion: '12',
      iOSBundleId: 'com.topscoreapp.ai',
    );
  }

  Future<void> sendSignInLinkToEmail(String email) async {
    await _auth.sendSignInLinkToEmail(
      email: email.trim(),
      actionCodeSettings: _buildActionCodeSettings(email: email),
    );
  }

  bool isSignInWithEmailLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  Future<UserCredential> signInWithEmailLink(String email, String link) async {
    return await _auth.signInWithEmailLink(
      email: email.trim(),
      emailLink: link,
    );
  }

  Future<void> applyActionCode(String code) async {
    await _auth.applyActionCode(code);
  }

  Future<ActionCodeInfo> checkActionCode(String code) async {
    return await _auth.checkActionCode(code);
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      // Use ActionCodeSettings to ensure the link redirects back to the app on mobile
      await user
          .sendEmailVerification(_buildActionCodeSettings(email: user.email));
    }
  }

  Future<bool> registerFCMToken(String token, {bool isRetry = false}) async {
    if (currentUser == null) return false;

    try {
      final idToken = await currentUser!.getIdToken(isRetry);
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/notifications/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 401 && !isRetry) {
        if (kDebugMode) {
          debugPrint("Auth: 401 on registerFCMToken, retrying with fresh token...");
        }
        return registerFCMToken(token, isRetry: true);
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Error registering FCM token: $e");
      return false;
    }
  }

  Future<bool> transferGuestHistory(String oldUserId, String newUserId,
      {bool isRetry = false}) async {
    if (currentUser == null) return false;

    try {
      final deviceId = await DeviceIdService.get();
      final effectiveOldId = deviceId.isNotEmpty ? deviceId : oldUserId;

      final idToken = await currentUser!.getIdToken(isRetry);
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/history/transfer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'X-Device-ID': deviceId,
        },
        body: jsonEncode({
          'old_user_id': effectiveOldId,
          'new_user_id': newUserId,
        }),
      );

      if (response.statusCode == 401 && !isRetry) {
        if (kDebugMode) {
          debugPrint("Auth: 401 on transferGuestHistory, retrying with fresh token...");
        }
        return transferGuestHistory(oldUserId, newUserId, isRetry: true);
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Error transferring guest history: $e");
      return false;
    }
  }
}
