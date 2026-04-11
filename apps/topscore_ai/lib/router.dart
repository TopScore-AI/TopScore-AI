import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/analytics_service.dart';
import 'services/update_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'providers/auth_provider.dart';
import 'package:provider/provider.dart';

// Screens
import 'screens/library/my_stuff_screen.dart';
import 'screens/student/resources_screen.dart';
import 'screens/tools/tools_screen.dart';
import 'screens/profile_screen.dart' as profile_page;
import 'screens/pdf_viewer_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'widgets/splash_screen.dart';
import 'screens/dashboard_screen.dart';

// Deferred imports for heavy screens (code splitting)
import 'tutor_client/chat_screen.dart' deferred as chat;
import 'screens/tools/periodic_table_screen.dart' deferred as periodic_table;
import 'screens/tools/science_lab_screen.dart' deferred as science_lab;
import 'screens/tools/flashcard_generator_screen.dart' deferred as flashcards;
import 'screens/tools/quiz_generator_screen.dart' deferred as quiz;

// Tool Sub-screens (lightweight - no deferred loading)
import 'screens/tools/calculator_screen.dart';
import 'screens/tools/smart_scanner_screen.dart';
import 'screens/tools/timetable_screen.dart';
import 'screens/tools/pdf_summarizer_screen.dart';

import 'screens/search_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/guest_welcome_screen.dart';
import 'screens/student/career_compass_screen.dart';
import 'screens/activity_history_screen.dart';
import 'composition_studio/composition_studio_screen.dart';

// Widget that holds the BottomNavigationBar
import 'widgets/scaffold_with_navbar.dart';
import 'widgets/app_error_widget.dart';

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
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();


CustomTransitionPage<void> _buildCustomTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCirc),
          ),
          child: child,
        ),
      );
    },
  );
}

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  refreshListenable: AuthProvider.instance,
  debugLogDiagnostics: false,
  observers: [AnalyticsService.instance.observer],
  errorBuilder: (context, state) => AppErrorWidget(
    details: state.error,
    onRetry: () => context.go('/home'),
  ),
  redirect: (context, state) {
    // Check for available updates on navigation (Web only)
    UpdateService().checkAndAutoApplyOnNavigation(state.matchedLocation);

    final authProvider = AuthProvider.instance;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final isLoggedIn = firebaseUser != null;

    final isLoggingIn = state.matchedLocation == '/login';
    final isOnboarding = state.matchedLocation == '/onboarding';
    final isVerifyingEmail = state.matchedLocation == '/verify-email';
    final isGuestWelcome = state.matchedLocation == '/guest-welcome';

    // 1. Loading Guard: Only block if we are totally unauthenticated AND initializing.
    // If we are already logged in (firebaseUser != null), we should allow transitions 
    // to the home screen even if the profile model is still fetching.
    if (authProvider.isLoading && !isLoggedIn) return null;

    // 2. Registered User Flow
    if (isLoggedIn) {
      // Already logged in, but needs email verification?
      if (authProvider.requiresEmailVerification) {
        return isVerifyingEmail ? null : '/verify-email';
      }

      // If they are on an auth screen but logged in, push to home.
      if (isLoggingIn || isOnboarding || isVerifyingEmail || isGuestWelcome) {
        return '/home';
      }

      // Otherwise, let them stay where they are.
      return null;
    }

    // 3. Guest Mode — let them through to the app freely.
    if (authProvider.isGuestMode) return null;

    // 4. Not logged in? Send to the welcome screen to reduce friction.
    return isLoggingIn ? null : '/guest-welcome';
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final isRegister = state.uri.queryParameters['isRegister'] == 'true';
        return AuthScreen(isRegister: isRegister);
      },
    ),
    GoRoute(
      path: '/guest-welcome',
      builder: (context, state) => const GuestWelcomeScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const EmailVerificationScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    // This "Shell" handles the Bottom Navigation Bar logic
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
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                key: state.pageKey,
                child: const DashboardScreen(),
              ),
            ),
            GoRoute(
              path: '/my-stuff',
              builder: (context, state) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                return MyStuffScreen(uid: auth.userModel?.uid ?? '');
              },
            ),
          ],
        ),
        // Tab 2: Library
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'libraryShell'),
          routes: [
            GoRoute(
              path: '/library',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                key: state.pageKey,
                child: const ResourcesScreen(),
              ),
            ),
          ],
        ),
        // Tab 3: AI Tutor
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'tutorShell'),
          routes: [
            GoRoute(
              path: '/ai-tutor',
              pageBuilder: (context, state) {
                // Check for subject query parameter
                final subject = state.uri.queryParameters['subject'];
                final extra = state.extra as Map<String, dynamic>? ?? {};
                final startVoice = extra['start_voice'] == true;

                return NoTransitionPage(
                  child: FutureBuilder(
                    future: chat.loadLibrary(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return chat.ChatScreen(
                          chatThread: extra,
                          subject: subject,
                          startVoice: startVoice,
                        );
                      }
                      return const _DeferredLoadingScreen(
                          message: 'Starting AI Tutor...');
                    },
                  ),
                );
              },
            ),
          ],
        ),
        // Tab 4: Tools
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'toolsShell'),
          routes: [
            GoRoute(
              path: '/tools',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                key: state.pageKey,
                child: const ToolsScreen(),
              ),
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
                  path: 'quiz',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: FutureBuilder(
                      future: quiz.loadLibrary(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return quiz.QuizGeneratorScreen();
                        }
                        return const _DeferredLoadingScreen(
                            message: 'Loading Quiz Generator...');
                      },
                    ),
                  ),
                ),
                GoRoute(
                  path: 'timetable',
                  builder: (context, state) => const TimetableScreen(),
                ),
                GoRoute(
                  path: 'science-lab',
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
                  path: 'periodic-table',
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
                GoRoute(
                  path: 'summarizer',
                  builder: (context, state) => const PdfSummarizerScreen(),
                ),
                GoRoute(
                  path: 'composition-studio',
                  builder: (context, state) => const CompositionStudioScreen(),
                ),

              ],
            ),
          ],
        ),
      ],
    ),
    // Search
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    // Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Profile
    GoRoute(
      path: '/profile',
      builder: (context, state) => const profile_page.ProfileScreen(),
    ),
    // Career Compass
    GoRoute(
      path: '/career-compass',
      builder: (context, state) => const CareerCompassScreen(),
    ),
    // Activity History
    GoRoute(
      path: '/activity-history',
      builder: (context, state) => const ActivityHistoryScreen(),
    ),
    // PDF Viewer
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
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
    // Direct Chat route (allows passing subject in path)
    GoRoute(
      path: '/chat/:subject',
      builder: (context, state) {
        final subject = state.pathParameters['subject'];
        return FutureBuilder(
          future: chat.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return chat.ChatScreen(subject: subject);
            }
            return const _DeferredLoadingScreen(
                message: 'Starting AI Tutor...');
          },
        );
      },
    ),
  ],
);
