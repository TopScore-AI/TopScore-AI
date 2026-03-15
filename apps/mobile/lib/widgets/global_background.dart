import 'package:flutter/material.dart';
import '../constants/colors.dart';

class GlobalBackground extends StatelessWidget {
  final Widget child;

  const GlobalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Base Background
          Container(color: theme.scaffoldBackgroundColor),

          // Animated/Static Mesh Gradients for Glass Depth
          Positioned(
            top: -100,
            right: -50,
            child: _GlowCircle(
              color: AppColors.kidBlue.withValues(alpha: isDark ? 0.3 : 0.15),
              size: 450,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: _GlowCircle(
              color: AppColors.kidPink.withValues(alpha: isDark ? 0.25 : 0.12),
              size: 400,
            ),
          ),
          if (isDark)
            Positioned(
              top: 200,
              left: 50,
              child: _GlowCircle(
                color: AppColors.kidPurple.withValues(alpha: 0.12),
                size: 350,
              ),
            ),

          // The actual content
          child,
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
