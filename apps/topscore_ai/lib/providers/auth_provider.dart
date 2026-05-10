import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show studyDb;
import '../models/user_model.dart';
import '../repositories/synced_study_repository.dart';
import '../services/auth_service.dart';
import '../services/chat_mirror.dart';
import '../services/firestore_artifact_service.dart';
import '../services/isar_service.dart';
import '../services/migration/artifact_migration_runner.dart';
import '../services/migration/chat_migration_runner.dart';
import '../services/offline_service.dart';
import '../services/subscription_service.dart';
import '../services/notification_service.dart';
import '../services/device_id_service.dart';

class AuthProvider with ChangeNotifier {
  static final AuthProvider instance = AuthProvider();
  final AuthService _authService = AuthService();

  bool _requiresEmailVerification = false;
  bool _isFetchingProfile = false;
  bool _isInitializing = true;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isNotifyPending = false;

  @override
  void notifyListeners() {
    if (_isNotifyPending) return;
    _isNotifyPending = true;
    Future.microtask(() {
      _isNotifyPending = false;
      super.notifyListeners();
    });
  }

  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  StreamSubscription<String>? _fcmTokenSubscription;

  bool get isProfileComplete {
    final hasGrade = _userModel?.grade != null;
    final hasPreferredName = _userModel?.preferredName != null &&
        _userModel!.preferredName!.trim().isNotEmpty;
    return hasGrade && hasPreferredName;
  }

  bool get requiresEmailVerification => _requiresEmailVerification;

  /// Persistent device-specific identifier for session linking.
  /// Delegates to DeviceIdService which uses FlutterSecureStorage.
  /// Use [getDeviceIdAsync] for the authoritative value.
  String get deviceId => OfflineService().getDeviceId();

  Future<String> getDeviceIdAsync() => DeviceIdService.get();

  bool _isLoading = false;
  bool get isLoading => _isLoading || _isFetchingProfile || _isInitializing;
  bool get isInitializing => _isInitializing;

  bool get isAuthenticated => _userModel != null;

  AuthProvider() {
    _authService.authStateChanges.listen((user) async {
      if (kDebugMode) {
        debugPrint('[TOPSCORE] Auth State Change: ${user?.uid ?? 'null'}');
      }
      if (user == null) {
        _userModel = null;
        _requiresEmailVerification = false;
        if (!_isInitializing) {
          _isInitializing = false;
          notifyListeners();
        }
        return;
      }

      // BLOCK ANONYMOUS USERS - All users must be verified Firebase users
      if (user.isAnonymous) {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] Blocking anonymous user - signing out');
        }
        await _authService.signOut();
        _userModel = null;
        _requiresEmailVerification = false;
        _isInitializing = false;
        notifyListeners();
        return;
      }

      // Check verification status immediately on every state change (sign-in/reload/restore)
      final isVerified = user.emailVerified;
      if (!isVerified) {
        _requiresEmailVerification = true;
        _userModel = null;
        _isInitializing = false;
        notifyListeners();
        return;
      }

      _requiresEmailVerification = false;

      // If user exists and is verified but no model, try to fetch it
      if (_userModel == null && !_isFetchingProfile) {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] Fetching profile for ${user.uid}...');
        }
        await _ensureUserProfile(user);
        _isInitializing = false;
        notifyListeners();
      } else if (_userModel != null) {
        _isInitializing = false;
        notifyListeners();
      }
    });

    // Global token refresh error handler
    _startTokenRefreshMonitoring();
  }

  StreamSubscription<User?>? _tokenMonitorSubscription;

  /// Monitor for token refresh failures and force re-authentication when needed
  void _startTokenRefreshMonitoring() {
    _tokenMonitorSubscription?.cancel();
    _tokenMonitorSubscription = _authService.auth.idTokenChanges().listen(
      (user) async {
        if (user == null) return;

        try {
          // Periodically verify token is still valid
          await user.getIdToken(false);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[TOPSCORE] Token refresh failed: $e');
          }

          // Check if this is a token expiration error (400 Bad Request from securetoken.googleapis.com)
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('400') ||
              errorString.contains('bad request') ||
              errorString.contains('token') ||
              errorString.contains('expired') ||
              errorString.contains('invalid')) {
            if (kDebugMode) {
              debugPrint(
                  '[TOPSCORE] Detected expired/invalid token. Forcing sign out...');
            }

            // Force sign out to clear invalid session
            await signOut();

            // Notify UI to show re-authentication dialog
            _safeNotifyTokenExpired();
          }
        }
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] Token monitoring error: $e');
        }
      },
    );
  }

  /// Safely notify listeners about token expiration without causing state conflicts
  void _safeNotifyTokenExpired() {
    // This will trigger UI to show a dialog or redirect to login
    notifyListeners();
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
    // Guests are allowed to send messages until the backend returns a limit error
    if (_userModel == null) return true;
    if (hasActiveSubscription) return true;

    // For new users or when window has expired, allow messages
    if (_userModel!.freeMessagesLastAt == null) {
      // First time user - allow if count is less than 6
      return _userModel!.freeMessageCount < 6;
    }

    // Check if 12 hours have passed since the tracking window started
    final now = DateTime.now();
    final elapsed = now.difference(_userModel!.freeMessagesLastAt!);
    if (elapsed.inHours >= 12) {
      // Window expired - allow sending (backend will reset count)
      return true;
    }

    // Within the 12-hour window - check if under limit
    return _userModel!.freeMessageCount < 6;
  }

  /// Called by the chat layer when the server returns FREE_LIMIT_REACHED
  /// so the UI can react immediately without a round-trip.
  void onServerLimitReached({required bool requiresAccount}) {
    notifyListeners();
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
    // We now allow opening all documents for reading
    return true;
  }

  /// Whether the user can download or save a document (limit 6 per 24h for free users)
  bool get canExportDocument {
    if (_userModel == null) return false;
    if (hasActiveSubscription) return true;
    if (_documentWindowExpired) return true;
    return _userModel!.accessedDocuments.length < 6;
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
    if (currentDocs.length < 6) {
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
    if (kDebugMode) debugPrint('[TOPSCORE] Initializing AuthProvider...');
    // 2. Background non-critical initialization
    unawaited(() async {
      try {
        await _authService.ensureBlockedEmailDomainsLoaded();

        // Handle redirect result (if any)
        final redirectResult = await _authService.auth.getRedirectResult();
        if (redirectResult.user != null) {
          await _ensureUserProfile(redirectResult.user!);
        }
      } catch (e) {
        if (kDebugMode) debugPrint("AuthProvider background init error: $e");
      }
    }());

    // 3. Auth State Resolution
    try {
      User? user = _authService.currentUser;
      if (user != null) {
        // If we have a user, set initializing to false immediately so the UI can render
        // with cached/placeholder data while the profile syncs.
        _isInitializing = false;
        notifyListeners();

        // BLOCK ANONYMOUS USERS - All users must be verified Firebase users
        if (user.isAnonymous) {
          if (kDebugMode) {
            debugPrint(
                '[TOPSCORE] Blocking anonymous user during init - signing out');
          }
          await _authService.signOut();
          _userModel = null;
          _isInitializing = false;
          notifyListeners();
        } else {
          // Sync profile in background
          unawaited(() async {
            try {
              await user.reload();
              final refreshedUser = _authService.currentUser;
              final isVerified = refreshedUser?.emailVerified ?? false;

              if (kDebugMode) {
                debugPrint(
                    '[TOPSCORE] Init Auth Sync: uid=${refreshedUser?.uid}, verified=$isVerified');
              }

              if (refreshedUser == null || !isVerified) {
                _requiresEmailVerification = refreshedUser != null;
                _userModel = null;
                notifyListeners();
                return;
              }

              // Explicitly set to false once verified to ensure router clears any /verify-email redirect
              _requiresEmailVerification = false;

              // Verify token and fetch profile
              await refreshedUser.getIdToken(true);
              await _ensureUserProfile(refreshedUser);
            } catch (e) {
              if (kDebugMode) {
                debugPrint("AuthProvider background profile sync error: $e");
              }
            } finally {
              _isInitializing = false;
              _setLoading(false);
              notifyListeners();
            }
          }());
        }
      } else {
        _isInitializing = false;
      }
    } catch (e) {
      _isInitializing = false;
      if (kDebugMode) debugPrint("AuthProvider init error: $e");
    } finally {
      // Ensure we always stop initializing so the app doesn't hang on splash
      _isInitializing = false;
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _ensureUserProfile(User user) async {
    _isFetchingProfile = true;
    notifyListeners();
    try {
      final existing = await _authService.getUserProfile(user.uid);
      if (existing != null) {
        _userModel = existing;
        // Check and expire subscription if needed
        await _checkAndExpireSubscription();

        // Ensure free user limit fields exist (migration for existing users)
        if (existing.freeMessageCount == 0 &&
            existing.freeMessagesLastAt == null &&
            !existing.isSubscribed) {
          try {
            await _authService.firestore
                .collection('users')
                .doc(user.uid)
                .update({
              'free_message_count': 0,
              'free_messages_last_at': null,
            });
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Failed to initialize free user limit fields: $e');
            }
          }
        }
      } else {
        // Only create a new profile if it's strictly MISSING from Firestore.
        // This prevents overwriting existing data (Pro status) during network/permissions errors.
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'New User',
          photoURL: user.photoURL,
          role: 'student', // Default opt-in role
          grade:
              null, // Default to null so 'Recommended' shows all files initially
          schoolName: 'Self Study',
          curriculum: 'CBC', // Default baseline
          freeMessageCount: 0, // Initialize free user limits
          freeMessagesLastAt: null,
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

    // Kick off artifact mirror: migrate local rows once, then attach
    // Firestore listeners. Non-blocking so the UI stays responsive.
    unawaited(_initArtifactSync(user.uid));
  }

  /// Phase A: pdf_summary. Phase B adds quiz + flashcard. Phases C–D extend further.
  static const List<String> _syncedArtifactTypes = [
    'pdf_summary',
    'quiz',
    'flashcard',
  ];

  Future<void> _initArtifactSync(String uid) async {
    try {
      final repo = studyDb;
      FirestoreArtifactService? sharedFirestore;
      if (repo is SyncedStudyRepository) {
        repo.setActiveUser(uid);
        sharedFirestore = repo.firestoreService;

        final runner = ArtifactMigrationRunner(
          repo: repo.inner,
          firestore: sharedFirestore,
        );
        await runner.runForTypes(uid: uid, types: _syncedArtifactTypes);

        for (final type in _syncedArtifactTypes) {
          await repo.attachListenerForType(type);
        }
      }

      // Phase C: chat mirror + chat migration. Reuse the Firestore service
      // instance from the study repo when available so writes share the same
      // SDK transport / offline queue.
      final firestore = sharedFirestore ?? FirestoreArtifactService();
      IsarService().mirror = ChatMirror(uid: uid, firestore: firestore);

      final chatRunner =
          ChatMigrationRunner(isar: IsarService(), firestore: firestore);
      await chatRunner.run(uid: uid);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthProvider] artifact sync init failed: $e');
      }
    }
  }

  void _teardownArtifactSync() {
    try {
      final repo = studyDb;
      if (repo is SyncedStudyRepository) {
        repo.detachListeners();
        repo.setActiveUser(null);
      }
      IsarService().mirror = null;
    } catch (_) {}
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
      _userModel = updated;
      // Always notify when the user document changes to ensure router redirects
      // (onboarding/verification) trigger immediately.
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) debugPrint('User doc listener error: $e');
    });
  }

  Future<void> _syncFCMToken() async {
    if (_userModel == null) return;

    try {
      final token = await NotificationService().getToken();
      if (token != null) {
        await _registerFCMToken(token);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Error syncing FCM token: $e");
    }

    // Firebase rotates FCM tokens (reinstall, cleared app data, APNS
    // re-registration, long idle). Without this listener, a refreshed token
    // never reaches the backend and nudges silently stop arriving.
    _fcmTokenSubscription?.cancel();
    _fcmTokenSubscription = NotificationService().onTokenRefresh.listen(
      (newToken) async {
        if (kDebugMode) debugPrint("🔄 FCM token refreshed — re-registering");
        await _registerFCMToken(newToken);
      },
      onError: (e) {
        if (kDebugMode) debugPrint("❌ FCM token refresh stream error: $e");
      },
    );
  }

  /// Called by main.dart after NotificationService.initialize() completes to
  /// ensure the FCM token is registered even if auth resolved first.
  Future<void> reSyncFCMToken() async {
    if (_userModel == null) return;
    try {
      final token = await NotificationService().getToken();
      if (token != null) await _registerFCMToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint("❌ reSyncFCMToken error: $e");
    }
  }

  /// Forced re-sync of the FCM token regardless of locally cached state.
  /// Useful for settings toggles or manual troubleshooting.
  Future<void> forceSyncFCMToken() async {
    if (_userModel == null) return;
    try {
      final token = await NotificationService().getToken();
      if (token != null) {
        await _registerFCMToken(token, force: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("❌ forceSyncFCMToken error: $e");
    }
  }

  Future<void> _registerFCMToken(String token, {bool force = false}) async {
    final offline = OfflineService();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Check if we've already pushed this exact token to the backend recently.
    final savedToken =
        offline.getStringList('last_synced_fcm_token').firstOrNull;
    final lastSyncMs = offline.getInt('last_fcm_sync_ms') ?? 0;

    // We force a re-sync if:
    // a) The token has changed
    // b) It's been more than 7 days since the last sync (handles backend DB resets)
    // c) The caller explicitly requested a force sync
    final sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    final isStale = (now - lastSyncMs) > sevenDaysMs;

    if (!force && !isStale && savedToken == token) {
      return;
    }

    final ok = await _authService.registerFCMToken(token);
    if (ok) {
      await offline.setStringList('last_synced_fcm_token', [token]);
      await offline.setInt('last_fcm_sync_ms', now);
      if (kDebugMode) {
        debugPrint(
            "✅ FCM Token synced with backend (Force: $force, Stale: $isStale)");
      }
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

      // Force refresh the token to ensure 'email_verified' claim is updated for Firestore
      await refreshedUser.getIdToken(true);

      await _ensureUserProfile(refreshedUser);

      // Mark onboarding complete on successful sign-in
      await OfflineService().setStringList('onboarding_complete', ['true']);

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

        // Create profile immediately so it's ready when they verify.
        // We catch errors here because if Firestore rules require email verification,
        // this call will fail. That's fine; the profile will be synced/created
        // once they verify and reloadAndCheckEmailVerified is called.
        try {
          await _ensureUserProfile(_authService.currentUser ?? user);
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '[TOPSCORE] Pre-verification profile creation skipped (likely due to Firestore rules): $e');
          }
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

  // --- PASSWORDLESS SIGN IN (EMAIL LINK) ---
  Future<void> sendLoginLink(String email) async {
    try {
      _setLoading(true);
      await _authService.sendSignInLinkToEmail(email);
      // Persist email locally so we can complete sign-in when they return
      await OfflineService().setStringList('signin_email', [email]);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint("Send Login Link Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> handleAuthLink(String link) async {
    if (kDebugMode) debugPrint('[TOPSCORE] Processing Auth Link: $link');
    try {
      _setLoading(true);

      final uri = Uri.tryParse(link);
      if (uri == null) return false;

      // Firebase often wraps the actual action URL in a 'link' parameter
      // e.g. https://<app>.firebaseapp.com/__/auth/links?link=https://<app>.ai/__/auth/action?mode=...
      String effectiveLink = link;
      if (uri.queryParameters.containsKey('link')) {
        effectiveLink = uri.queryParameters['link']!;
        if (kDebugMode) {
          debugPrint('[TOPSCORE] Extracted nested link: $effectiveLink');
        }
      }

      final actionUri = Uri.tryParse(effectiveLink) ?? uri;
      final mode = actionUri.queryParameters['mode'];
      final oobCode = actionUri.queryParameters['oobCode'];

      // 1. Handle Email Verification
      if (mode == 'verifyEmail' && oobCode != null) {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] Applying email verification code...');
        }
        await _authService.applyActionCode(oobCode);

        // Refresh the user and check status immediately
        final success = await reloadAndCheckEmailVerified();
        if (success) {
          if (kDebugMode) {
            debugPrint('[TOPSCORE] Email verification successful via link.');
          }
          return true;
        }
        return false;
      }

      // 2. Handle Password Reset (Redirect to reset screen)
      if (mode == 'resetPassword' && oobCode != null) {
        // We'll store the code and let the router handle navigation or show a dialog
        await OfflineService().setStringList('pending_reset_code', [oobCode]);
        notifyListeners();
        return false;
      }

      // 3. Handle Email Sign-In (Magic Link)
      if (_authService.isSignInWithEmailLink(effectiveLink)) {
        // Try to get the email from local storage first (same device flow)
        String? email =
            OfflineService().getStringList('signin_email').firstOrNull;

        // Fallback: extract email from the link itself (cross-device / cold-start)
        if (email == null || email.isEmpty) {
          email = actionUri.queryParameters['email'];
        }

        if (email == null || email.isEmpty) {
          // Can't complete sign-in without the email — store the pending link
          // and let the router show a prompt to enter the email.
          await OfflineService()
              .setStringList('pending_email_link', [effectiveLink]);
          if (kDebugMode) {
            debugPrint(
                'Email link received but no email found — stored as pending');
          }
          notifyListeners();
          return false;
        }

        final credential =
            await _authService.signInWithEmailLink(email, effectiveLink);
        final user = credential.user;
        if (user != null) {
          await _ensureUserProfile(user);
          await OfflineService().setStringList('onboarding_complete', ['true']);
          // Clear stored email and any pending link
          await OfflineService().setStringList('signin_email', []);
          await OfflineService().setStringList('pending_email_link', []);
          notifyListeners();
          return true;
        }
      }

      if (kDebugMode) {
        debugPrint('[TOPSCORE] Link is not a recognized auth action.');
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint("Auth Link Processing Error: $e");
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

    try {
      if (kDebugMode) debugPrint('[TOPSCORE] Forcing verification check...');

      // 1. Force a reload of the user profile from the server
      await user.reload();

      // 2. Force a refresh of the ID token to ensure the 'email_verified' claim is fresh
      await user.getIdToken(true);

      final refreshedUser = _authService.currentUser;
      final isVerified = refreshedUser?.emailVerified ?? false;

      if (kDebugMode) {
        debugPrint('[TOPSCORE] Refreshed verification status: $isVerified');
      }

      if (refreshedUser == null || !isVerified) {
        _requiresEmailVerification = refreshedUser != null;
        notifyListeners();
        return false;
      }

      _requiresEmailVerification = false;

      // Force refresh the token to ensure 'email_verified' claim is updated for Firestore
      await refreshedUser.getIdToken(true);

      await _ensureUserProfile(refreshedUser);

      // Mark onboarding complete
      await OfflineService().setStringList('onboarding_complete', ['true']);

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TOPSCORE] Error during verification reload: $e');
      }
      return false;
    }
  }

  /// Lightweight verification check used on app resume to ensure state is fresh.
  Future<void> checkEmailVerificationOnResume() async {
    final user = _authService.currentUser;
    // Only check if we are currently "stuck" in a state requiring verification
    if (user != null && _requiresEmailVerification) {
      await reloadAndCheckEmailVerified();
    }
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
    String? preferredName,
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
        if (preferredName != null) 'preferred_name': preferredName,
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
        preferredName: preferredName,
      );

      // Successfully updated profile = onboarding complete
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
    _fcmTokenSubscription?.cancel();
    _fcmTokenSubscription = null;
    _tokenMonitorSubscription?.cancel();
    _tokenMonitorSubscription = null;
    _teardownArtifactSync();
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
      _setLoading(true);
      final uid = _userModel!.uid;
      final firestore = _authService.firestore;

      // Cancel listeners before deleting so we don't get spurious updates
      _userDocSubscription?.cancel();
      _userDocSubscription = null;
      _fcmTokenSubscription?.cancel();
      _fcmTokenSubscription = null;
      _tokenMonitorSubscription?.cancel();
      _tokenMonitorSubscription = null;
      _teardownArtifactSync();

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
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSubscription(int durationInDays) async {
    if (_userModel == null) return;
    final expiry = DateTime.now().add(Duration(days: durationInDays));

    await _authService.firestore
        .collection('users')
        .doc(_userModel!.uid)
        .update({
      'tier': 'Premium',
      'isSubscribed': true,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
      'free_message_count': 0,
      'accessedDocuments': <String>[],
    });

    _userModel = _userModel!.copyWith(
      isSubscribed: true,
      subscriptionExpiry: expiry,
      freeMessageCount: 0,
      accessedDocuments: const [],
    );
    notifyListeners();
  }

  /// Award XP to the user for achievements or learning progress.
  Future<void> awardXp(int amount, String reason) async {
    if (_userModel == null) return;

    try {
      final newXp = _userModel!.xp + amount;
      // Simple leveling logic: every 1000 XP is a level
      final newLevel = (newXp / 1000).floor() + 1;

      await _authService.firestore
          .collection('users')
          .doc(_userModel!.uid)
          .update({
        'xp': newXp,
        'level': newLevel,
      });

      _userModel = _userModel!.copyWith(
        xp: newXp,
        level: newLevel,
      );

      notifyListeners();

      if (kDebugMode) {
        debugPrint(
            "🏆 Awarded $amount XP for: $reason. New Totals: $newXp XP (Lvl $newLevel)");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error awarding XP: $e");
    }
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

      // Force refresh the token to ensure 'email_verified' claim is updated for Firestore
      await user.getIdToken(true);

      await _ensureUserProfile(user);

      // Mark onboarding complete
      await OfflineService().setStringList('onboarding_complete', ['true']);

      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return; // Skip if no change
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
      // Check and handle expired subscriptions
      await _checkAndExpireSubscription();
      notifyListeners();
    }
  }

  /// Check if subscription has expired and update Firestore if needed
  Future<void> _checkAndExpireSubscription() async {
    if (_userModel == null) return;

    // Only check if user is marked as subscribed
    if (!_userModel!.isSubscribed) return;

    final expiry = _userModel!.subscriptionExpiry;

    // If no expiry date is set, treat as active (legacy subscriptions)
    if (expiry == null) return;

    // Check if subscription has expired
    final now = DateTime.now();
    if (expiry.isBefore(now)) {
      if (kDebugMode) {
        debugPrint(
            '[TOPSCORE] Subscription expired on ${expiry.toIso8601String()}. Updating user status...');
      }

      try {
        // Update Firestore to mark subscription as expired
        await _authService.firestore
            .collection('users')
            .doc(_userModel!.uid)
            .update({
          'tier': 'Free',
          'isSubscribed': false,
        });

        // Update local model
        _userModel = _userModel!.copyWith(isSubscribed: false);

        if (kDebugMode) {
          debugPrint('[TOPSCORE] Subscription status updated to expired.');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] Error updating expired subscription: $e');
        }
      }
    }
  }
}
