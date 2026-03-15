import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../constants/strings.dart';
import '../../services/recaptcha_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/global_background.dart';
import '../../config/app_theme.dart';
import '../../utils/browser_utils.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegister = false;
  String _selectedRole = 'student';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Load and show reCAPTCHA script only on auth pages
    RecaptchaService.loadRecaptchaScript();
    RecaptchaService.showBadge();
  }

  @override
  void dispose() {
    // Hide reCAPTCHA badge when leaving auth
    RecaptchaService.hideBadge();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[LOGIN] build() entered');
    // Only disable UI during explicit sign-in operations (_isSubmitting),
    // not during initial auth resolution (authProvider.isLoading).
    // This prevents the login page from appearing blank/frozen on first load.
    final theme = Theme.of(context);
    final isLoading = _isSubmitting;

    return GlobalBackground(
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
                    if (BrowserUtils.isInAppBrowser) _buildIabWarningBanner(theme),
                    // Logo Section
                    _buildLogoSection(theme),
                    const SizedBox(height: 60),

                    // Login Form Card
                    GlassCard(
                      borderRadius: AppTheme.radiusXl,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Welcome!",
                            style: GoogleFonts.quicksand(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Let's play and learn together",
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Google Sign In Button
                          _buildGoogleButton(theme, isLoading),

                          const SizedBox(height: 16),

                          // Divider with "or"
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.quicksand(
                                    fontWeight: FontWeight.w700,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          _buildEmailPasswordForm(theme, isLoading),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildLogoSection(ThemeData theme) {
    return Column(
      children: [
        AppTheme.buildGlassContainer(
          context,
          borderRadius: 32,
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/images/topscore_logo.jpg',
            height: 120,
            width: 120,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.appName,
          style: GoogleFonts.quicksand(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.kidBlue,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(
    ThemeData theme,
    bool isLoading,
  ) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading
            ? null
            : () async {
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.signInWithGoogle();
                  if (!mounted) return;
                  if (authProvider.isAuthenticated) {
                    context.go('/home');
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Sign in failed. Please try again.',
                      ),
                      backgroundColor: AppColors.error,
                      action: SnackBarAction(
                        label: 'Retry',
                        textColor: Colors.white,
                        onPressed: () async {
                          try {
                            await Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            ).signInWithGoogle();
                          } catch (_) {}
                        },
                      ),
                    ),
                  );
                }
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: theme.brightness == Brightness.light ? Colors.white : Colors.white.withValues(alpha: 0.05),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) {
                return const FaIcon(
                  FontAwesomeIcons.google,
                  size: 20,
                  color: AppColors.error,
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              "Continue with Google",
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailPasswordForm(
    ThemeData theme,
    bool isLoading,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isRegister ? 'Create account with email' : 'Sign in with email',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Name field (sign-up only)
          if (_isRegister) ...[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Name is required';
                if (name.length < 2) return 'Enter your full name';
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // --- 🚀 ROLE SELECTION ---
            Text(
              "I am a:",
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'student',
                  label: Text('Student'),
                  icon: Icon(Icons.school_outlined),
                ),
                ButtonSegment<String>(
                  value: 'teacher',
                  label: Text('Teacher'),
                  icon: Icon(Icons.history_edu_outlined),
                ),
                ButtonSegment<String>(
                  value: 'parent',
                  label: Text('Parent'),
                  icon: Icon(Icons.family_restroom_outlined),
                ),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedRole = newSelection.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.comfortable,
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Email is required';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(email)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: _isRegister
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            onChanged: _isRegister ? (_) => setState(() {}) : null,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.length < 6) {
                return 'Password must be at least 6 characters';
              }
              if (_isRegister && _getPasswordStrength(password) < 2) {
                return 'Password is too weak. Add numbers or symbols.';
              }
              return null;
            },
          ),

          // Password strength indicator (sign-up only)
          if (_isRegister && _passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPasswordStrengthIndicator(theme),
          ],

          // Confirm password (sign-up only)
          if (_isRegister) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
              ),
              validator: (value) {
                if ((value ?? '') != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: (isLoading || _isSubmitting) ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isRegister ? 'Create Account' : 'Sign In',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (!_isRegister)
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = _emailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter your email to reset password'),
                          ),
                        );
                        return;
                      }
                      try {
                        await Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).sendPasswordReset(email);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password reset email sent'),
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Could not send reset email. Please check your email address.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Forgot password?'),
            ),
          TextButton(
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      _isRegister = !_isRegister;
                      _confirmPasswordController.clear();
                      _nameController.clear();
                    });
                  },
            child: Text(
              _isRegister
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account',
            ),
          ),
        ],
      ),
    );
  }

  // ── Password strength ────────────────────────────────────────────

  /// Returns 0-4 (weak → strong)
  int _getPasswordStrength(String password) {
    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  Widget _buildPasswordStrengthIndicator(ThemeData theme) {
    final strength = _getPasswordStrength(_passwordController.text);
    final labels = ['Very Weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.lightGreen,
      Colors.green,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < strength
                      ? colors[strength]
                      : theme.dividerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          labels[strength],
          style: TextStyle(
            fontSize: 11,
            color: colors[strength],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Submit handler ───────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      bool success = false;
      if (_isRegister) {
        success = await authProvider.signUpWithEmail(
          email,
          password,
          displayName: _nameController.text.trim(),
          role: _selectedRole,
        );
      } else {
        success = await authProvider.signInWithEmail(email, password);
      }
      
      if (!mounted) return;
      if (success) {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyAuthError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildIabWarningBanner(ThemeData theme) {
    final iabName = BrowserUtils.detectedIabName ?? 'this browser';
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        borderRadius: AppTheme.radiusMd,
        padding: const EdgeInsets.all(16),
        opacity: theme.brightness == Brightness.dark ? 0.15 : 0.8,
        blur: 10,
        border: Border.all(
          color: AppColors.kidOrange.withValues(alpha: 0.3),
          width: 2,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.kidOrange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You're in $iabName",
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Built-in browsers like $iabName can be unstable. For the best experience and working Google login, please open TopScore in Chrome or Safari.",
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'https://app.topscoreapp.ai'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied! Open Chrome/Safari and paste to continue.'),
                      backgroundColor: AppColors.kidBlue,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text("Copy Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kidBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps auth exceptions to user-friendly messages
  String _friendlyAuthError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found') || msg.contains('no user record')) {
      return 'No account found with this email. Would you like to create one?';
    } else if (msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return 'Incorrect password. Please try again or reset your password.';
    } else if (msg.contains('email-already-in-use')) {
      return 'An account already exists with this email. Try signing in instead.';
    } else if (msg.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters with a mix of letters and numbers.';
    } else if (msg.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    } else if (msg.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
