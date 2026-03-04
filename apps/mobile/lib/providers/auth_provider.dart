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

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool get requiresEmailVerification => _requiresEmailVerification;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool get isAuthenticated => _userModel != null;

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
        // 24h window expired, count is effectively 0
        return true;
      }
    }

    // Limit to 5 per 24-hour window for Freemium
    return _userModel!.dailyMessageCount < 5;
  }

  Future<void> incrementDailyMessage() async {
    if (_userModel == null) return;
    if (hasActiveSubscription) return; // No tracking for subscribers

    final now = DateTime.now();
    int newCount = 1;
    DateTime newDate = now;

    if (_userModel!.lastMessageDate != null) {
      final elapsed = now.difference(_userModel!.lastMessageDate!);
      if (elapsed.inHours < 24) {
        // Still within the 24h window — increment
        newCount = _userModel!.dailyMessageCount + 1;
        newDate =
            _userModel!.lastMessageDate!; // preserve original window start
      }
      // else: window expired — reset to count=1 with new timestamp
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

  /// Whether the 24h document access window has expired and the list should reset.
  bool get _documentWindowExpired {
    if (_userModel?.lastDocumentAccessDate == null) return true;
    return DateTime.now()
            .difference(_userModel!.lastDocumentAccessDate!)
            .inHours >=
        24;
  }

  // Used by UI to check without side-effects
  bool get canOpenDocument {
    if (_userModel == null) return false;
    if (hasActiveSubscription) return true;
    if (_documentWindowExpired) return true;
    return _userModel!.accessedDocuments.length < 5;
  }

  Future<bool> tryAccessDocument(String docId) async {
    if (_userModel == null) return false;

    // Check if trial or premium
    final isPremiumOrTrial =
        await SubscriptionService().isSessionPremiumOrTrial();
    if (isPremiumOrTrial) return true;

    // Reset the document list if 24h window has expired
    List<String> currentDocs = List<String>.from(_userModel!.accessedDocuments);
    DateTime windowStart = _userModel!.lastDocumentAccessDate ?? DateTime.now();

    if (_documentWindowExpired) {
      currentDocs = [];
      windowStart = DateTime.now();
    }

    // Already accessed within this window?
    if (currentDocs.contains(docId)) {
      return true;
    }

    // If limits not reached
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

    // Denied payload
    return false;
  }

  bool get needsRoleSelection => false;

  Future<void> init() async {
    _setLoading(true);
    try {
      await _authService.ensureBlockedEmailDomainsLoaded();
      User? user = _authService.currentUser;
      if (user != null) {
        if (user.isAnonymous) {
          debugPrint(
              "Anonymous user detected but guest mode is disabled. Signing out...");
          await _authService.signOut();
          _userModel = null;
          return;
        }

        await user.reload();
        user = _authService.currentUser;
        if (user == null || !user.emailVerified) {
          _requiresEmailVerification = user != null;
          _userModel = null;
          return;
        }

        _userModel = await _authService.getUserProfile(user.uid);
      }
    } catch (e) {
      debugPrint("AuthProvider init error: $e");
    } finally {
      _setLoading(false);
    }
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
        role: '',
        grade: null,
        schoolName: '',
      );
      await _authService.updateUserProfile(user.uid, newUser.toMap());
      _userModel = newUser;
    }
  }

  // --- GOOGLE SIGN IN ---
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        _requiresEmailVerification = false;
        await _ensureUserProfile(user);

        // Mark onboarding complete on successful sign-in
        await OfflineService().setStringList('onboarding_complete', ['true']);

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
    return false;
  }

  // --- EMAIL SIGN IN ---
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final credential = await _authService.signInWithEmail(email, password);
      final user = credential?.user;
      if (user == null) return false;

      await user.reload();
      final refreshedUser = _authService.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        _requiresEmailVerification = true;
        await _authService.sendEmailVerification();
        _userModel = null;
        notifyListeners();
        return false;
      }

      _requiresEmailVerification = false;
      await _ensureUserProfile(refreshedUser);

      // Mark onboarding complete on successful sign-in
      await OfflineService().setStringList('onboarding_complete', ['true']);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Email Sign In Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- EMAIL SIGN UP ---
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
        // Set display name on the Firebase Auth user first
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
          await user.reload();
        }

        // Send verification email
        await user.sendEmailVerification().catchError((e) {
          debugPrint("Failed to send verification email: $e");
        });

        // Create profile immediately so it's ready when they verify
        await _ensureUserProfile(_authService.currentUser ?? user);

        // Require verification before granting access
        _requiresEmailVerification = true;
        _userModel = null;
        notifyListeners();
        return false; // Signals caller to show verification screen
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
    if (refreshedUser == null || !refreshedUser.emailVerified) {
      _requiresEmailVerification = true;
      notifyListeners();
      return false;
    }
    _requiresEmailVerification = false;
    await _ensureUserProfile(refreshedUser);

    // Mark onboarding complete
    await OfflineService().setStringList('onboarding_complete', ['true']);

    notifyListeners();
    return true;
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
        'educationLevel':
            educationLevel ?? curriculum, // Sync both for compatibility
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

      // Delete user's support tickets
      final tickets = await firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in tickets.docs) {
        await doc.reference.delete();
      }

      // Delete user's activity records
      final activities = await firestore
          .collection('user_activity')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in activities.docs) {
        await doc.reference.delete();
      }

      // Delete user profile document
      await firestore.collection('users').doc(uid).delete();

      // Delete Firebase Auth account
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

      // Mark onboarding complete
      await OfflineService().setStringList('onboarding_complete', ['true']);

      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
