import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/colors.dart';

class TopScoreLoader extends StatelessWidget {
  final String? message;
  final bool showProgress;
  final double progress;

  const TopScoreLoader({
    super.key,
    this.message,
    this.showProgress = false,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Rotating Ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    width: 4,
                  ),
                ),
              ),
              
              // Animated Spinner Ring
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: showProgress && progress > 0 ? progress : null,
                  strokeWidth: 4,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ).animate(onPlay: (c) => c.repeat())
               .rotate(duration: 2.seconds),

              // Logo in the center
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Image.asset(
                  'assets/images/topscore_logo_transparent.png',
                  fit: BoxFit.contain,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1.seconds),
            ],
          ),
          
          if (message != null) ...[
            const SizedBox(height: 32),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    );
  }
}
