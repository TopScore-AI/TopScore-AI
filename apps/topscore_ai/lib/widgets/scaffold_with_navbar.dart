import 'dart:ui';
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

import 'trial_completed_overlay.dart';


class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
      : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isCollapsed = false;


  @override
  void initState() {
    super.initState();
    _restoreLastTab();
  }

  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTab = prefs.getInt('last_tab');
    if (lastTab != null && lastTab != widget.navigationShell.currentIndex) {
      if (mounted) {
        widget.navigationShell.goBranch(lastTab);
        await prefs.remove('last_tab');
      }
    }
  }

  @override
  void dispose() {

    super.dispose();
  }

  Future<void> _goBranch(int index) async {
    HapticFeedback.lightImpact();
    widget.navigationShell.goBranch(index, initialLocation: true);
    
    // Persist the current tab so we can restore if the app is killed in bg
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_tab', index);
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthProvider>(context).userModel;

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
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final showTrialBlock = auth.isGuestMode && auth.isGuestLimitReached;
        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: isKeyboardOpen ? 0 : 90), // Buffer for floating bar
                child: widget.navigationShell,
              ),
              // Floating Pill Navigation - Hide when keyboard is open
              if (!isKeyboardOpen)
                Positioned(
                  bottom: 12, // Pushed a little lower
                  left: 24,
                  right: 24,
                  child: SafeArea(
                    child: _FloatingPillNavBar(
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: _goBranch,
                      isDark: isDark,
                    ),
                  ),
                ),
              if (showTrialBlock)
                const Positioned.fill(
                  child: TrialCompletedOverlay(),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDesktopLayout(bool isDark, dynamic user) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final showTrialBlock = auth.isGuestMode && auth.isGuestLimitReached;

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
              if (showTrialBlock)
                const Positioned.fill(
                  child: TrialCompletedOverlay(),
                ),
            ],
          ),
        );
      }
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
                ? const Color(0xFF1E293B).withValues(alpha: 0.7)
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
              _buildNavItem(context, 0, CupertinoIcons.home, CupertinoIcons.house_fill, "Home"),
              _buildNavItem(context, 1, CupertinoIcons.folder, CupertinoIcons.folder_solid, "Library"),
              _buildNavItem(context, 2, CupertinoIcons.chat_bubble_2, CupertinoIcons.chat_bubble_2_fill, "AI Tutor"),
              _buildNavItem(context, 3, CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill, "Tools"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, int index, IconData outlinedIcon, IconData filledIcon, String label) {
    final isSelected = currentIndex == index;
    final icon = isSelected ? filledIcon : outlinedIcon;
    final primaryColor = const Color(0xFF2563EB);

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
                    color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
                    blurRadius: 12,
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
                  : (isDark ? Colors.white54 : Colors.black54),
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
            icon: CupertinoIcons.folder,
            activeIcon: CupertinoIcons.folder_solid,
            label: "Library",
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
            isCollapsed: isCollapsed,
            isDark: isDark,
          ),
          _SidebarItem(
            icon: CupertinoIcons.chat_bubble_2,
            activeIcon: CupertinoIcons.chat_bubble_2_fill,
            label: "AI Tutor",
            isSelected: currentIndex == 2,
            onTap: () => onTap(2),
            isCollapsed: isCollapsed,
            isDark: isDark,
          ),
          _SidebarItem(
            icon: CupertinoIcons.square_grid_2x2,
            activeIcon: CupertinoIcons.square_grid_2x2_fill,
            label: "Tools",
            isSelected: currentIndex == 3,
            onTap: () => onTap(3),
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
            Image.asset('assets/images/topscore_logo.png',
                width: 28, height: 28),
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
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
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
                            color: Color(0xFF2563EB),
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

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCollapsed = false,
    required this.isDark,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isSelected
        ? const Color(0xFF2563EB)
        : (widget.isDark ? Colors.white60 : Colors.black54);

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
                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
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
                Icon(widget.isSelected ? widget.activeIcon : widget.icon, size: 20, color: activeColor),
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
