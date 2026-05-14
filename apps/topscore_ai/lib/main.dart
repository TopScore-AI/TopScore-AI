import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'providers/auth_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/resources_provider.dart';
import 'providers/ai_tutor_history_provider.dart';

import 'providers/tutor_connection_provider.dart';
import 'providers/search_provider.dart';
import 'providers/notification_provider.dart';

import 'tutor_client/chat_controller.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/sharing_service.dart';
import 'router.dart' as app_router;

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'services/analytics_service.dart';
import 'services/recovery_service.dart';
import 'config/app_theme.dart';

import 'services/isar_service.dart';
import 'repositories/study_repository.dart';
import 'repositories/study_repository_factory.dart';

late StudyRepository studyDb;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for the background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    debugPrint("Handling a background message: ${message.messageId}");
    debugPrint("Message data: ${message.data}");
    debugPrint("Message notification: ${message.notification?.title}");
  }

  // CRITICAL: Initialize local database (Isar) in the background isolate
  // so that showNotification can persist the notification to the internal center.
  try {
    await IsarService().init();
    studyDb = await createStudyRepository();
  } catch (e) {
    if (kDebugMode) debugPrint("Background Isar init error (non-fatal): $e");
  }

  // Data-only messages (no notification block) - we handle display
  // This is the primary path now that backend sends data-only messages
  if (message.data.isNotEmpty) {
    try {
      final title = message.data['title'] ?? 'TopScore AI Update';
      final body = message.data['body'] ?? '';
      final route = (message.data['route'] as String?)?.trim();

      if (body.isNotEmpty) {
        final service = NotificationService();
        await service.initialize();
        await service.showNotification(
          id: message.messageId.hashCode, // Use messageId for deduplication
          title: title,
          body: body,
          payload: (route != null && route.startsWith('/')) ? route : null,
          type: (message.data['nudge_type'] as String?) ?? 'system',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error showing background notification: $e');
    }
  }
  // Legacy: notification block (should not happen with new backend)
  // Keep for backward compatibility during transition
  else if (message.notification != null) {
    if (kDebugMode) {
      debugPrint(
          '⚠️  Received notification block (legacy) - backend should send data-only');
    }
  }
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Enable Edge-to-Edge display for Android 15+ (SDK 35)
  // This makes the status and navigation bars transparent and allows the app to draw behind them.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  // Set the background messaging handler early on, as a named top-level function
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Enable clean URLs for web (removes # from URLs)
  usePathUrlStrategy();

  // Parallel Initialization: Run independent core services simultaneously to speed up boot.
  // We wait for these critical core services before rendering the first frame.
  await Future.wait([
    // 1. Firebase Initialization (handled with error safety)
    () async {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          if (kDebugMode) {
            await AnalyticsService.instance.enableDebugMode();
          }

          // Initialize Firebase Crashlytics (Non-web only)
          if (!kIsWeb) {
            FlutterError.onError =
                FirebaseCrashlytics.instance.recordFlutterFatalError;
            PlatformDispatcher.instance.onError = (error, stack) {
              FirebaseCrashlytics.instance
                  .recordError(error, stack, fatal: true);
              return true;
            };
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[TOPSCORE] Firebase init error: $e');
      }
    }(),

    // 2. Offline Service (Hive/Prefs)
    () async {
      try {
        await OfflineService().init();
      } catch (e) {
        if (kDebugMode) debugPrint('Offline init error: $e');
      }
    }(),
  ]);

  // Sequential Initialization for Isar to prevent race conditions
  // (Both services might try to open the DB if run concurrently)
  bool isarInitFailed = false;
  String isarErrorStr = "";
  try {
    await IsarService().init();
    studyDb = await createStudyRepository();
  } catch (e) {
    if (kDebugMode) debugPrint('Isar/Repository init error: $e');
    isarInitFailed = true;
    isarErrorStr = e.toString();
  }

  // Modern Firestore Persistence settings (replaces legacy persistenceEnabled)
  try {
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[TOPSCORE] Firestore settings error: $e');
  }

  if (isarInitFailed) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.storage, color: Colors.red, size: 64),
                    const SizedBox(height: 24),
                    const Text(
                      'Storage Error',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'TopScore AI could not access local storage. This usually happens if your device is completely out of storage space or the local database is corrupted.\n\nPlease free up some space, or try clearing the app data/cache in your device settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isarErrorStr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }


  runApp(const MyApp());
}

Future<void> setupInteractedMessage() async {
  // Handle background/terminated messages
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleMessage(initialMessage);
  }
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  // Track processed message IDs to prevent duplicates
  final Set<String> processedMessageIds = {};

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('Foreground message received: ${message.messageId}');
    }

    // Deduplication: Skip if we've already processed this message
    final messageId = message.messageId;
    if (messageId != null && processedMessageIds.contains(messageId)) {
      if (kDebugMode) {
        debugPrint('⚠️  Duplicate message detected, skipping: $messageId');
      }
      return;
    }
    if (messageId != null) {
      processedMessageIds.add(messageId);
      // Clean up old IDs (keep last 100)
      if (processedMessageIds.length > 100) {
        processedMessageIds.remove(processedMessageIds.first);
      }
    }

    // Data-only messages (primary path with new backend)
    if (message.data.containsKey('title') || message.data.containsKey('body')) {
      String title = message.data['title'] ?? "TopScore AI Update";
      String body = message.data['body'] ?? "";

      if (body.isEmpty && message.notification != null) {
        body = message.notification!.body ?? "";
      }
      if (title == "TopScore AI Update" && message.notification != null) {
        title = message.notification!.title ?? title;
      }

      // Personalize with user's first name
      try {
        final auth = AuthProvider.instance;
        final name = auth.userModel?.displayName.split(' ')[0];
        if (name != null && name.isNotEmpty && !body.contains(name)) {
          body = "Hi $name, $body";
        }
      } catch (_) {}

      final route = (message.data['route'] as String?)?.trim();
      await NotificationService().showNotification(
        id: messageId?.hashCode ?? message.data.hashCode,
        title: title,
        body: body,
        payload: (route != null && route.startsWith('/')) ? route : null,
        type: (message.data['nudge_type'] as String?) ?? 'system',
      );
    }
    // Legacy: notification block (should not happen with new backend)
    else if (message.notification != null) {
      if (kDebugMode) {
        debugPrint(
            '⚠️  Received notification block (legacy) - backend should send data-only');
      }

      final notification = message.notification!;
      String body = notification.body ?? "";

      // Personalize with user's first name
      try {
        final auth = AuthProvider.instance;
        final name = auth.userModel?.displayName.split(' ')[0];
        if (name != null && name.isNotEmpty && !body.contains(name)) {
          body = "Hi $name, $body";
        }
      } catch (_) {}

      final route = (message.data['route'] as String?)?.trim();
      await NotificationService().showNotification(
        id: notification.hashCode,
        title: notification.title ?? "TopScore AI Update",
        body: body,
        payload: (route != null && route.startsWith('/')) ? route : null,
        type: (message.data['nudge_type'] as String?) ?? 'system',
      );
    }
  });
}

void _handleMessage(RemoteMessage message) {
  // Backend nudge workers set data['route'] = '/ai-tutor' | '/subscription' | etc.
  // Honor that first; fall back to the legacy 'screen' key for older payloads.
  final data = message.data;
  final route = (data['route'] as String?)?.trim();
  if (route != null && route.isNotEmpty && route.startsWith('/')) {
    _navigateTo(route);
    return;
  }

  if (data['screen'] == 'subscription_page') {
    _navigateTo('/subscription');
  }
}

void _navigateTo(String path) {
  // Defer slightly so the app frame is up when the router receives the push.
  Future.delayed(const Duration(milliseconds: 100), () {
    try {
      app_router.router.go(path);
    } catch (e) {
      if (kDebugMode) debugPrint('[TOPSCORE] Failed to navigate to $path: $e');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider;
  late final DownloadProvider _downloadProvider;
  late final SettingsProvider _settingsProvider;
  late final NavigationProvider _navigationProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final ResourcesProvider _resourcesProvider;
  late final AiTutorHistoryProvider _aiTutorHistoryProvider;
  late final TutorConnectionProvider _tutorConnectionProvider;
  late final AppLinks _appLinks;

  // Track the last UID we synced so _syncAnalyticsUser only fires once per sign-in.
  String? _lastSyncedUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider.instance;
    _downloadProvider = DownloadProvider();
    _settingsProvider = SettingsProvider();
    _navigationProvider = NavigationProvider();
    _connectivityProvider = ConnectivityProvider();
    _resourcesProvider = ResourcesProvider();
    _aiTutorHistoryProvider = AiTutorHistoryProvider();
    _tutorConnectionProvider = TutorConnectionProvider();


    // Initialize deep link handling for app shortcuts and auth redirects
    _appLinks = AppLinks();
    _initDeepLinks();

    // Defer initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Remove native splash immediately — don't rely on individual screens
      FlutterNativeSplash.remove();

      // Initialize notifications FIRST so FCM token is available when
      // auth resolves and _syncFCMToken() is called.
      // Initialize notifications for ALL platforms (Web, Android, iOS)
      NotificationService().initialize().then((_) {
        setupInteractedMessage();
        // Re-sync FCM token now that the service is ready — handles the
        // case where auth resolved before initialize() completed.
        AuthProvider.instance.reSyncFCMToken();
      }).catchError((e) {
        if (kDebugMode) debugPrint('Notification init error: $e');
      });

      // Connect to WebSocket immediately using Device ID (Token-free flow)
      final deviceId = _authProvider.deviceId;
      if (deviceId.isNotEmpty) {
        _tutorConnectionProvider.preconnect(deviceId).catchError((e) {
          if (kDebugMode) debugPrint('[TOPSCORE] preconnect error: $e');
        });
      }

      _authProvider.init().then((_) {
        // Once Firebase resolves, if we have a real user, upgrade the connection
        final userId = _authProvider.userModel?.uid;
        if (userId != null) {
          _tutorConnectionProvider.updateUserId(userId).catchError((e) {
            if (kDebugMode) debugPrint('[TOPSCORE] updateUserId error: $e');
          });
        }
      }).catchError((e) {
        if (kDebugMode) debugPrint('[TOPSCORE] auth init error: $e');
      });
      _downloadProvider.init();
      _resourcesProvider.loadRecentlyOpened();

      // Set analytics user properties once auth resolves
      _authProvider.addListener(_syncAnalyticsUser);

      // Initialize sharing intent listener (Mobile Only)
      if (!kIsWeb) {
        SharingService.init(context);

        // Execute OS background death recovery routing
        RecoveryService.checkAndRouteRecovery(app_router.router);
      }

      _initDeferredServices();

    });
  }

  Future<void> _initDeferredServices() async {
    // Pre-load Google Fonts in the background (mobile only).
    if (!kIsWeb) {
      unawaited(() async {
        try {
          await GoogleFonts.pendingFonts([
            GoogleFonts.poppins(),
            GoogleFonts.nunito(),
            GoogleFonts.inter(),
            GoogleFonts.plusJakartaSans(),
            GoogleFonts.lexend(),
          ]);
        } catch (_) {}
      }());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // The database should stay open during lifecycle changes to prevent
        // crashes during background operations (e.g., scanning or downloads).
        // WebSocket keep-alive is still paused to save battery.
        _tutorConnectionProvider.pause();

        break;

      case AppLifecycleState.resumed:
        // Re-open Isar (init is idempotent — returns existing instance if open).
        if (!kIsWeb) IsarService().init();
        // Reconnect WebSocket and flush any messages queued while offline.
        // Fall back to deviceId for guest/preconnected users who have no uid.
        final userId = _authProvider.userModel?.uid ?? _authProvider.deviceId;
        if (userId.isNotEmpty) {
          _tutorConnectionProvider.updateUserId(userId).catchError((e) {
            if (kDebugMode) debugPrint('[TOPSCORE] resume updateUserId error: $e');
          });
        }
        // Check if email verification was completed while app was in background
        _authProvider.checkEmailVerificationOnResume();
        break;

      default:
        break;
    }
  }

  void _syncAnalyticsUser() {
    final user = _authProvider.userModel;
    if (user != null) {
      AnalyticsService.instance.setUserId(user.uid);
      AnalyticsService.instance.setUserRole(user.role);

      // Only record the app-visit XP once per sign-in session.
      // _authProvider fires notifyListeners() multiple times during sign-in
      // (profile fetch start, profile write, listener attach), which would
      // cause concurrent transactions on users/{uid} → failed-precondition.
      if (_lastSyncedUid == user.uid) return;
      _lastSyncedUid = user.uid;

      // Fast load recent 10 chats first
      _aiTutorHistoryProvider.fetchHistory(user.uid, limit: 10);

      // EAGER LOAD: Fetch file history and general resources immediately on launch/sign-in
      _resourcesProvider.loadCloudHistory(user.uid);
      _resourcesProvider.fetchFiles(user: user);

      // Load the rest in the background
      Future.delayed(const Duration(milliseconds: 500), () {
        _aiTutorHistoryProvider.fetchHistory(user.uid);
      });

      _tutorConnectionProvider.updateUserId(user.uid);
    } else {
      _lastSyncedUid = null;
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting initial deep link: $e');
    }

    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (kDebugMode) debugPrint('[TOPSCORE] Processing deep link: $uri');

    // 1. Firebase Auth Actions (Verification, Reset, Sign-In)
    final isFirebaseAuthLink = uri.host.contains('firebaseapp.com') ||
        uri.host.contains('firebase') ||
        uri.path.contains('__/auth/') ||
        uri.queryParameters.containsKey('oobCode');

    if (isFirebaseAuthLink) {
      if (kDebugMode) {
        debugPrint(
            '[TOPSCORE] Firebase auth link detected — processing action');
      }
      _authProvider.handleAuthLink(uri.toString());
      return;
    }

    // 2. topscoreapp.ai HTTPS deep links
    if (uri.host.contains('topscoreapp.ai')) {
      final path = uri.path.isEmpty ? '/home' : uri.path;
      Future.delayed(const Duration(milliseconds: 100), () {
        app_router.router.go(path);
      });
      return;
    }

    // 3. Custom scheme: topscore://app/...
    if (uri.scheme == 'topscore' && uri.host == 'app') {
      final path = uri.path.isEmpty ? '/home' : uri.path;
      Future.delayed(const Duration(milliseconds: 100), () {
        app_router.router.go(path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DownloadProvider>.value(
            value: _downloadProvider),
        ChangeNotifierProvider<SettingsProvider>.value(
            value: _settingsProvider),
        ChangeNotifierProvider<NavigationProvider>.value(
            value: _navigationProvider),
        ChangeNotifierProvider<ConnectivityProvider>.value(
            value: _connectivityProvider),
        ChangeNotifierProvider<ResourcesProvider>.value(
            value: _resourcesProvider),
        ChangeNotifierProvider<AiTutorHistoryProvider>.value(
            value: _aiTutorHistoryProvider),
        ChangeNotifierProvider<TutorConnectionProvider>.value(
            value: _tutorConnectionProvider),
        ChangeNotifierProvider<SearchProvider>(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider<ChatController>(
            create: (context) => ChatController()),
      ],
      child: Selector<
          SettingsProvider,
          ({
            double fontSize,
            double lineHeight,
            ThemeMode themeMode,
            Locale locale
          })>(
        selector: (_, s) => (
          fontSize: s.fontSize,
          lineHeight: s.lineHeight,
          themeMode: s.themeMode,
          locale: s.locale
        ),
        builder: (context, settings, _) {
          return MaterialApp.router(
            title: 'TopScore AI',
            debugShowCheckedModeBanner: false,
            theme:
                AppTheme.lightTheme(settings.fontSize, settings.lineHeight),
            darkTheme:
                AppTheme.darkTheme(settings.fontSize, settings.lineHeight),
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: const [Locale('en'), Locale('sw')],
            routerConfig: app_router.router,
            builder: (context, child) {
              return child!;
            },
          );
        },
      ),
    );
  }
}

// AuthWrapper is intentionally removed — authentication routing is handled
// entirely by the GoRouter redirect in router.dart.
