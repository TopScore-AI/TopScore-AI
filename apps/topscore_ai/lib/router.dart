import '../../constants/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'services/analytics_service.dart';

import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'providers/auth_provider.dart';

// Core Screens (Always loaded)
import 'screens/auth/auth_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'widgets/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/scaffold_with_navbar.dart';
import 'widgets/app_error_widget.dart';

// Deferred/Lazy Loaded Screens
import 'screens/library/your_library_screen.dart' deferred as your_library;
import 'screens/library/library_screen.dart' deferred as lib_screen;
import 'screens/profile_screen.dart' deferred as profile_page;
import 'screens/pdf_viewer_screen.dart' deferred as pdf_viewer;
import 'screens/tools/smart_scanner_screen.dart' deferred as scanner;
import 'screens/tools/pdf_summarizer_screen.dart' deferred as summarizer;
import 'screens/tools/flashcard_generator_screen.dart' deferred as flashcards;
import 'screens/tools/quiz_generator_screen.dart' deferred as quiz;
import 'screens/share_preview_screen.dart' deferred as share_preview;
import 'screens/search_screen.dart' deferred as search;
import 'screens/auth/onboarding_screen.dart' deferred as onboarding;
import 'screens/student/career_compass_screen.dart' deferred as career;
import 'screens/subscription/subscription_screen.dart' deferred as subscription;
import 'screens/notification_center_screen.dart' deferred as notifications;
import 'tutor_client/chat_screen.dart' deferred as chat;
import 'tutor_client/screens/lesson_mode_screen.dart' deferred as lesson_mode;
import 'screens/language_tree_screen.dart' deferred as language_tree;
import 'screens/activity_history_screen.dart' deferred as activity;
import 'screens/multiplayer/multiplayer_lobby_screen.dart'
    deferred as multiplayer_lobby;
import 'screens/legal/privacy_policy_screen.dart' deferred as privacy;
import 'screens/legal/terms_of_use_screen.dart' deferred as terms;
import 'screens/legal/account_deletion_screen.dart'
    deferred as account_deletion;
import 'screens/support/support_screen.dart' deferred as support;
import 'screens/notifications/notification_preferences_screen.dart'
    deferred as notif_prefs;
import 'screens/student/achievements_screen.dart' deferred as achievements;

// Deferred loading widget for consistent UX
class PremiumSkeletonLoader extends StatelessWidget {
  final String message;
  const PremiumSkeletonLoader({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          // Animated Background Gradient
          Positioned.fill(
            child: _AnimatedBackground(isDark: isDark),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Premium Pulse Loader
                _PulseLogo(isDark: isDark),
                const SizedBox(height: 32),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBackground extends StatefulWidget {
  final bool isDark;
  const _AnimatedBackground({required this.isDark});

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                0.5 * (1 + 0.2 * (0.5 - _controller.value)),
                -0.5,
              ),
              radius: 1.5,
              colors: widget.isDark
                  ? [AppColors.surfaceElevatedDark, AppColors.backgroundDark]
                  : [AppColors.surfaceVariant, AppColors.background],
            ),
          ),
        );
      },
    );
  }
}

class _PulseLogo extends StatefulWidget {
  final bool isDark;
  const _PulseLogo({required this.isDark});

  @override
  State<_PulseLogo> createState() => _PulseLogoState();
}

class _PulseLogoState extends State<_PulseLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Image.asset('assets/images/logo.png'),
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
    transitionDuration: 400.ms,
    reverseTransitionDuration: 300.ms,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOutCubic).animate(animation),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
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

    final authProvider = AuthProvider.instance;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final isLoggedIn = firebaseUser != null;

    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/auth';
    final isOnboarding = state.matchedLocation == '/onboarding';
    final isVerifyingEmail = state.matchedLocation == '/verify-email';
    final isForgotPassword = state.matchedLocation == '/forgot-password';
    final isPublicLegal = state.matchedLocation == '/privacy-policy' ||
        state.matchedLocation == '/terms-of-use' ||
        state.matchedLocation == '/support';

    // Whitelist Firebase Auth reserved paths on web/mobile to prevent
    // GoRouter from redirecting to /login during the auth handshake.
    final isAuthHandler = state.matchedLocation.contains('__/auth/');

    // 1. Loading Guard: Only block if we are totally unauthenticated AND initializing.
    // If we are already logged in (firebaseUser != null), we should allow transitions
    // to the home screen even if the profile model is still fetching.
    if (authProvider.isLoading && !isLoggedIn) return null;

    if (kDebugMode) {
      debugPrint('[TOPSCORE] Router Redirect:');
      debugPrint('  Location: ${state.matchedLocation}');
      debugPrint('  LoggedIn: $isLoggedIn');
      debugPrint('  Loading: ${authProvider.isLoading}');
      debugPrint('  LoggingIn: $isLoggingIn');
      debugPrint('  AuthHandler: $isAuthHandler');
    }

    // 2. Registered User Flow
    if (isLoggedIn) {
      // Already logged in, but needs email verification?
      if (authProvider.requiresEmailVerification) {
        if (kDebugMode) debugPrint('[TOPSCORE] Redirecting to /verify-email');
        return isVerifyingEmail ? null : '/verify-email';
      }

      // Already logged in? Don't allow login/onboarding screens
      // Also don't allow auth handlers if we're already logged in (they'll be handled or ignored)
      if (isLoggingIn || isOnboarding || isVerifyingEmail || isAuthHandler) {
        if (kDebugMode) {
          debugPrint('[TOPSCORE] Redirecting to /home (isLoggedIn: true)');
        }
        return '/home';
      }
      return null;
    }

    // 3. Not logged in?
    if (!isLoggedIn) {
      if (authProvider.isLoading && !isLoggedIn) {
        if (kDebugMode) {
          debugPrint(
              '[TOPSCORE] Staying on ${state.matchedLocation} (isLoading: true)');
        }
        return null;
      }
      if (isLoggingIn || isOnboarding || isVerifyingEmail || isForgotPassword || isPublicLegal || isAuthHandler) {
        if (kDebugMode) {
          debugPrint(
              '[TOPSCORE] Staying on ${state.matchedLocation} (Whitelisted)');
        }
        return null;
      }
      if (kDebugMode) {
        debugPrint('[TOPSCORE] Redirecting to /login (isLoggedIn: false)');
      }
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/home',
    ),
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
      path: '/auth',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const EmailVerificationScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    // Firebase Auth Reserved Paths (Internal)
    GoRoute(
      path: '/__/auth/action',
      builder: (context, state) =>
          const PremiumSkeletonLoader(message: 'Verifying link...'),
    ),
    GoRoute(
      path: '/__/auth/handler',
      builder: (context, state) =>
          const PremiumSkeletonLoader(message: 'Authenticating...'),
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
                          initialInputText:
                              extra?['initial_input_text'] as String?,
                          initialImage: extra?['initial_image'] as XFile?,
                        );
                      }
                      return const PremiumSkeletonLoader(
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
              pageBuilder: (context, state) => NoTransitionPage(
                child: FutureBuilder(
                  future: lib_screen.loadLibrary(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return lib_screen.LibraryScreen();
                    }
                    return const PremiumSkeletonLoader(
                        message: 'Loading Library...');
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    // Tool Routes (Standalone with /tools prefix)
    GoRoute(
      path: '/tools/summarizer',
      builder: (context, state) => FutureBuilder(
        future: summarizer.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return summarizer.PdfSummarizerScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Summarizer...');
        },
      ),
    ),
    GoRoute(
      path: '/summarizer',
      builder: (context, state) => FutureBuilder(
        future: summarizer.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return summarizer.PdfSummarizerScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Summarizer...');
        },
      ),
    ),
    GoRoute(
      path: '/tools/flashcards',
      builder: (context, state) => FutureBuilder(
        future: flashcards.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return flashcards.FlashcardGeneratorScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Flashcards...');
        },
      ),
    ),
    GoRoute(
      path: '/flashcards',
      builder: (context, state) => FutureBuilder(
        future: flashcards.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return flashcards.FlashcardGeneratorScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Flashcards...');
        },
      ),
    ),
    GoRoute(
      path: '/tools/quiz',
      builder: (context, state) => FutureBuilder(
        future: quiz.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return quiz.QuizGeneratorScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Quiz...');
        },
      ),
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => FutureBuilder(
        future: quiz.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return quiz.QuizGeneratorScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Quiz...');
        },
      ),
    ),
    GoRoute(
      path: '/tools/scanner',
      builder: (context, state) => FutureBuilder(
        future: scanner.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return scanner.SmartScannerScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Scanner...');
        },
      ),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => FutureBuilder(
        future: scanner.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return scanner.SmartScannerScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Scanner...');
        },
      ),
    ),
    // Search
    GoRoute(
      path: '/search',
      builder: (context, state) => FutureBuilder(
        future: search.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return search.SearchScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Search...');
        },
      ),
    ),
    // Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => FutureBuilder(
        future: onboarding.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return onboarding.OnboardingScreen();
          }
          return const PremiumSkeletonLoader(message: 'Setting up...');
        },
      ),
    ),
    // Profile
    GoRoute(
      path: '/profile',
      builder: (context, state) => FutureBuilder(
        future: profile_page.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return profile_page.ProfileScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Profile...');
        },
      ),
    ),
    // Career Compass
    GoRoute(
      path: '/career-compass',
      builder: (context, state) => FutureBuilder(
        future: career.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return career.CareerCompassScreen();
          }
          return const PremiumSkeletonLoader(
              message: 'Loading Career Compass...');
        },
      ),
    ),
    // Subscription (deep-link target for upsell/renewal nudges)
    GoRoute(
      path: '/subscription',
      builder: (context, state) => FutureBuilder(
        future: subscription.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return subscription.SubscriptionScreen();
          }
          return const PremiumSkeletonLoader(
              message: 'Loading Subscription...');
        },
      ),
    ),
    // Activity History
    GoRoute(
      path: '/activity-history',
      builder: (context, state) => FutureBuilder(
        future: activity.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return activity.ActivityHistoryScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading History...');
        },
      ),
    ),
    // My Library (Personal)
    GoRoute(
      path: '/my-stuff',
      builder: (context, state) => FutureBuilder(
        future: your_library.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return your_library.YourLibraryScreen();
          }
          return const PremiumSkeletonLoader(
              message: 'Loading Your Library...');
        },
      ),
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
          child: FutureBuilder(
            future: pdf_viewer.loadLibrary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return pdf_viewer.PdfViewerScreen(
                  url: extras['url'],
                  storagePath: extras['storagePath'],
                  assetPath: extras['assetPath'],
                  bytes: extras['bytes'],
                  file: extras['file'],
                  title: extras['title'] ?? 'Document',
                );
              }
              return const PremiumSkeletonLoader(message: 'Loading PDF...');
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
    GoRoute(
      path: '/language-tree',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final language = extra['language'] as String? ?? 'French';
        return FutureBuilder(
          future: language_tree.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return language_tree.LanguageTreeScreen(language: language);
            }
            return const PremiumSkeletonLoader(message: 'Loading Language Tree...');
          },
        );
      },
    ),
    GoRoute(
      path: '/lesson-mode',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final language = extra['language'] as String? ?? 'French';
        final topic = extra['topic'] as String? ?? 'Greetings';
        return FutureBuilder(
          future: lesson_mode.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return lesson_mode.LessonModeScreen(
                language: language,
                topic: topic,
              );
            }
            return const PremiumSkeletonLoader(message: 'Generating Lesson Quest...');
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
            return const PremiumSkeletonLoader(message: 'Starting AI Tutor...');
          },
        );
      },
    ),
    // Share Preview (Secure)
    GoRoute(
      path: '/share/:fileId',
      builder: (context, state) {
        final fileId = state.pathParameters['fileId']!;
        return FutureBuilder(
          future: share_preview.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return share_preview.SharePreviewScreen(fileId: fileId);
            }
            return const PremiumSkeletonLoader(message: 'Loading Share...');
          },
        );
      },
    ),
    // Notification Center
    GoRoute(
      path: '/notifications',
      builder: (context, state) => FutureBuilder(
        future: notifications.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return notifications.NotificationCenterScreen();
          }
          return const PremiumSkeletonLoader(
              message: 'Loading Notifications...');
        },
      ),
    ),
    GoRoute(
      path: '/multiplayer-lobby/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        final isHost = state.uri.queryParameters['isHost'] == 'true';
        return FutureBuilder(
          future: multiplayer_lobby.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return multiplayer_lobby.MultiplayerLobbyScreen(
                  roomCode: code, isHost: isHost);
            }
            return const PremiumSkeletonLoader(message: 'Loading Lobby...');
          },
        );
      },
    ),
    // Legal & Support
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => FutureBuilder(
        future: privacy.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return privacy.PrivacyPolicyScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading...');
        },
      ),
    ),
    GoRoute(
      path: '/terms-of-use',
      builder: (context, state) => FutureBuilder(
        future: terms.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return terms.TermsOfUseScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading...');
        },
      ),
    ),
    GoRoute(
      path: '/delete-account',
      builder: (context, state) => FutureBuilder(
        future: account_deletion.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return account_deletion.AccountDeletionScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading...');
        },
      ),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => FutureBuilder(
        future: support.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return support.SupportScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Support...');
        },
      ),
    ),
    GoRoute(
      path: '/achievements',
      builder: (context, state) => FutureBuilder(
        future: achievements.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return achievements.AchievementsScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Achievements...');
        },
      ),
    ),
    GoRoute(
      path: '/notification-preferences',
      builder: (context, state) => FutureBuilder(
        future: notif_prefs.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return notif_prefs.NotificationPreferencesScreen();
          }
          return const PremiumSkeletonLoader(message: 'Loading Settings...');
        },
      ),
    ),
  ],
);
