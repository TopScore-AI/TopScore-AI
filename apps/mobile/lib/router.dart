import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'providers/auth_provider.dart';
// Screens
import 'screens/home_screen.dart';
import 'screens/student/resources_screen.dart';
import 'screens/tools/tools_screen.dart';
import 'screens/profile_screen.dart' as profile_page;
import 'screens/pdf_viewer_screen.dart';
import 'screens/notifications/notification_inbox_screen.dart';
import 'screens/library/offline_library_screen.dart';

// Deferred imports for heavy screens (code splitting)
import 'tutor_client/chat_screen.dart' deferred as chat;
import 'screens/tools/periodic_table_screen.dart' deferred as periodic_table;
import 'screens/tools/science_lab_screen.dart' deferred as science_lab;
import 'screens/tools/flashcard_generator_screen.dart' deferred as flashcards;

// Tool Sub-screens (lightweight - no deferred loading)
import 'screens/tools/calculator_screen.dart';
import 'screens/tools/smart_scanner_screen.dart';
import 'screens/tools/timetable_screen.dart';
import 'screens/search_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/student/career_compass_screen.dart';
import 'screens/splash_screen.dart';

// Widget that holds the BottomNavigationBar
import 'widgets/scaffold_with_navbar.dart';

// Deferred loading widget for consistent UX
class _DeferredLoadingScreen extends StatelessWidget {
  final String message;
  const _DeferredLoadingScreen({this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: kIsWeb ? '/home' : '/splash',
    refreshListenable: authProvider,
    debugLogDiagnostics: false,
    observers: const [], // Temporarily disabled for diagnostics: [AnalyticsService.instance.observer],
    routes: [
      // ── Main app shell with bottom navigation ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Home
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'homeShell'),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeTab(),
              ),
            ],
          ),
          // Tab 2: Library
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'libraryShell'),
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) {
                  final category = state.uri.queryParameters['category'];
                  return ResourcesScreen(initialCategory: category);
                },
                routes: [
                  GoRoute(
                    path: 'offline',
                    builder: (context, state) => const OfflineLibraryScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: AI Tutor
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'tutorShell'),
            routes: [
              GoRoute(
                path: '/ai-tutor',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: FutureBuilder(
                    future: chat.loadLibrary(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return chat.ChatScreen();
                      }
                      return const _DeferredLoadingScreen(
                          message: 'Starting AI Tutor...');
                    },
                  ),
                ),
              ),
            ],
          ),
          // Tab 4: Tools
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'toolsShell'),
            routes: [
              GoRoute(
                path: '/tools',
                builder: (context, state) => const ToolsScreen(),
                routes: [
                  GoRoute(
                    path: 'calculator',
                    builder: (context, state) => const CalculatorScreen(),
                  ),
                  GoRoute(
                    path: 'scanner',
                    builder: (context, state) => const SmartScannerScreen(),
                  ),
                  GoRoute(
                    path: 'flashcards',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: FutureBuilder(
                        future: flashcards.loadLibrary(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return flashcards.FlashcardGeneratorScreen();
                          }
                          return const _DeferredLoadingScreen(
                              message: 'Loading Flashcards...');
                        },
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'timetable',
                    builder: (context, state) => const TimetableScreen(),
                  ),
                  GoRoute(
                    path: 'science_lab',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: FutureBuilder(
                        future: science_lab.loadLibrary(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return science_lab.ScienceLabScreen();
                          }
                          return const _DeferredLoadingScreen(
                              message: 'Loading Science Lab...');
                        },
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'periodic_table',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: FutureBuilder(
                        future: periodic_table.loadLibrary(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return periodic_table.PeriodicTableScreen();
                          }
                          return const _DeferredLoadingScreen(
                              message: 'Loading Periodic Table...');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 5: Profile
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'profileShell'),
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const profile_page.ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Standalone routes ──
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/career-compass',
        builder: (context, state) => const CareerCompassScreen(),
      ),
      GoRoute(
        path: '/pdf-viewer',
        pageBuilder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return CustomTransitionPage(
            key: state.pageKey,
            child: PdfViewerScreen(
              url: extras['url'],
              storagePath: extras['storagePath'],
              assetPath: extras['assetPath'],
              bytes: extras['bytes'],
              file: extras['file'],
              title: extras['title'] ?? 'Document',
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationInboxScreen(),
      ),

      // ── Auth routes ──
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
    ],

    // ── Redirect: single source of truth for auth gating ──
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isOnLogin = location == '/login';
      final isOnVerification = location == '/verification';
      final isOnSplash = location == '/splash';

      final isLoggedIn = authProvider.isAuthenticated;
      final isInitializing = authProvider.isInitializing;
      final isLoading = authProvider.isLoading;

      // Log redirect check
      debugPrint('[ROUTER] Redirect check: location=$location, auth=$isLoggedIn, init=$isInitializing, loading=$isLoading');

      // 1. While INITIALIZING (app startup)
      if (isInitializing) {
        // On Web, we bypass the splash route to avoid "double splash"
        // The HTML splash screen in index.html handles the initial wait.
        if (kIsWeb) return null;

        // If we are already on splash, stay there.
        if (isOnSplash) return null;
        return '/splash';
      }

      // 2. Not logged in -> go to login
      if (!isLoggedIn) {
        // While explicit submission is loading, stay put
        if (isLoading) return null;
        
        if (isOnLogin) return null;
        return '/login';
      }

      final needsVerification = authProvider.requiresEmailVerification;

      // 3. Logged in but email not verified -> go to verification
      if (needsVerification) {
        if (isOnVerification) return null;
        return '/verification';
      }

      // 4. Fully authenticated — redirect away from auth/splash screens
      if (isOnLogin || isOnVerification || isOnSplash) {
        debugPrint('[ROUTER] Fully authenticated and on auth/splash screen -> Redirecting to /home');
        return '/home';
      }

      return null;
    },
  );
}
