import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';

class TrialCompletedOverlay extends StatelessWidget {
  /// When true, the user is a guest who needs to create an account.
  /// When false, the user is a free authenticated user who needs to upgrade.
  final bool requiresAccount;

  const TrialCompletedOverlay({
    super.key,
    this.requiresAccount = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headline = requiresAccount ? "Trial Completed" : "Free Limit Reached";
    final subtitle = requiresAccount
        ? "You've used your 6 free messages."
        : "You've used all 6 free messages for this period.";

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.4),
      body: Stack(
        children: [
          // 1. Background Blobs for Premium Depth
          Positioned(
            top: -100,
            right: -50,
            child: _Blob(
              color: AppColors.primaryPurple.withValues(alpha: 0.2),
              size: 300,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _Blob(
              color: AppColors.accentTeal.withValues(alpha: 0.15),
              size: 250,
            ),
          ),

          // 2. Main Content Card with Glassmorphism
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white)
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo / Icon Area
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryPurple,
                                AppColors.primaryPurple.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple
                                    .withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            color: Colors.white,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          headline,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Benefits
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BenefitItem(text: "Unlimited AI Tutor messages"),
                              const SizedBox(height: 12),
                              _BenefitItem(text: "AI Flashcards & Quiz Generation"),
                              const SizedBox(height: 12),
                              _BenefitItem(text: "Live Voice AI Tutor sessions"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        if (requiresAccount) ...[
                          _AuthButton(
                            label: "Create Free Profile",
                            isPrimary: true,
                            onTap: () => context.push('/login?isRegister=true'),
                          ),
                          const SizedBox(height: 12),
                          _AuthButton(
                            label: "Sign In",
                            isPrimary: false,
                            onTap: () => context.push('/login'),
                          ),
                        ] else ...[
                          _AuthButton(
                            label: "Upgrade to Premium",
                            isPrimary: true,
                            onTap: () => context.push('/subscription'),
                          ),
                          const SizedBox(height: 12),
                          _AuthButton(
                            label: "Maybe Later",
                            isPrimary: false,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? AppColors.primaryPurple : Colors.transparent,
          foregroundColor:
              isPrimary ? Colors.white : theme.colorScheme.onSurface,
          elevation: 0,
          side: !isPrimary
              ? BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;

  const _BenefitItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.primaryPurple,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
