import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Overlay type determines which Lottie animation + copy to show.
enum LevelUpType { streak7, streakMilestone, missionCleared, levelUp, prestige }

/// Full-screen sci-fi HUD overlay shown on major achievements.
/// Usage:
///   LevelUpOverlay.show(context, type: LevelUpType.levelUp, level: 5);
class LevelUpOverlay extends StatefulWidget {
  final LevelUpType type;
  final VoidCallback? onDismiss;

  /// For [LevelUpType.levelUp] and [LevelUpType.prestige], the new level number.
  final int? level;

  const LevelUpOverlay(
      {super.key, required this.type, this.onDismiss, this.level});

  static Future<void> show(
    BuildContext context, {
    required LevelUpType type,
    VoidCallback? onDismiss,
    int? level,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) =>
          LevelUpOverlay(type: type, onDismiss: onDismiss, level: level),
    );
  }

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay> {
  @override
  void initState() {
    super.initState();
    // Triple-buzz on overlay open — feels like a system alert
    HapticFeedback.heavyImpact();
    Future.delayed(
        const Duration(milliseconds: 150), HapticFeedback.mediumImpact);
    Future.delayed(
        const Duration(milliseconds: 300), HapticFeedback.lightImpact);
  }

  _OverlayContent get _content {
    switch (widget.type) {
      case LevelUpType.streak7:
        return _OverlayContent(
          lottieAsset: 'assets/lottie/achievement.json',
          headline: '7-DAY STREAK',
          subline: 'MISSION ACTIVE',
          accentColor: const Color(0xFFFF8C00),
          badge: '🔥',
        );
      case LevelUpType.streakMilestone:
        return _OverlayContent(
          lottieAsset: 'assets/lottie/achievement.json',
          headline: 'STREAK MILESTONE',
          subline: 'LEVEL UP',
          accentColor: const Color(0xFFFFD700),
          badge: '🏆',
        );
      case LevelUpType.missionCleared:
        return _OverlayContent(
          lottieAsset: 'assets/lottie/mission_clear.json',
          headline: 'MODULE MASTERED',
          subline: 'MISSION CLEARED',
          accentColor: const Color(0xFF00E5FF),
          badge: '⚡',
        );
      case LevelUpType.levelUp:
        final lvl = widget.level;
        return _OverlayContent(
          lottieAsset: 'assets/lottie/level_up.json',
          headline: lvl != null ? 'LEVEL $lvl' : 'LEVEL UP',
          subline: 'NEW RANK UNLOCKED',
          accentColor: const Color(0xFF7C3AED),
          badge: '🚀',
        );
      case LevelUpType.prestige:
        final lvl = widget.level;
        return _OverlayContent(
          lottieAsset: 'assets/lottie/level_up.json',
          headline: lvl != null ? 'PRESTIGE $lvl' : 'PRESTIGE',
          subline: 'ELITE SCHOLAR',
          accentColor: const Color(0xFFEC4899),
          badge: '💎',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _content;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            widget.onDismiss?.call();
          },
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: c.accentColor.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: c.accentColor.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HUD corner accents
                _HudCorners(color: c.accentColor),
                const SizedBox(height: 8),

                // Lottie animation
                _LottieOrFallback(
                    asset: c.lottieAsset, badge: c.badge, color: c.accentColor),

                const SizedBox(height: 16),

                // Headline
                Text(
                  c.headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.accentColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 6),

                // Subline
                Text(
                  c.subline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 24),

                // Dismiss hint
                Text(
                  'TAP TO CONTINUE',
                  style: TextStyle(
                    color: c.accentColor.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _OverlayContent {
  final String lottieAsset;
  final String headline;
  final String subline;
  final Color accentColor;
  final String badge;

  const _OverlayContent({
    required this.lottieAsset,
    required this.headline,
    required this.subline,
    required this.accentColor,
    required this.badge,
  });
}

/// Tries to load a Lottie asset; falls back to an emoji badge if missing.
class _LottieOrFallback extends StatelessWidget {
  final String asset;
  final String badge;
  final Color color;

  const _LottieOrFallback({
    required this.asset,
    required this.badge,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Lottie.asset(
        asset,
        repeat: false,
        errorBuilder: (_, __, ___) => Center(
          child: Text(badge, style: const TextStyle(fontSize: 80)),
        ),
      ),
    );
  }
}

/// Four corner bracket decorations — classic HUD aesthetic.
class _HudCorners extends StatelessWidget {
  final Color color;
  const _HudCorners({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _corner(color, top: true, left: true),
          _corner(color, top: true, left: false),
        ],
      ),
    );
  }

  Widget _corner(Color c, {required bool top, required bool left}) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: c, width: 2) : BorderSide.none,
          bottom: !top ? BorderSide(color: c, width: 2) : BorderSide.none,
          left: left ? BorderSide(color: c, width: 2) : BorderSide.none,
          right: !left ? BorderSide(color: c, width: 2) : BorderSide.none,
        ),
      ),
    );
  }
}
