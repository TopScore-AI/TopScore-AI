import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/offline_service.dart';
import '../services/subscription_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _requiresEmailVerification = false;
  StreamSubscription<UserModel?>? _userStreamSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool get requiresEmailVerification => _requiresEmailVerification;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  /// Uses Firebase Auth currentUser as the source of truth for authentication.
  bool get isAuthenticated => _authService.currentUser != null;

  /// Whether the user has a currently active (non-expired) subscription.
  bool get hasActiveSubscription {
    if (_userModel == null) return false;
    if (!_userModel!.isSubscribed) return false;
    final expiry = _userModel!.subscriptionExpiry;
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  bool get canSendMessage {
    if (_userModel == null) return false;
    if (hasActiveSubscription) return true;

    // Check if 24 hours have passed since the tracking window started
    if (_userModel!.lastMessageDate != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_userModel!.lastMessageDate!);
      if (elapsed.inHours >= 24) {
        return true;
      }
    }

    return _userModel!.dailyMessageCount < 5;
  }

  Future<void> incrementDailyMessage() async {
    if (_userModel == null) return;
    if (hasActiveSubscription) return;

    final now = DateTime.now();
    int newCount = 1;
    DateTime newDate = now;

    if (_userModel!.lastMessageDate != null) {
      final elapsed = now.difference(_userModel!.lastMessageDate!);
      if (elapsed.inHours < 24) {
        newCount = _userModel!.dailyMessageCount + 1;
        newDate = _userModel!.lastMessageDate!;
      }
    }

    try {
      await _authService.firestore
          .collection('users')
          .doc(_userModel!.uid)
          .update({
        'dailyMessageCount': newCount,
        'lastMessageDate': newDate.millisecondsSinceEpoch,
      });

      _userModel = _userModel!.copyWith(
        dailyMessageCount: newCount,
        lastMessageDate: newDate,
      );
      notifyListeners();
    } catch (e) {
      debugPrint("Error incrementing daily message: $e");
    }
  }

  bool get _documentWindowExpired {
    if (_userModel?.lastDocumentAccessDate == null) return true;
    return DateTime.now()
            .difference(_userModel!.lastDocumentAccessDate!)
            .inHours >=
        24;
  }

  bool get canOpenDocument {
    if (_userModel == null) return false;
    if (hasActiveSubscription) return true;
    if (_documentWindowExpired) return true;
    return _userModel!.accessedDocuments.length < 5;
  }

  Future<bool> tryAccessDocument(String docId) async {
    if (_userModel == null) return false;

    final isPremiumOrTrial =
        await SubscriptionService().isSessionPremiumOrTrial();
    if (isPremiumOrTrial) return true;

    List<String> currentDocs = List<String>.from(_userModel!.accessedDocuments);
    DateTime windowStart = _userModel!.lastDocumentAccessDate ?? DateTime.now();

    if (_documentWindowExpired) {
      currentDocs = [];
      windowStart = DateTime.now();
    }

    if (currentDocs.contains(docId)) {
      return true;
    }

    if (currentDocs.length < 5) {
      try {
        final newList = List<String>.from(currentDocs)..add(docId);

        await _authService.firestore
            .collection('users')
            .doc(_userModel!.uid)
            .update({
          'accessedDocuments': newList,
          'lastDocumentAccessDate': windowStart.millisecondsSinceEpoch,
        });

        _userModel = _userModel!.copyWith(
          accessedDocuments: newList,
          lastDocumentAccessDate: windowStart,
        );
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint("Error updating accessed documents: $e");
        return false;
      }
    }

    return false;
  }

  // ──────────────────────────────────────────────────────────
  //  Initialization — uses Firebase authStateChanges() stream
  //  per https://firebase.google.com/docs/auth/flutter/start
  // ──────────────────────────────────────────────────────────

  Future<void> init() async {
    _isInitializing = true;
    notifyListeners();
    try {
      debugPrint('[AUTH] Provider init starting...');
      
      // Load domains early
      await _authService.ensureBlockedEmailDomainsLoaded();

      // Step 1: On web, check for redirect result FIRST.
      if (kIsWeb) {
        debugPrint('[AUTH] Checking for redirect result...');
        try {
          final redirectResult = await _authService.getRedirectResult()
              .timeout(const Duration(seconds: 10), onTimeout: () {
            debugPrint('[AUTH] getRedirectResult timed out');
            return null;
          });
          if (redirectResult?.user != null) {
            debugPrint('[AUTH] Redirect sign-in found: ${redirectResult!.user!.uid}');
            await _resolveUser(redirectResult.user!);
            _startAuthListener();
            return; 
          }
        } catch (e) {
          debugPrint('[AUTH] getRedirectResult error (non-fatal): $e');
        }
      }

      // Step 2: Ensure we wait for the first auth state change with a timeout
      debugPrint('[AUTH] Waiting for authStateChanges().first...');
      User? user;
      try {
        user = await _authService.auth.authStateChanges().first.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[AUTH] authStateChanges().first timed out, using currentUser');
            return _authService.currentUser;
          },
        );
      } catch (e) {
        debugPrint('[AUTH] Error waiting for auth state: $e');
        user = _authService.currentUser;
      }
      
      debugPrint('[AUTH] Initial user resolved: ${user?.uid}');

      if (user != null) {
        await _resolveUser(user);
      } else {
        // Explicitly clear model if no user found on startup
        _userModel = null;
        _requiresEmailVerification = false;
      }

      // Step 3: Start persistent listener
      _startAuthListener();
    } catch (e) {
      debugPrint("[AUTH] AuthProvider init error: $e");
    } finally {
      // Small delay on web to ensure indexedDB state is fully propagated to UI if needed
      if (kIsWeb) await Future.delayed(const Duration(milliseconds: 100));
      
      _isInitializing = false;
      notifyListeners();
      debugPrint('[AUTH] Init complete. isInitializing: false, authenticated: $isAuthenticated, user: ${_authService.currentUser?.uid}');
    }
  }

  /// Starts a persistent listener on authStateChanges to react to sign-in/sign-out
  /// events that happen after initialization (e.g. from email sign-in, sign-out button).
  void _startAuthListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _authService.auth.authStateChanges().listen((user) async {
      // Skip during loading or initialization — init or explicit methods handle resolution.
      if (_isLoading || _isInitializing) return;
      debugPrint('[AUTH] authStateChanges (post-init): ${user?.uid}');
      await _resolveUser(user);
    });
  }

  /// Resolves a Firebase Auth user: checks anonymous, verification, loads profile.
  Future<void> _resolveUser(User? firebaseUser) async {
    if (firebaseUser == null) {
      if (_userModel == null && !_requiresEmailVerification && _authService.currentUser == null) {
        return; // Already in signed-out state
      }
      debugPrint('[AUTH] Resolving null user (Sign Out).');
      _userModel = null;
      _requiresEmailVerification = false;
      _userStreamSubscription?.cancel();
      notifyListeners();
      return;
    }

    if (firebaseUser.isAnonymous) {
      if (_userModel == null && !_requiresEmailVerification && isAuthenticated) {
        return; // Already in anonymous state
      }
      debugPrint("[AUTH] Anonymous user detected. Keeping authenticated state but no profile.");
      _userModel = null;
      _requiresEmailVerification = false;
      notifyListeners();
      return;
    }

    // Heavy operations below: reload and Firestore fetch
    // We only want to run these if the user has changed OR if we are currently
    // in an unauthenticated/unverified state but have a firebaseUser.
    final bool isSameUser = _userModel?.uid == firebaseUser.uid;
    final bool wasVerified = isSameUser && !_requiresEmailVerification;

    // Reload to get fresh emailVerified status.
    User user = firebaseUser;
    try {
      await firebaseUser.reload();
      user = _authService.currentUser ?? firebaseUser;
      debugPrint('[AUTH] User ${user.uid} reloaded. Verified: ${user.emailVerified}');
    } catch (e) {
      debugPrint("[AUTH] user.reload() failed, using cached state: $e");
    }

    // If verification status and user are the same, we can often skip notifications
    if (isSameUser && wasVerified == user.emailVerified && _userModel != null) {
      debugPrint('[AUTH] No state change detected for ${user.uid}. Skipping heavy resolution.');
      // Ensure we stop initializing if we were
      if (_isInitializing) {
        _isInitializing = false;
        notifyListeners();
      }
      return;
    }

    if (!user.emailVerified) {
      debugPrint('[AUTH] User ${user.uid} not verified.');
      _requiresEmailVerification = true;
      _userModel = null;
      notifyListeners();
      return;
    }

    _requiresEmailVerification = false;

    // Fetch or create Firestore profile
    if (_userModel?.uid != user.uid) {
      debugPrint('[AUTH] Loading Firestore profile for ${user.uid}...');
      final model = await _authService.getUserProfile(user.uid);
      if (model != null) {
        _userModel = model;
      } else {
        debugPrint('[AUTH] Profile missing, creating default for ${user.uid}...');
        await _ensureUserProfile(user);
      }
      _listenToUserProfile(user.uid);
    }
    
    notifyListeners();
  }

  void _listenToUserProfile(String uid) {
    _userStreamSubscription?.cancel();
    _userStreamSubscription =
        _authService.userProfileStream(uid).listen((model) {
      if (model != null) {
        _userModel = model;
        notifyListeners();
      }
    });
  }

  Future<void> _ensureUserProfile(User user) async {
    final existing = await _authService.getUserProfile(user.uid);
    if (existing != null) {
      _userModel = existing;
    } else {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'New User',
        photoURL: user.photoURL,
        role: 'student',
        grade: null,
        schoolName: '',
      );
      await _authService.updateUserProfile(user.uid, newUser.toMap());
      _userModel = newUser;
    }
  }

  // ── GOOGLE SIGN IN ─────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // Both Mobile and Web paths now return a user directly!
        _requiresEmailVerification = false;
        await _resolveUser(user);

        // Mark onboarding complete on successful sign-in
        await OfflineService().setStringList('onboarding_complete', ['true']);
        
        _setLoading(false);
        return true;
      }
      
      // If user is null, it means the user cancelled the sign-in flow.
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      _setLoading(false);
      rethrow;
    }
  }

  // ── EMAIL SIGN IN ──────────────────────────────────────────
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final credential = await _authService.signInWithEmail(email, password);
      final user = credential?.user;
      if (user == null) return false;

      await user.reload();
      final refreshedUser = _authService.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        debugPrint('[AUTH] User ${refreshedUser?.uid} email not verified. Setting _requiresEmailVerification to true.');
        _requiresEmailVerification = true;
        _userModel = null;
        try {
          debugPrint('[AUTH] Sending email verification...');
          await _authService.sendEmailVerification();
        } catch (e) {
          debugPrint('[AUTH] Error sending email verification: $e');
        }
        notifyListeners();
        return false;
      }

      debugPrint('[AUTH] User ${refreshedUser.uid} email verified. Resolving user...');
      _requiresEmailVerification = false;
      await _resolveUser(refreshedUser);

      // Mark onboarding complete on successful sign-in
      await OfflineService().setStringList('onboarding_complete', ['true']);

      return true;
    } catch (e) {
      debugPrint("Email Sign In Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── EMAIL SIGN UP ──────────────────────────────────────────
  Future<bool> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      _setLoading(true);
      final credential = await _authService.signUpWithEmail(email, password);
      final user = credential?.user;
      if (user != null) {
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
          await user.reload();
        }
        
        try {
          debugPrint('[AUTH] Sending initial verification email for new user ${user.uid}...');
          await _authService.sendEmailVerification();
        } catch (e) {
          debugPrint('[AUTH] Error sending initial verification: $e');
        }

        // Create profile immediately
        await _ensureUserProfile(_authService.currentUser ?? user);

        // Require verification (return false to signals caller to handle or wait for redirect)
        _requiresEmailVerification = true;
        _userModel = null;
        notifyListeners();
        return false;
      }
      return false;
    } catch (e) {
      debugPrint("Email Sign Up Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordReset(email);
  }

  Future<void> resendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _authService.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _authService.currentUser;
    await _resolveUser(refreshedUser);
    
    if (refreshedUser?.emailVerified ?? false) {
      // Mark onboarding complete
      await OfflineService().setStringList('onboarding_complete', ['true']);
      return true;
    }
    return false;
  }

  Future<void> updateUserRole({
    required String role,
    required String grade,
    required String schoolName,
    String? displayName,
    String? phoneNumber,
    String? curriculum,
    String? educationLevel,
    List<String>? interests,
    List<String>? subjects,
    DateTime? dateOfBirth,
    bool? parentalConsentGiven,
  }) async {
    if (_userModel == null) return;

    try {
      _setLoading(true);
      int? gradeInt = int.tryParse(grade.replaceAll(RegExp(r'[^0-9]'), ''));

      final updates = <String, dynamic>{
        'role': role,
        'grade': gradeInt,
        'schoolName': schoolName,
        'displayName': displayName ?? _userModel!.displayName,
        'phoneNumber': phoneNumber,
        'curriculum': curriculum,
        'educationLevel': educationLevel ?? curriculum, // Sync both for compatibility
        'interests': interests,
        'subjects': subjects,
        if (dateOfBirth != null)
          'date_of_birth': dateOfBirth.millisecondsSinceEpoch,
        if (parentalConsentGiven != null)
          'parental_consent_given': parentalConsentGiven,
      };

      updates.removeWhere((key, value) => value == null);

      await _authService.firestore
          .collection('users')
          .doc(_userModel!.uid)
          .update(updates);

      _userModel = _userModel!.copyWith(
        role: role,
        grade: gradeInt,
        schoolName: schoolName,
        displayName: displayName,
        phoneNumber: phoneNumber,
        curriculum: curriculum,
        educationLevel: educationLevel ?? _userModel!.educationLevel,
        interests: interests,
        subjects: subjects,
        dateOfBirth: dateOfBirth,
        parentalConsentGiven: parentalConsentGiven,
      );

      notifyListeners();
    } catch (e) {
      debugPrint("Error updating profile: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
    await _authService.signOut();
    _userModel = null;
    _requiresEmailVerification = false;
    notifyListeners();
  }

  Future<void> updateLanguage(String lang) async {
    if (_userModel == null) return;
    await _authService.firestore
        .collection('users')
        .doc(_userModel!.uid)
        .update({'preferred_language': lang});
    _userModel = _userModel!.copyWith(preferredLanguage: lang);
    notifyListeners();
  }

  /// Delete account and all associated data (Kenya DPA 2019 Section 40 - Right to Erasure)
  Future<void> deleteAccount() async {
    if (_userModel == null) return;
    try {
      final uid = _userModel!.uid;
      final firestore = _authService.firestore;

      final tickets = await firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in tickets.docs) {
        await doc.reference.delete();
      }

      final activities = await firestore
          .collection('user_activity')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in activities.docs) {
        await doc.reference.delete();
      }

      await firestore.collection('users').doc(uid).delete();

      await _authService.deleteAccount();
      _userModel = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Delete Account Error: $e");
      rethrow;
    }
  }

  Future<void> updateSubscription(int durationInDays) async {
    if (_userModel == null) return;
    final expiry = DateTime.now().add(Duration(days: durationInDays));

    await _authService.firestore
        .collection('users')
        .doc(_userModel!.uid)
        .update({
      'isSubscribed': true,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
      'dailyMessageCount': 0,
      'accessedDocuments': <String>[],
    });

    _userModel = _userModel!.copyWith(
      isSubscribed: true,
      subscriptionExpiry: expiry,
      dailyMessageCount: 0,
      accessedDocuments: const [],
    );
    notifyListeners();
  }

  Future<void> reloadUser() async {
    User? user = _authService.currentUser;
    if (user != null) {
      await user.reload();
      user = _authService.currentUser;
      if (user == null || !user.emailVerified) {
        _requiresEmailVerification = user != null;
        _userModel = null;
        notifyListeners();
        return;
      }
      _requiresEmailVerification = false;
      await _ensureUserProfile(user);
      _listenToUserProfile(user.uid);

      // Mark onboarding complete
      await OfflineService().setStringList('onboarding_complete', ['true']);

      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
