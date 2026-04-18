import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TopScoreWatermark extends StatelessWidget {
  final Widget child;
  final double opacity;
  final bool isDark;

  const TopScoreWatermark({
    super.key,
    required this.child,
    this.opacity = 0.5,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 12,
          right: 12,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.2 * opacity),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1 * opacity),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtle Sparkle Icon
                  Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4 * opacity),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'TopScore AI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4 * opacity),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
