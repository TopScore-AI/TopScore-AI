import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../services/permission_service.dart';
import '../widgets/permission_dialog.dart';
import '../../widgets/session_history_carousel.dart';
import '../../widgets/bounce_wrapper.dart';
import '../../constants/colors.dart';
import '../../providers/notification_provider.dart';
import '../tutor_client/chat_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });
  }

  Future<void> _checkNotificationPermission() async {
    final permissionService = PermissionService();
    final hasPermission = await permissionService.hasNotificationPermission();

    if (!hasPermission && mounted) {
      // Show custom dialog explaining why we need notifications
      final granted = await PermissionDialog.show(
        context,
        permission: Permission.notification,
        title: 'Stay on Track!',
        customMessage:
            'TopScore AI works best when it can send you study reminders and important updates. Allow notifications to stay ahead!',
      );

      if (granted == true) {
        // If they allowed in our dialog, the actual OS prompt was triggered.
        // We can optionally refresh the UI or sync FCM token here.
        AuthProvider.instance.forceSyncFCMToken();
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final subtextColor = theme.textTheme.bodyMedium?.color ??
        (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Selector<AuthProvider,
        ({String? displayName, String? photoURL, bool isLoading})>(
      selector: (_, auth) => (
        displayName: auth.userModel?.displayName,
        photoURL: auth.userModel?.photoURL,
        isLoading: auth.isLoading || auth.userModel == null,
      ),
      builder: (context, userData, _) {
        final firstName = userData.displayName?.split(' ')[0] ?? 'Student';

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          // ... rest of the build method
          slivers: [
            // Header
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: 1,
                        fit: FlexFit.tight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: subtextColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              firstName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                color: textColor,
                                height: 1.15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Icons section with its own Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Notification Bell
                          Selector<NotificationProvider, int>(
                            selector: (_, p) => p.unreadCount,
                            builder: (context, unreadCount, _) {
                              return BounceWrapper(
                                onTap: () => context.push('/notifications'),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.05)
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.03),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.bell_fill,
                                        size: 20,
                                        color: isDark
                                            ? Colors.white70
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF6366F1),
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                              minWidth: 16, minHeight: 16),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          // Profile avatar
                          BounceWrapper(
                            onTap: () => context.push('/profile'),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: userData.photoURL != null &&
                                        userData.photoURL!.isNotEmpty
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            userData.photoURL!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                gradient: userData.photoURL != null &&
                                        userData.photoURL!.isNotEmpty
                                    ? null
                                    : LinearGradient(
                                        colors: [
                                          AppColors.primary
                                              .withValues(alpha: 0.15),
                                          const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : AppColors.primary
                                          .withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: userData.photoURL != null &&
                                      userData.photoURL!.isNotEmpty
                                  ? null
                                  : Center(
                                      child: Text(
                                        firstName.isNotEmpty
                                            ? firstName[0].toUpperCase()
                                            : 'S',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Hero Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: RepaintBoundary(child: _buildHeroCard(context, isDark)),
              ),
            ),

            // Study Tools Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "STUDY TOOLS",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: subtextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                context,
                                "Upload PDF",
                                CupertinoIcons.doc_text_fill,
                                const Color(0xFF8B5CF6),
                                const Color(0xFFA78BFA),
                                isDark,
                                '/summarizer',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildActionCard(
                                context,
                                "Flashcards",
                                CupertinoIcons.rectangle_on_rectangle_angled,
                                const Color(0xFFF59E0B),
                                const Color(0xFFFBBF24),
                                isDark,
                                '/flashcards',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                context,
                                "Take a Quiz",
                                CupertinoIcons.checkmark_seal_fill,
                                const Color(0xFF10B981),
                                const Color(0xFF34D399),
                                isDark,
                                '/quiz',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildActionCard(
                                context,
                                "Doc Scanner",
                                Icons.document_scanner_rounded,
                                const Color(0xFF06B6D4),
                                const Color(0xFF22D3EE),
                                isDark,
                                '/scanner',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                context,
                                "Your Library",
                                CupertinoIcons.folder_badge_person_crop,
                                const Color(0xFF8B5CF6),
                                const Color(0xFFA78BFA),
                                isDark,
                                '/my-stuff',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildActionCard(
                                context,
                                "Career Compass",
                                Icons.explore_rounded,
                                const Color(0xFF6366F1),
                                const Color(0xFF818CF8),
                                isDark,
                                '/career-compass',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Recent Sessions Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.surfaceElevatedDark : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "RECENT SESSIONS",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: subtextColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/my-stuff'),
                            child: Text(
                              "See All",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const RepaintBoundary(child: SessionHistoryCarousel()),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom padding for floating nav
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context, bool isDark) {
    return BounceWrapper(
      onTap: () async {
        final chatController =
            Provider.of<ChatController>(context, listen: false);
        await chatController.preWarmAudio();
        if (context.mounted) {
          context.go('/ai-tutor', extra: {'start_voice': true});
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF1E40AF), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary
                  .withValues(alpha: isDark ? 0.2 : 0.25),
              blurRadius: 32,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LivePulseIndicator(),
                        const SizedBox(width: 6),
                        Text(
                          "LIVE",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Talk to Your AI Tutor",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Voice conversations, instant help.",
                    style: GoogleFonts.nunito(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const _LiveWaveformIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color colorStart,
    Color colorEnd,
    bool isDark,
    String route, {
    VoidCallback? onTap,
  }) {
    return _AnimatedActionCard(
      title: title,
      icon: icon,
      colorStart: colorStart,
      colorEnd: colorEnd,
      isDark: isDark,
      route: route,
      onTap: onTap,
    );
  }
}

class _LivePulseIndicator extends StatefulWidget {
  const _LivePulseIndicator();

  @override
  State<_LivePulseIndicator> createState() => _LivePulseIndicatorState();
}

class _LivePulseIndicatorState extends State<_LivePulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4ADE80).withValues(alpha: _pulseAnimation.value * 0.8),
                blurRadius: 10 * _pulseAnimation.value,
                spreadRadius: 4 * _pulseAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveWaveformIcon extends StatefulWidget {
  const _LiveWaveformIcon();

  @override
  State<_LiveWaveformIcon> createState() => _LiveWaveformIconState();
}

class _LiveWaveformIconState extends State<_LiveWaveformIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
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
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: (_scaleAnimation.value - 0.95) * 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.waveform,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color colorStart;
  final Color colorEnd;
  final bool isDark;
  final String route;
  final VoidCallback? onTap;

  const _AnimatedActionCard({
    required this.title,
    required this.icon,
    required this.colorStart,
    required this.colorEnd,
    required this.isDark,
    required this.route,
    this.onTap,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: BounceWrapper(
        onTap: widget.onTap ?? () => context.push(widget.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _isHovered ? -4.0 : 0.0, 0.0, 1.0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.surfaceElevatedDark : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isDark
                  ? (_isHovered
                      ? widget.colorStart.withValues(alpha: 0.3)
                      : widget.colorStart.withValues(alpha: 0.1))
                  : (_isHovered
                      ? widget.colorStart.withValues(alpha: 0.2)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.04)),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isDark
                    ? widget.colorStart.withValues(alpha: _isHovered ? 0.12 : 0.06)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: _isHovered ? 0.08 : 0.03),
                blurRadius: _isHovered ? 24 : 16,
                offset: Offset(0, _isHovered ? 10 : 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.colorStart, widget.colorEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: widget.colorStart.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: widget.isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.surfaceElevatedDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

