import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/colors.dart';

class TrialCompletedOverlay extends StatelessWidget {
  const TrialCompletedOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Frosted glass background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6),
              ),
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with animated-like glow
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Headline
                  Text(
                    "Trial Completed",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    "You've used all your 3 free guest messages. Sign in now to unlock unlimited access and save your progress!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: theme.hintColor.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Google Sign In
                  _AuthButton(
                    label: "Continue with Google",
                    isGoogle: true,
                    onTap: () => _handleGoogleSignIn(context),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Email Sign Up
                  _AuthButton(
                    label: "Sign up with Email",
                    isPrimary: true,
                    onTap: () => context.push('/login?isRegister=true'),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Sign In
                  _AuthButton(
                    label: "I already have an account",
                    onTap: () => context.push('/login?isRegister=false'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.signInWithGoogle();
      // Redirect handled by router RefreshListenable
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    }
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isGoogle;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    this.isPrimary = false,
    this.isGoogle = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary 
              ? AppColors.primaryPurple 
              : (isGoogle ? Colors.white : Colors.transparent),
          foregroundColor: isPrimary 
              ? Colors.white 
              : (isGoogle ? Colors.black87 : theme.colorScheme.onSurface),
          elevation: isGoogle ? 1 : 0,
          side: (!isPrimary && !isGoogle) 
              ? BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)) 
              : (isGoogle ? BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)) : null),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGoogle) ...[
              Image.asset(
                'assets/images/google_logo.png',
                height: 24,
                width: 24,
              ),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

