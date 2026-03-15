import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  bool _isCheckingManually = false;
  bool _resendCooldown = false;
  int _resendCountdown = 0;
  Timer? _cooldownTimer;
  late AnimationController _iconPulse;

  @override
  void initState() {
    super.initState();
    _iconPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Auto-poll every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _autoCheckVerification();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _iconPulse.dispose();
    super.dispose();
  }

  Future<void> _autoCheckVerification() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final verified = await authProvider.reloadAndCheckEmailVerified();
    if (verified && mounted) {
      _pollTimer?.cancel();
      // GoRouter redirect handles navigation automatically via refreshListenable
    }
  }

  Future<void> _manualCheck() async {
    setState(() => _isCheckingManually = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final verified = await authProvider.reloadAndCheckEmailVerified();
    if (!mounted) return;
    setState(() => _isCheckingManually = false);
    if (verified) {
      _pollTimer?.cancel();
      // GoRouter redirect handles navigation automatically via refreshListenable
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not verified yet. Please check your inbox.'),
        ),
      );
    }
  }

  Future<void> _resendEmail() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.resendEmailVerification();
      if (!mounted) return;
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Check your inbox.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _startResendCooldown() {
    setState(() {
      _resendCooldown = true;
      _resendCountdown = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _resendCooldown = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Animated Icon
                    Center(
                      child: AnimatedBuilder(
                        animation: _iconPulse,
                        builder: (_, __) => Transform.scale(
                          scale: 1.0 + (_iconPulse.value * 0.08),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withValues(
                                      alpha: 0.3 + _iconPulse.value * 0.2),
                                  blurRadius: 25,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mark_email_unread_outlined,
                              size: 48,
                              color: AppColors.accentTeal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Verify Your Email",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "We've sent a verification link to your email. "
                            "Click the link, then come back — we'll detect it automatically.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),

                          // Auto-check indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentTeal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Auto-checking...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.accentTeal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Manual check button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (authProvider.isLoading ||
                                      _isCheckingManually)
                                  ? null
                                  : _manualCheck,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isCheckingManually
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      "I've Verified My Email",
                                      style: GoogleFonts.roboto(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Resend with cooldown
                          TextButton(
                            onPressed:
                                (authProvider.isLoading || _resendCooldown)
                                    ? null
                                    : _resendEmail,
                            child: Text(
                              _resendCooldown
                                  ? 'Resend in ${_resendCountdown}s'
                                  : 'Resend verification email',
                            ),
                          ),

                          // Sign out — GoRouter redirect handles navigation to /login
                          TextButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () async {
                                    await authProvider.signOut();
                                  },
                            child: const Text('Back to Sign In'),
                          ),

                          const SizedBox(height: 8),

                          // Help tips
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.hintColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Didn\'t receive it?',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '• Check your spam/junk folder\n'
                                  '• Make sure you entered the correct email\n'
                                  '• Wait a minute before requesting again',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
