import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
// import 'package:seo/seo.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
import 'providers/gamification_provider.dart';
import 'services/xp_service.dart';
import 'providers/tutor_connection_provider.dart';
import 'providers/search_provider.dart';
import 'providers/notification_provider.dart';
import 'tutor_client/chat_controller.dart';
import 'router.dart' as app_router;

import 'screens/home_screen.dart';
import 'screens/subscription/subscription_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/auth_screen.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'services/update_service.dart';
import 'services/analytics_service.dart';
import 'config/app_theme.dart';
import 'widgets/app_error_widget.dart';
import 'widgets/update_banner.dart';
import 'services/isar_service.dart';
import 'repositories/study_repository.dart';
import 'repositories/study_repository_factory.dart';

late StudyRepository studyDb;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  IsarService().init();

  // Enable clean URLs for web (removes # from URLs)
  usePathUrlStrategy();

  // Initialize Firebase with error handling
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kDebugMode) {
        await AnalyticsService.instance.enableDebugMode();
      }
      
      // Initialize Firebase Crashlytics
      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('[TOPSCORE] Firebase init error: $e\n$stackTrace');
    }
  }

  // Firestore offline persistence
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Firestore settings error: $e');
  }

  // Init Notifications (skip on web to avoid blocking)
  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await setupInteractedMessage();
    } catch (e) {
      if (kDebugMode) debugPrint('Notification init error: $e');
    }
  }

  // Init Offline Storage
  try {
    await OfflineService().init();
  } catch (e) {
    if (kDebugMode) debugPrint('Offline init error: $e');
  }

  studyDb = await createStudyRepository();

  // Global error handler for uncaught Flutter widget errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[TOPSCORE] FlutterError: ${details.exceptionAsString()}');
    }
  };
  ErrorWidget.builder =
      (FlutterErrorDetails details) => AppErrorWidget(details: details);

  runApp(const MyApp());
}

Future<void> setupInteractedMessage() async {
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleMessage(initialMessage);
  }
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
}

void _handleMessage(RemoteMessage message) {
  if (message.data['screen'] == 'subscription_page') {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
  }
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

    UpdateService().startAutoCheck();

    // Initialize deep link handling for app shortcuts
    if (!kIsWeb) {
      _appLinks = AppLinks();
      _initDeepLinks();
    }

    // Defer initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider.init();
      _downloadProvider.init();
      _navigationProvider.init();
      _resourcesProvider.loadRecentlyOpened();

      // Set analytics user properties once auth resolves
      _authProvider.addListener(_syncAnalyticsUser);
    });
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
        // Pause the WebSocket keep-alive so it doesn't burn battery in background.
        // The connection will be re-established when the app resumes.
        _tutorConnectionProvider.pause();
        // Close Isar cleanly so Android doesn't corrupt the DB file on force-kill.
        if (!kIsWeb) {
          IsarService().db.then((isar) {
            if (isar?.isOpen ?? false) isar!.close();
          });
        }
        break;

      case AppLifecycleState.resumed:
        // Re-open Isar (init is idempotent — returns existing instance if open).
        if (!kIsWeb) IsarService().init();
        // Reconnect WebSocket and flush any messages queued while offline.
        final userId = _authProvider.userModel?.uid;
        if (userId != null) {
          _tutorConnectionProvider.updateUserId(userId);
        }
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

      // Start real-time streak + XP listeners (idempotent — safe to call every notify)
      GamificationProvider.instance.startListening(user.uid);

      // Only record the app-visit XP once per sign-in session.
      // _authProvider fires notifyListeners() multiple times during sign-in
      // (profile fetch start, profile write, listener attach), which would
      // cause concurrent transactions on users/{uid} → failed-precondition.
      if (_lastSyncedUid == user.uid) return;
      _lastSyncedUid = user.uid;

      // Defer until the current frame settles so _ensureUserProfile's Firestore
      // write has committed before we open a competing transaction on the same doc.
      Future.microtask(() => GamificationProvider.instance
          .record(user.uid, ActivityType.appVisit));

      // Fast load recent 10 chats first
      _aiTutorHistoryProvider.fetchHistory(user.uid, limit: 10);

      // Load the rest in the background
      Future.delayed(const Duration(milliseconds: 500), () {
        _aiTutorHistoryProvider.fetchHistory(user.uid);
      });

      _tutorConnectionProvider.updateUserId(user.uid);
    } else {
      _lastSyncedUid = null;
      GamificationProvider.instance.stopListening();
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
        ChangeNotifierProvider<NotificationProvider>(
            create: (_) => NotificationProvider()),
        ChangeNotifierProvider<GamificationProvider>.value(
            value: GamificationProvider.instance),
        ChangeNotifierProvider<ChatController>(
            create: (context) => ChatController()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return UpdateBanner(
            child: MaterialApp.router(
              title: 'TopScore AI',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(settings.fontSize, settings.lineHeight),
              darkTheme: AppTheme.darkTheme(settings.fontSize, settings.lineHeight),
              themeMode: settings.themeMode,
              locale: settings.locale,
              supportedLocales: const [Locale('en'), Locale('sw')],
              routerConfig: app_router.router,
            ),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.requiresEmailVerification) {
      return const EmailVerificationScreen();
    }

    if (authProvider.userModel == null) {
      return const AuthScreen();
    }

    // Always route to student home screen - teacher and parent screens disabled
    return const HomeScreen();
  }
}
