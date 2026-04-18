import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/analytics_service.dart';
import 'services/update_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'providers/auth_provider.dart';

// Screens
import 'screens/library/your_library_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/profile_screen.dart' as profile_page;
import 'screens/pdf_viewer_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'widgets/splash_screen.dart';
import 'screens/dashboard_screen.dart';

// Tool Sub-screens (lightweight - no deferred loading)
import 'screens/tools/smart_scanner_screen.dart';
import 'screens/tools/pdf_summarizer_screen.dart';
import 'screens/tools/flashcard_generator_screen.dart';
import 'screens/tools/quiz_generator_screen.dart';
import 'screens/share_preview_screen.dart';

import 'screens/search_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/guest_welcome_screen.dart';
import 'screens/student/career_compass_screen.dart';
import 'tutor_client/chat_screen.dart' deferred as chat;
import 'screens/activity_history_screen.dart';

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
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeOut).animate(animation),
        child: child,
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
        // Tab 0: Home
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
          ],
        ),
        // Tab 1: AI Tutor (Center)
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'tutorShell'),
          routes: [
            GoRoute(
              path: '/ai-tutor',
              pageBuilder: (context, state) {
                final subject = state.uri.queryParameters['subject'];
                final extra = state.extra as Map<String, dynamic>?;
                final startVoice = extra?['start_voice'] == true;

                return NoTransitionPage(
                  child: FutureBuilder(
                    future: chat.loadLibrary(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return chat.ChatScreen(
                          chatThread: extra,
                          subject: subject,
                          startVoice: startVoice,
                          initialMessage: extra?['initial_message'] as String?,
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
        // Tab 2: Library (Explorer)
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'libraryShell'),
          routes: [
            GoRoute(
              path: '/library',
              pageBuilder: (context, state) => _buildCustomTransitionPage(
                key: state.pageKey,
                child: const LibraryScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    // Tool Routes (Standalone)
    GoRoute(
      path: '/summarizer',
      builder: (context, state) => const PdfSummarizerScreen(),
    ),
    GoRoute(
      path: '/flashcards',
      builder: (context, state) => const FlashcardGeneratorScreen(),
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const QuizGeneratorScreen(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const SmartScannerScreen(),
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
    // My Library (Personal)
    GoRoute(
      path: '/my-stuff',
      builder: (context, state) => const YourLibraryScreen(),
    ),
    // PDF Viewer
    GoRoute(
      path: '/pdf-viewer',
      pageBuilder: (context, state) {
        final extras = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 150),
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
    // Share Preview (Secure)
    GoRoute(
      path: '/share/:fileId',
      builder: (context, state) {
        final fileId = state.pathParameters['fileId']!;
        return SharePreviewScreen(fileId: fileId);
      },
    ),
  ],
);
