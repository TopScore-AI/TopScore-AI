import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/offline_service.dart';
import '../services/subscription_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  static final AuthProvider instance = AuthProvider();
  final AuthService _authService = AuthService();

  bool _requiresEmailVerification = false;
  bool _isFetchingProfile = false;
  bool _isInitializing = true;
  bool _localOnboardingComplete = false;
  bool _isGuestMode = false;
  bool _isGuestLimitReached = false;
  int _guestMessageCount = 0;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  bool get isProfileComplete =>
      (_userModel?.grade != null) || _localOnboardingComplete;
  bool get requiresEmailVerification => _requiresEmailVerification;
  bool get isGuestMode => _isGuestMode;
  bool get isGuestLimitReached => _isGuestLimitReached;
  int get guestMessageCount => _guestMessageCount;

  /// Persistent device-specific identifier for session linking.
  String get deviceId => OfflineService().getDeviceId();

  bool _isLoading = false;
  bool get isLoading => _isLoading || _isFetchingProfile || _isInitializing;

  bool get isAuthenticated => _userModel != null;

  /// Lets an unauthenticated user explore the app without signing in.
  void enterGuestMode() {
    _isGuestMode = true;
    notifyListeners();
  }

  /// Clears guest mode — called after successful sign-in or explicit exit.
  void exitGuestMode() {
    _isGuestMode = false;
    notifyListeners();
  }

  AuthProvider() {
    _authService.authStateChanges.listen((user) async {
      if (user == null) {
        _userModel = null;
        _requiresEmailVerification = false;
        _isInitializing = false;
        notifyListeners();
        return;
      }

      // If user exists but no model, try to fetch it
      if (_userModel == null && !_isFetchingProfile) {
        await _ensureUserProfile(user);
        _isInitializing = false;
        notifyListeners();
      } else if (_userModel != null) {
        _isInitializing = false;
        notifyListeners();
      }
    });
  }

  /// Whether the user has a currently active (non-expired) subscription.
  bool get hasActiveSubscription {
    if (_userModel == null) return false;
    if (!_userModel!.isSubscribed) return false;

    final expiry = _userModel!.subscriptionExpiry;
    // If subscribed but expiry is missing, we treat as active (matches UI).
    // If expiry is specified, it must be in the future.
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  }

  bool get canSendMessage {
    if (isGuestMode) {
      // Guests can send up to 3 messages globally per device
      return !isGuestLimitReached;
    }
    if (_userModel == null) return false;
    if (hasActiveSubscription) return true;

    // Check if 6 hours have passed since the tracking window started
    if (_userModel!.lastMessageDate != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_userModel!.lastMessageDate!);
      if (elapsed.inHours >= 6) {
        // 6h window expired, count is effectively 0
        return true;
      }
    }

    // Limit to 5 per 6-hour window for Freemium
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
      if (elapsed.inHours < 6) {
        // Still within the 6h window â€” increment
        newCount = _userModel!.dailyMessageCount + 1;
        newDate =
            _userModel!.lastMessageDate!; // preserve original window start
      }
      // else: window expired â€” reset to count=1 with new timestamp
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
      if (kDebugMode) debugPrint("Error incrementing daily message: $e");
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
        if (kDebugMode) debugPrint("Error updating accessed documents: $e");
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

      // Load local states
      _guestMessageCount = OfflineService().getGuestMessageCount();
      _isGuestLimitReached = OfflineService().isGuestLimitReached();

      final onboardingData =
          OfflineService().getStringList('onboarding_complete');
      _localOnboardingComplete =
          onboardingData.isNotEmpty && onboardingData.first == 'true';

      // Handle redirect result (if any) - formerly Web-only but now used for all platforms
      final redirectResult = await _authService.auth.getRedirectResult();
      if (redirectResult.user != null) {
        await _ensureUserProfile(redirectResult.user!);
      }

      User? user = _authService.currentUser;
      if (user != null) {
        if (user.isAnonymous) {
          if (kDebugMode) {
            debugPrint(
                "Anonymous user detected but guest mode is disabled. Signing out...");
          }
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

        await _ensureUserProfile(user);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("AuthProvider init error: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _ensureUserProfile(User user) async {
    _isFetchingProfile = true;
    notifyListeners();
    try {
      final existing = await _authService.getUserProfile(user.uid);
      if (existing != null) {
        _userModel = existing;
      } else {
        // Only create a new profile if it's strictly MISSING from Firestore.
        // This prevents overwriting existing data (Pro status) during network/permissions errors.
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'New User',
          photoURL: user.photoURL,
          role: '',
          grade: null,
          schoolName: '',
        );
        await _authService.updateUserProfile(
            user.uid, newUser.toInitialProfileMap());
        _userModel = newUser;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'AuthProvider: Error fetching user profile. Keeping existing local state if any: $e');
      }
      // If we already have a user model (stale-while-revalidate), we keep it.
      // Otherwise, the user will see a loading/error state rather than a wiped account.
    } finally {
      _isFetchingProfile = false;
      notifyListeners();
    }

    // Start real-time listener for subscription/profile changes
    _startUserDocListener(user.uid);

    // Sync FCM Token
    _syncFCMToken();
  }

  /// Listens to the user's Firestore document so subscription changes
  /// (e.g. from a backend webhook) propagate to the client automatically.
  void _startUserDocListener(String uid) {
    _userDocSubscription?.cancel();
    _userDocSubscription = _authService.firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final updated = UserModel.fromMap(snap.data()!, uid);
      final prev = _userModel;
      _userModel = updated;
      if (prev == null ||
          prev.isSubscribed != updated.isSubscribed ||
          prev.subscriptionExpiry != updated.subscriptionExpiry ||
          prev.dailyMessageCount != updated.dailyMessageCount) {
        notifyListeners();
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('User doc listener error: $e');
    });
  }

  Future<void> _syncFCMToken() async {
    if (_userModel == null || kIsWeb) return;

    try {
      final token = await NotificationService().getToken();
      if (token != null) {
        // We could also store it in SharedPreferences to avoid redundant syncs
        final savedToken =
            OfflineService().getStringList('last_synced_fcm_token').firstOrNull;
        if (savedToken == token) return;

        // Use AuthService to hit the registration endpoint
        // Assuming AuthService has a way to make authenticated requests or we use http directly
        final response = await _authService.registerFCMToken(token);
        if (response) {
          await OfflineService()
              .setStringList('last_synced_fcm_token', [token]);
          if (kDebugMode) debugPrint("✅ FCM Token synced with backend");
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Error syncing FCM token: $e");
    }
  }

  // --- GOOGLE SIGN IN ---
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        final wasGuest = _isGuestMode;
        _requiresEmailVerification = false;
        _isGuestMode = false;
        await _ensureUserProfile(user);

        // Mark onboarding complete on successful sign-in
        await OfflineService().setStringList('onboarding_complete', ['true']);

        if (wasGuest) {
          if (kDebugMode) debugPrint("🔄 AuthProvider: Migrating guest history to ${user.uid}...");
          await _authService.transferGuestHistory('guest', user.uid);
        }

        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Google Sign In Error: $e");
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
      final wasGuest = _isGuestMode;
      _isGuestMode = false;
      await _ensureUserProfile(refreshedUser);

      // Mark onboarding complete on successful sign-in
      await OfflineService().setStringList('onboarding_complete', ['true']);

      if (wasGuest) {
        if (kDebugMode) debugPrint("🔄 AuthProvider: Migrating guest history to ${refreshedUser.uid}...");
        await _authService.transferGuestHistory('guest', refreshedUser.uid);
      }

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint("Email Sign In Error: $e");
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
          if (kDebugMode) debugPrint("Failed to send verification email: $e");
        });

        // Create profile immediately so it's ready when they verify
        final wasGuest = _isGuestMode;
        _isGuestMode = false;
        await _ensureUserProfile(_authService.currentUser ?? user);

        // If they were a guest, we can attempt transfer now (associated with UID, even if not verified yet)
        if (wasGuest) {
          final uid = (_authService.currentUser ?? user).uid;
          if (kDebugMode) debugPrint("🔄 AuthProvider: Migrating guest history to $uid (Pending verification)...");
          await _authService.transferGuestHistory('guest', uid);
        }

        // Require verification before granting access
        _requiresEmailVerification = true;
        _userModel = null;
        notifyListeners();
        return false; // Signals caller to show verification screen
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint("Email Sign Up Error: $e");
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

      // Successfully updated profile = onboarding complete
      _localOnboardingComplete = true;
      await OfflineService().setStringList('onboarding_complete', ['true']);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint("Error updating profile: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
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
      if (kDebugMode) debugPrint("Delete Account Error: $e");
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

  /// Expose auth service for direct Firestore/Auth access when needed
  AuthService get authService => _authService;

  /// Update the user's photo URL in Firestore and Firebase Auth
  Future<void> updatePhotoURL(String url) async {
    if (_userModel == null) return;
    await _authService.firestore
        .collection('users')
        .doc(_userModel!.uid)
        .update({'photoURL': url});
    await _authService.auth.currentUser?.updatePhotoURL(url);
    _userModel = _userModel!.copyWith(photoURL: url);
    notifyListeners();
  }

  /// Reload user profile from Firestore
  Future<void> refreshUser() async {
    if (_userModel == null) return;
    final updated = await _authService.getUserProfile(_userModel!.uid);
    if (updated != null) {
      _userModel = updated;
      notifyListeners();
    }
  }

  /// Increment the guest message count and update limit state.
  Future<void> incrementGuestMessageCount() async {
    await OfflineService().incrementGuestMessageCount();
    _guestMessageCount = OfflineService().getGuestMessageCount();
    _isGuestLimitReached = OfflineService().isGuestLimitReached();
    notifyListeners();
  }

  /// Mark the guest limit as reached for this device.
  Future<void> markGuestLimitReached() async {
    _isGuestLimitReached = true;
    await OfflineService().setGuestLimitReached(true);
    _guestMessageCount = OfflineService().getGuestMessageCount();
    notifyListeners();
  }
}
