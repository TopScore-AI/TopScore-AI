import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

import '../providers/auth_provider.dart';
import '../providers/resources_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/onboarding_tooltip_service.dart';
import '../widgets/interest_update_sheet.dart';
import '../widgets/session_history_carousel.dart';
import '../widgets/streak_widget.dart';
import '../widgets/bounce_wrapper.dart';
import '../utils/image_cache_manager.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resourcesProvider =
          Provider.of<ResourcesProvider>(context, listen: false);
      resourcesProvider.loadRecentlyOpened();

      // Load cloud file history for cross-device sync
      final userId =
          Provider.of<AuthProvider>(context, listen: false).userModel?.uid;
      if (userId != null) {
        resourcesProvider.loadCloudHistory(userId);
      }

      OnboardingTooltipService().init();
      _checkMissingInterests();
      _setupConnectivityListener();
    });
  }

  void _setupConnectivityListener() {
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    bool? wasOnline;
    connectivity.addListener(() {
      if (!mounted) return;
      final isOnline = connectivity.isOnline;
      if (wasOnline != null && wasOnline != isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(isOnline ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(isOnline ? 'Back online' : 'You are offline',
                    style:
                        GoogleFonts.nunito(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            backgroundColor: isOnline ? Colors.green : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      wasOnline = isOnline;
    });
  }

  void _checkMissingInterests() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user != null &&
        user.role == 'student' &&
        (user.interests == null || user.interests!.isEmpty)) {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (context) => InterestUpdateSheet(userId: user.uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const HomeTab();
}

// ─────────────────────────────────────────────────────────────────────────────

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final firstName = user?.displayName.split(' ')[0] ?? 'Student';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header with Progress Ring ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mini progress ring
                    _DailyProgressRing(
                      progress: 0.6,
                      size: 48,
                      child: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                          ? CircleAvatar(
                              radius: 20,
                              backgroundImage: CachedNetworkImageProvider(
                                user.photoURL!,
                                cacheManager: ProfileImageCacheManager(),
                              ),
                            )
                          : Text(
                              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, $firstName 👋',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.gradeLabel ?? 'Form 3',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        backgroundImage:
                            user?.photoURL != null && user!.photoURL!.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    user.photoURL!,
                                    cacheManager: ProfileImageCacheManager(),
                                  )
                                : null,
                        child: user?.photoURL == null || user!.photoURL!.isEmpty
                            ? Text(
                                firstName.isNotEmpty
                                    ? firstName[0].toUpperCase()
                                    : 'S',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Streak Surface ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: StudyStreakWidget(
                  currentStreak: 3,
                  longestStreak: 12,
                  weeklyProgress: 3,
                  weeklyGoal: 5,
                ),
              ),
            ),

            // ── Ask AI ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: BounceWrapper(
                  onTap: () => context.push('/ai-tutor'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ask the AI Tutor anything...',
                            style: GoogleFonts.nunito(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Subject Quick Chips ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUICK START',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: subtextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _SubjectChip(label: 'Mathematics', emoji: '📐', color: const Color(0xFF2563EB)),
                          _SubjectChip(label: 'Science', emoji: '🔬', color: const Color(0xFF10B981)),
                          _SubjectChip(label: 'English', emoji: '📖', color: const Color(0xFFF59E0B)),
                          _SubjectChip(label: 'Kiswahili', emoji: '🇰🇪', color: const Color(0xFFEF4444)),
                          _SubjectChip(label: 'History', emoji: '🏛️', color: const Color(0xFF8B5CF6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Recent Sessions ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RECENT',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: subtextColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/activity-history'),
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const SessionHistoryCarousel(),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY PROGRESS RING
// ─────────────────────────────────────────────────────────────────────────────

class _DailyProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Widget? child;

  const _DailyProgressRing({
    required this.progress,
    this.size = 48,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          progress: progress.clamp(0.0, 1.0),
          trackColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFF2563EB).withValues(alpha: 0.1),
          progressColor: const Color(0xFF2563EB),
          strokeWidth: 3.5,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = progressColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;

  const _SubjectChip({
    required this.label,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: BounceWrapper(
        onTap: () => context.push('/ai-tutor', extra: {
          'initial_message': 'Help me study $label',
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? color.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.2 : 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? color.withValues(alpha: 0.9) : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
