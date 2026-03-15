import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../services/haptics_service.dart';
import '../constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_cache_manager.dart';
import 'offline_banner.dart';
import 'command_palette.dart';
import '../config/app_theme.dart';
import '../providers/navigation_provider.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell})
      : super(key: const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isCollapsed = false;

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  void _showCommandPalette() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Command Palette',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return CommandPalette(
          onNavigate: (index) {
            widget.navigationShell.goBranch(index, initialLocation: true);
          },
          onLoadThread: (threadId) {
            Provider.of<NavigationProvider>(context, listen: false)
                .navigateToChat(threadId: threadId);
          },
          onStartNewChat: () {
            Provider.of<NavigationProvider>(context, listen: false)
                .navigateToChat();
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthProvider>(context).userModel;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showCommandPalette,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          return _MobileLayout(
            navigationShell: widget.navigationShell,
            isDark: isDark,
          );
        } else {
          return _DesktopLayout(
            navigationShell: widget.navigationShell,
            isDark: isDark,
            isCollapsed: _isCollapsed,
            onToggle: _toggleSidebar,
            user: user,
          );
        }
      },
    ),
  );
}
}

class _MobileLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final bool isDark;

  const _MobileLayout({
    required this.navigationShell,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarTheme.of(context).copyWith(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: AppTheme.buildGlassContainer(
            context,
            borderRadius: 24,
            padding: EdgeInsets.zero,
            child: NavigationBar(
              height: 70,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                HapticFeedback.lightImpact();
                navigationShell.goBranch(index, initialLocation: true);
              },
              destinations: [
                const NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.house, size: 20),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.folderOpen, size: 20),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Consumer<NotificationProvider>(
                    builder: (context, provider, child) {
                      final count = provider.unreadCount;
                      final isSelected = navigationShell.currentIndex == 2;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: count > 0
                            ? Badge.count(
                                count: count,
                                child: FaIcon(
                                  FontAwesomeIcons.brain, 
                                  size: 24,
                                  color: isSelected ? AppColors.primary : null,
                                ),
                              )
                            : FaIcon(
                                FontAwesomeIcons.brain, 
                                size: 24,
                                color: isSelected ? AppColors.primary : null,
                              ),
                      );
                    },
                  ),
                  label: 'AI Tutor',
                ),
                const NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.briefcase, size: 20),
                  label: 'Tools',
                ),
                const NavigationDestination(
                  icon: FaIcon(FontAwesomeIcons.user, size: 20),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final bool isDark;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final dynamic user;

  const _DesktopLayout({
    required this.navigationShell,
    required this.isDark,
    required this.isCollapsed,
    required this.onToggle,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) {
              HapticFeedback.lightImpact();
              navigationShell.goBranch(index, initialLocation: true);
            },
            isDark: isDark,
            isCollapsed: isCollapsed,
            onToggle: onToggle,
            user: user,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final bool isProminent;

  const _NavItemData({
    required this.icon,
    required this.label,
    this.isProminent = false,
  });
}

const _navItems = [
  _NavItemData(icon: FontAwesomeIcons.house, label: 'Home'),
  _NavItemData(icon: FontAwesomeIcons.folderOpen, label: 'Library'),
  _NavItemData(
    icon: FontAwesomeIcons.brain,
    label: 'AI Tutor',
    isProminent: true,
  ),
  _NavItemData(icon: FontAwesomeIcons.briefcase, label: 'Tools'),
  _NavItemData(icon: FontAwesomeIcons.user, label: 'Profile'),
];

// =============================================================================
// Desktop: Enhanced Sidebar
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
      width: isCollapsed ? 80 : 260,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.65),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.surfaceDark.withValues(alpha: 0.85),
                        AppColors.surfaceDark.withValues(alpha: 0.65),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.8),
                        Colors.white.withValues(alpha: 0.6),
                      ],
              ),
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 15,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _SidebarLogoHeader(
                  isCollapsed: isCollapsed,
                  isDark: isDark,
                  onToggle: onToggle,
                ),
                const SizedBox(height: 12),
                ...List.generate(4, (i) {
                  final item = _navItems[i];
                  return _SidebarItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: currentIndex == i,
                    onTap: () => onTap(i),
                    isProminent: item.isProminent,
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                  );
                }),
                const Spacer(),
                _SidebarSyncInfo(isCollapsed: isCollapsed),
                _SidebarProfileSection(
                  isCollapsed: isCollapsed,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  isDark: isDark,
                  user: user,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLogoHeader extends StatelessWidget {
  final bool isCollapsed;
  final bool isDark;
  final VoidCallback onToggle;

  const _SidebarLogoHeader({
    required this.isCollapsed,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 12 : 24,
        vertical: 24,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (!isCollapsed) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/launcher_icon.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'TopScore AI',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.chevron_right : Icons.chevron_left,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            onPressed: onToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _SidebarSyncInfo extends StatelessWidget {
  final bool isCollapsed;

  const _SidebarSyncInfo({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
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
              Icon(
                Icons.sync_rounded,
                size: 12,
                color: Colors.grey.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Last updated at $timeStr',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarProfileSection extends StatelessWidget {
  final bool isCollapsed;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final dynamic user;

  const _SidebarProfileSection({
    required this.isCollapsed,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isCollapsed ? 8 : 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(4),
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.accentTeal.withValues(
            alpha: 0.06,
          ),
          splashColor: AppColors.accentTeal.withValues(
            alpha: 0.12,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: currentIndex == 4
                  ? AppColors.accentTeal.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: currentIndex == 4
                  ? Border.all(
                      color: AppColors.accentTeal.withValues(
                        alpha: 0.25,
                      ),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary,
                  backgroundImage:
                      (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                          ? CachedNetworkImageProvider(
                              user.photoURL!,
                              cacheManager: kIsWeb ? null : ProfileImageCacheManager(),
                            )
                          : null,
                  child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                      ? Text(
                          (user?.displayName != null &&
                                  user!.displayName.isNotEmpty)
                              ? user.displayName[0].toUpperCase()
                              : 'S',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Settings',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
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
      ),
    );
  }
}

// =============================================================================
// Desktop: Sidebar Item with Hover Effect
// =============================================================================

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isProminent;
  final bool isCollapsed;
  final bool isDark;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isProminent = false,
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
    final defaultColor = widget.isDark ? Colors.grey[700]! : Colors.grey[700]!;
    final activeColor = widget.isSelected
        ? AppColors.accentTeal
        : (widget.isDark ? Colors.grey[400]! : defaultColor);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCollapsed ? 8 : 16,
        vertical: 3,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticsService.instance.lightImpact();
                widget.onTap();
              },
              borderRadius: BorderRadius.circular(12),
              hoverColor: Colors.transparent,
              splashColor: AppColors.accentTeal.withValues(
                alpha: 0.12,
              ),
              child: Tooltip(
                message: widget.isCollapsed ? widget.label : "",
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppColors.accentTeal.withValues(alpha: 0.15)
                        : _isHovered
                            ? (widget.isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04))
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: widget.isSelected
                        ? Border.all(
                            color: AppColors.accentTeal.withValues(
                              alpha: 0.35,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: widget.isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          FaIcon(
                            widget.icon,
                            size: 18,
                            color: _isHovered && !widget.isSelected
                                ? (widget.isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[600])
                                : activeColor,
                          ),
                          if (widget.isCollapsed &&
                              widget.isProminent &&
                              !widget.isSelected)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentTeal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
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
                              color: widget.isSelected
                                  ? (widget.isDark
                                      ? Colors.white
                                      : AppColors.accentTeal)
                                  : _isHovered
                                      ? (widget.isDark
                                          ? Colors.grey[200]
                                          : Colors.grey[700])
                                      : (widget.isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[800]),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isProminent && !widget.isSelected) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.accentTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
