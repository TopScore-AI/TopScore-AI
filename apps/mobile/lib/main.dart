import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:seo/seo.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:app_links/app_links.dart';
import 'package:web/web.dart' as web;

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
import 'router.dart';

import 'firebase_options.dart';
import 'services/offline_service.dart';
import 'services/analytics_service.dart';
import 'config/app_theme.dart';
import 'widgets/app_error_widget.dart';
import 'widgets/global_background.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  runZonedGuarded(() async {
    if (kDebugMode) {
      debugPrint('[TOPSCORE] 1. Starting main()');
    }
    WidgetsFlutterBinding.ensureInitialized();

    // Enable clean URLs for web (removes # from URLs)
    usePathUrlStrategy();
    if (kDebugMode) {
      debugPrint(
        '[TOPSCORE] 2. WidgetsFlutterBinding initialized & URL strategy set',
      );
    }

    // Load environment variables with error handling
    try {
      if (kDebugMode) {
        debugPrint('[TOPSCORE] 3. Loading dotenv...');
      }
      if (!kIsWeb) {
        await dotenv.load(fileName: ".env");
      }
      if (kDebugMode) {
        debugPrint('[TOPSCORE] 4. Dotenv loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TOPSCORE] 4. Dotenv load error (continuing anyway): $e');
      }
    }

    // Initialize Firebase with error handling
    try {
      if (kDebugMode) {
        debugPrint('[TOPSCORE] 5. Checking Firebase apps...');
      }
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] 6. Initializing Firebase...');
        }
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        if (kDebugMode) {
          debugPrint('[TOPSCORE] 7. Firebase initialized successfully');
        }

        // Initialize Analytics
        try {
          AnalyticsService.instance.enableDebugMode();
          if (kDebugMode) {
            debugPrint('[TOPSCORE] 7b. Analytics initialized');
          }
        } catch (analyticsError) {
          debugPrint('[TOPSCORE] Analytics init error (non-fatal): $analyticsError');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] 6-7. Firebase already initialized');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[TOPSCORE] 7. Firebase init error: $e');
      debugPrint('[TOPSCORE] 7. Stack trace: $stackTrace');
      // Rethrow to be caught by the runZonedGuarded boundary
      rethrow;
    }

    // Enable offline persistence (only on non-web)
    if (!kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
      } catch (e) {
        debugPrint("Firestore persistence error: $e");
      }
    }
    if (kDebugMode) {
      debugPrint('[TOPSCORE] 8. Firestore settings done (skipped on web)');
    }

    // Init Notifications (skip on web to avoid blocking)
    if (!kIsWeb) {
      try {
// Notification initialization removed or needs update for unified router
      } catch (e) {
        debugPrint("Notification Init Error: $e");
      }
    }
    if (kDebugMode) {
      debugPrint('[TOPSCORE] 9. Notifications done (skipped on web)');
    }

    // Init Offline Storage (Initializes SharedPreferences on web, Hive on mobile)
    try {
      await OfflineService().init();
    } catch (e) {
      debugPrint("Offline Init Error: $e");
    }
    if (kDebugMode) {
      debugPrint('[TOPSCORE] 10. Offline storage done');
      debugPrint('[TOPSCORE] 11. Calling runApp()...');
    }

    // Global error handler for uncaught Flutter widget errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[TOPSCORE] FlutterError: ${details.exceptionAsString()}');
    };
    ErrorWidget.builder =
        (FlutterErrorDetails details) => AppErrorWidget(details: details);

    runApp(const MyApp());
    debugPrint('[TOPSCORE] 12. runApp() called');
  }, (error, stack) {
    debugPrint('[TOPSCORE] FATAL STARTUP ERROR: $error');
    debugPrint('[TOPSCORE] Stack trace: $stack');
    
    // Fallback: If everything fails, show a safety UI
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'The application failed to start correctly. This usually happens due to a configuration mismatch or network issues.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    error.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => web.window.location.reload(),
                  child: const Text('Reload Application'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthProvider _authProvider;
  late final DownloadProvider _downloadProvider;
  late final SettingsProvider _settingsProvider;
  late final NavigationProvider _navigationProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final ResourcesProvider _resourcesProvider;
  late final AiTutorHistoryProvider _aiTutorHistoryProvider;
  late final TutorConnectionProvider _tutorConnectionProvider;
  late final AppLinks _appLinks;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _downloadProvider = DownloadProvider();
    _settingsProvider = SettingsProvider();
    _navigationProvider = NavigationProvider();
    _connectivityProvider = ConnectivityProvider();
    _resourcesProvider = ResourcesProvider();
    _aiTutorHistoryProvider = AiTutorHistoryProvider();
    _tutorConnectionProvider = TutorConnectionProvider();
    _tutorConnectionProvider.attachHistoryProvider(_aiTutorHistoryProvider);
    _router = createRouter(_authProvider);

    // Start auth initialization immediately so GoRouter redirect
    // can properly gate navigation from the very first frame.
    _authProvider.init().then((_) {
      if (kIsWeb) {
        web.window.dispatchEvent(web.CustomEvent('app-ready'));
      }
    });
    _authProvider.addListener(_syncAnalyticsUser);

    // Initialize deep link handling for app shortcuts
    if (!kIsWeb) {
      _appLinks = AppLinks();
      _initDeepLinks(_router);
    }

    // Defer non-auth initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _downloadProvider.init();
      _navigationProvider.init();
      _resourcesProvider.loadRecentlyOpened();
    });
  }

  void _syncAnalyticsUser() {
    final user = _authProvider.userModel;
    if (user != null) {
      AnalyticsService.instance.setUserId(user.uid);
      AnalyticsService.instance.setUserRole(user.role);

      // Fast load recent 10 chats first
      _aiTutorHistoryProvider.fetchHistory(user.uid, limit: 10);

      // Load the rest in the background
      Future.delayed(const Duration(milliseconds: 500), () {
        _aiTutorHistoryProvider.fetchHistory(user.uid);
      });

      _tutorConnectionProvider.updateUserId(user.uid);

      // Sync FCM token for push notifications
      _syncFCMToken(user.uid);
    }
  }

  Future<void> _syncFCMToken(String uid) async {
    try {
      if (kIsWeb) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'lastTokenSync': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] Token synced for user: $uid');
      }
    } catch (e) {
      debugPrint('[FCM] Error syncing token: $e');
    }
  }

  Future<void> _initDeepLinks(GoRouter router) async {
    // Handle initial link (app opened from shortcut while closed)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri, router);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // Handle links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri, router);
    });
  }

  void _handleDeepLink(Uri uri, GoRouter router) {
    // Convert topscore://app/path to /path for go_router
    if (uri.scheme == 'topscore' && uri.host == 'app') {
      final path = uri.path.isEmpty ? '/home' : uri.path;
      debugPrint('Deep link received: $path');
      Future.delayed(const Duration(milliseconds: 100), () {
        router.go(path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DownloadProvider>.value(
          value: _downloadProvider,
        ),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: _settingsProvider,
        ),
        ChangeNotifierProvider<NavigationProvider>.value(
          value: _navigationProvider,
        ),
        ChangeNotifierProvider<ConnectivityProvider>.value(
          value: _connectivityProvider,
        ),
        ChangeNotifierProvider<ResourcesProvider>.value(
          value: _resourcesProvider,
        ),
        ChangeNotifierProvider<AiTutorHistoryProvider>.value(
          value: _aiTutorHistoryProvider,
        ),
        ChangeNotifierProvider<TutorConnectionProvider>.value(
          value: _tutorConnectionProvider,
        ),
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider(),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return SeoController(
            enabled: true,
            tree: WidgetTree(context: context),
            child: MaterialApp.router(
            title: 'TopScore AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('sw'),
            ],
            routerConfig: _router,
            builder: (context, child) {
              return GlobalBackground(
                child: Stack(
                  children: [
                    child!,
                    // Visual Heartbeat Indicator (Diagnostic)
                    if (!kIsWeb || kDebugMode)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.pinkAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ));
        },
      ),
    );
  }
}





