import '../../constants/colors.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/haptics_service.dart';
import 'package:intl/intl.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../utils/image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
      : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isCollapsed = false;
  bool _showAppPromo = false;
  bool _isTutorNavBarVisible = false;

  @override
  void initState() {
    super.initState();
    _restoreLastTab();
    _checkAppPromo();
  }

  Future<void> _checkAppPromo() async {
    // Only show on Web mobile browsers
    if (!kIsWeb) return;

    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (!isMobile) return;

    final prefs = await SharedPreferences.getInstance();
    final hidePromo = prefs.getBool('hide_app_promo') ?? false;
    if (!hidePromo) {
      // Small delay to make the entry feel smooth and premium after the app loads
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _showAppPromo = true;
        });
      }
    }
  }

  Future<void> _dismissAppPromo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_app_promo', true);
    if (mounted) {
      setState(() {
        _showAppPromo = false;
      });
    }
  }

  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();

    // Use a unified key across the app to prevent conflicts
    final lastTab = prefs.getInt('active_tab_index');

    if (lastTab != null) {
      // Safety check: The current layout has exactly 3 tabs (0: Home, 1: Tutor, 2: Library)
      if (lastTab >= 0 && lastTab < 3) {
        if (lastTab != widget.navigationShell.currentIndex && mounted) {
          widget.navigationShell.goBranch(lastTab);
        }
      } else {
        // If the persisted index is invalid (e.g. from an old 5-tab layout),
        // default to Home and clear the bad data.
        await prefs.setInt('active_tab_index', 0);
      }
    } else {
      // First boot: Explicitly set to 0 to ensure we land on Home
      await prefs.setInt('active_tab_index', 0);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _goBranch(int index) async {
    HapticFeedback.lightImpact();
    widget.navigationShell.goBranch(index, initialLocation: true);

    // Persist using the unified key
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_tab_index', index);

    // Cleanup old/conflicting legacy keys if they exist
    if (prefs.containsKey('last_tab')) await prefs.remove('last_tab');
    if (prefs.containsKey('current_nav_index')) {
      await prefs.remove('current_nav_index');
    }

    if (index == 1) {
      setState(() {
        _isTutorNavBarVisible = false;
      });
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (widget.navigationShell.currentIndex != 1) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta ?? 0;
      if (scrollDelta < -5) {
        // Scroll Up (drag finger down) -> Show navigation bar
        if (!_isTutorNavBarVisible) {
          setState(() {
            _isTutorNavBarVisible = true;
          });
        }
      } else if (scrollDelta > 5) {
        // Scroll Down (drag finger up) -> Hide navigation bar
        if (_isTutorNavBarVisible) {
          setState(() {
            _isTutorNavBarVisible = false;
          });
        }
      }
    }
    return false;
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user =
        context.select<AuthProvider, dynamic>((auth) => auth.userModel);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          return _buildMobileLayout(isDark);
        } else {
          return _buildDesktopLayout(isDark, user);
        }
      },
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    final theme = Theme.of(context);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // Hide navigation for AI Tutor (index 1) to create an immersive, Gemini-style experience.
    final isAiTutor = widget.navigationShell.currentIndex == 1;
    final showNavBar = !isKeyboardOpen && (!isAiTutor || _isTutorNavBarVisible);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
                bottom: (isKeyboardOpen || isAiTutor) ? 0 : 90), // Buffer for floating bar
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: widget.navigationShell,
            ),
          ),

          // Floating Pill Navigation - Slides up on scroll, slides down to hide
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            bottom: showNavBar ? 12 : -100, // Slides off-screen when hidden
            left: 24,
            right: 24,
            child: SafeArea(
              child: RepaintBoundary(
                child: _FloatingPillNavBar(
                  currentIndex: widget.navigationShell.currentIndex,
                  onTap: _goBranch,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // Mobile App Promo Popup - Hide when in AI Tutor
          if (!isAiTutor) _buildAppPromoBanner(context, isDark),
        ],
      ),
    );
  }

  Widget _buildAppPromoBanner(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      bottom: _showAppPromo ? 104 : -300, // Slides up from bottom
      left: 16,
      right: 16,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceElevatedDark.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          isAndroid
                              ? Icons.android_rounded
                              : Icons.phone_iphone_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Study Smarter on the App!',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Open in the TopScore AI app for real-time multiplayer revision, live AI tutor voice chat, and physical paper scanning.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _dismissAppPromo,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticsService.instance.lightImpact();
                            final uri = Uri.parse('topscore://home');
                            try {
                              final launched = await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                              if (!launched) {
                                final storeUri = Uri.parse(isAndroid
                                    ? 'https://play.google.com/store/apps/details?id=com.topscoreapp.ai'
                                    : 'https://apps.apple.com/app/topscore-ai/id6476140411');
                                await launchUrl(storeUri,
                                    mode: LaunchMode.externalApplication);
                              }
                            } catch (_) {
                              final storeUri = Uri.parse(isAndroid
                                  ? 'https://play.google.com/store/apps/details?id=com.topscoreapp.ai'
                                  : 'https://apps.apple.com/app/topscore-ai/id6476140411');
                              await launchUrl(storeUri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: Text(
                            'Open App',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            HapticsService.instance.lightImpact();
                            final storeUri = Uri.parse(isAndroid
                                ? 'https://play.google.com/store/apps/details?id=com.topscoreapp.ai'
                                : 'https://apps.apple.com/app/topscore-ai/id6476140411');
                            await launchUrl(storeUri,
                                mode: LaunchMode.externalApplication);
                          },
                          icon: Icon(
                            isAndroid
                                ? Icons.play_arrow_rounded
                                : Icons.apple_rounded,
                            size: 16,
                          ),
                          label: Text(
                            'Install App',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            side: BorderSide(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.15),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDark, dynamic user) {

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              _DesktopSidebar(
                currentIndex: widget.navigationShell.currentIndex,
                onTap: _goBranch,
                isDark: isDark,
                isCollapsed: _isCollapsed,
                onToggle: _toggleSidebar,
                user: user,
              ),
              Expanded(child: widget.navigationShell),
            ],
          ),


        ],
      ),
    );
  }
}

// =============================================================================
// Mobile: Floating Pill Navigation Bar
// =============================================================================

class _FloatingPillNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _FloatingPillNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceElevatedDark.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, CupertinoIcons.home,
                  CupertinoIcons.house_fill, "Home"),
              _buildNavItem(context, 1, CupertinoIcons.chat_bubble_2,
                  CupertinoIcons.chat_bubble_2_fill, "AI Tutor",
                  isCenter: true),
              _buildNavItem(context, 2, CupertinoIcons.folder,
                  CupertinoIcons.folder_solid, "Library"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData outlinedIcon,
      IconData filledIcon, String label,
      {bool isCenter = false}) {
    final isSelected = currentIndex == index;
    final icon = isSelected ? filledIcon : outlinedIcon;
    final theme = Theme.of(context);
    const primaryColor =
        AppColors.primary; // Consistent Blue for all active tabs

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticsService.instance.lightImpact();
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCirc,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? primaryColor
                  : (isDark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Desktop: Enhanced Sidebar (Cleaned up)
// =============================================================================

class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final dynamic user;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    required this.isCollapsed,
    required this.onToggle,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 72 : 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLogoHeader(context),
          const SizedBox(height: 12),
          _SidebarItem(
            icon: CupertinoIcons.home,
            activeIcon: CupertinoIcons.house_fill,
            label: "Home",
            isSelected: currentIndex == 0,
            onTap: () => onTap(0),
            isCollapsed: isCollapsed,
            isDark: isDark,
          ),
          _SidebarItem(
            icon: CupertinoIcons.chat_bubble_2,
            activeIcon: CupertinoIcons.chat_bubble_2_fill,
            label: "AI Tutor",
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
            isCollapsed: isCollapsed,
            isDark: isDark,
            isPrimary: true,
          ),
          _SidebarItem(
            icon: CupertinoIcons.folder,
            activeIcon: CupertinoIcons.folder_solid,
            label: "Library",
            isSelected: currentIndex == 2,
            onTap: () => onTap(2),
            isCollapsed: isCollapsed,
            isDark: isDark,
          ),
          const Spacer(),
          _buildSyncInfo(context),
          _buildProfileSection(context),
        ],
      ),
    );
  }

  Widget _buildLogoHeader(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 24, vertical: 24),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (!isCollapsed) ...[
            Image.asset('assets/images/logo.png', width: 28, height: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'TopScore AI',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          IconButton(
            icon: Icon(isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                size: 20, color: Colors.grey),
            onPressed: onToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncInfo(BuildContext context) {
    if (isCollapsed) return const SizedBox.shrink();

    return Consumer<AiTutorHistoryProvider>(
      builder: (context, provider, child) {
        final lastFetch = provider.lastFetchTime;
        if (lastFetch == null) return const SizedBox.shrink();
        final timeStr = DateFormat('h:mm a').format(lastFetch);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.sync_rounded,
                  size: 12, color: Colors.grey.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                'Updated $timeStr',
                style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.grey.withValues(alpha: 0.6)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isCollapsed ? 8 : 16),
      child: InkWell(
        onTap: () => context.push('/profile'),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage:
                    user?.photoURL != null && user!.photoURL!.isNotEmpty
                        ? CachedNetworkImageProvider(
                            user!.photoURL!,
                            cacheManager: ProfileImageCacheManager(),
                          )
                        : null,
                child: user?.photoURL == null || user!.photoURL!.isEmpty
                    ? Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Profile',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Settings',
                        style:
                            GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCollapsed;
  final bool isDark;
  final bool isPrimary;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCollapsed = false,
    required this.isDark,
    this.isPrimary = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isSelected
        ? (widget.isPrimary ? const Color(0xFF6366F1) : AppColors.primary)
        : (widget.isDark
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7));

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: widget.isCollapsed ? 8 : 16, vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: () {
            HapticsService.instance.lightImpact();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : (_isHovered
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: widget.isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(widget.isSelected ? widget.activeIcon : widget.icon,
                    size: 20, color: activeColor),
                if (!widget.isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: activeColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
