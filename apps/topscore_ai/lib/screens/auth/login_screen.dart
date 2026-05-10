import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../services/offline_service.dart';
import '../../widgets/app_spinner.dart';

class LoginScreen extends StatefulWidget {
  final bool isRegister;
  const LoginScreen({super.key, this.isRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  late bool _isRegister;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _isLinkSent = false;
  bool _showClassicLogin = false;
  bool _agreedToTerms = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.isRegister;
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    // Check for a pending email link (cross-device / cold-start from email)
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkPendingEmailLink());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoading = Provider.of<AuthProvider>(context).isLoading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _buildCenteredLayout(theme, isDark, isLoading),
      ),
    );
  }

  // ── Centered layout (unified for all screens) ──────────────────────────────
  Widget _buildCenteredLayout(ThemeData theme, bool isDark, bool isLoading) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simplified Logo
            Hero(
              tag: 'app_logo',
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4)),
                        ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child:
                    Image.asset('assets/images/logo.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 32),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildFormPanel(theme, isDark, isLoading),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form panel ─────────────────────────────────────────────────────────────
  Widget _buildFormPanel(ThemeData theme, bool isDark, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                _isRegister ? 'Create account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                _isRegister
                    ? 'Start your learning journey today'
                    : 'Sign in to continue learning',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: theme.hintColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Terms of Service Checkbox (only for registration)
        if (_isRegister) ...[
          _buildTermsCheckbox(theme),
          const SizedBox(height: 16),
        ],

        // Google button
        _buildGoogleButton(context, theme, isLoading),
        const SizedBox(height: 20),

        // Divider
        Row(children: [
          Expanded(
              child: Divider(color: theme.dividerColor.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or',
                style: GoogleFonts.inter(fontSize: 12, color: theme.hintColor)),
          ),
          Expanded(
              child: Divider(color: theme.dividerColor.withValues(alpha: 0.3))),
        ]),
        const SizedBox(height: 20),

        // Magic link / email-password
        if (!_isRegister) _buildMagicLinkSection(context, theme, isLoading),
        if (_isRegister) _buildEmailPasswordForm(context, theme, isLoading),

        // Classic login toggle
        if (!_isRegister) ...[
          const SizedBox(height: 12),
          _buildClassicLoginToggle(theme),
          if (_showClassicLogin) ...[
            const SizedBox(height: 16),
            _buildEmailPasswordForm(context, theme, isLoading),
          ],
        ],

        const SizedBox(height: 28),

        // Switch register/login
        Center(
          child: TextButton(
            onPressed: isLoading
                ? null
                : () => setState(() {
                      _isRegister = !_isRegister;
                      _confirmPasswordController.clear();
                      _nameController.clear();
                      _isLinkSent = false;
                      _showClassicLogin = false;
                    }),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: theme.hintColor),
                children: [
                  TextSpan(
                      text: _isRegister
                          ? 'Already have an account? '
                          : "Don't have an account? "),
                  TextSpan(
                    text: _isRegister ? 'Sign in' : 'Create one',
                    style: TextStyle(
                        color: AppColors.topscoreBlue,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Google button ──────────────────────────────────────────────────────────
  Widget _buildGoogleButton(
      BuildContext context, ThemeData theme, bool isLoading) {
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading
            ? null
            : () async {
                if (!_checkTerms()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await Provider.of<AuthProvider>(context, listen: false)
                      .signInWithGoogle();
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('Sign in failed: $e'),
                        backgroundColor: AppColors.error),
                  );
                }
              },
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isDark ? AppColors.surfaceElevatedDark : Colors.white,
          side: BorderSide(
              color: theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20, child: AppSpinner(strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset('assets/images/google_logo.png',
                    height: 20,
                    width: 20,
                    errorBuilder: (_, __, ___) => const FaIcon(
                        FontAwesomeIcons.google,
                        size: 18,
                        color: Colors.red)),
                const SizedBox(width: 12),
                Text('Continue with Google',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface)),
              ]),
      ),
    );
  }

  // ── Magic link ─────────────────────────────────────────────────────────────
  Widget _buildMagicLinkSection(
      BuildContext context, ThemeData theme, bool isLoading) {
    if (_isLinkSent) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          const Icon(Icons.mark_email_read_rounded,
              color: Colors.green, size: 36),
          const SizedBox(height: 12),
          Text('Check your inbox!',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.green.shade700)),
          const SizedBox(height: 6),
          Text('We sent a sign-in link to\n${_emailController.text}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.green.shade600, height: 1.5)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _isLinkSent = false),
            child: Text('Use a different email',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.topscoreBlue)),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Enter your email',
          hintStyle: GoogleFonts.inter(fontSize: 14),
          prefixIcon: const Icon(Icons.email_outlined, size: 20),
          suffixIcon: IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 18, height: 18, child: AppSpinner(strokeWidth: 2))
                : const Icon(Icons.send_rounded,
                    size: 20, color: AppColors.topscoreBlue),
            onPressed: isLoading ? null : _handleMagicLink,
          ),
          filled: true,
          fillColor: theme.dividerColor.withValues(alpha: 0.06),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.topscoreBlue, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      const SizedBox(height: 8),
      Text('No password needed — we\'ll email you a secure sign-in link.',
          style: GoogleFonts.inter(fontSize: 12, color: theme.hintColor),
          textAlign: TextAlign.center),
    ]);
  }

  Widget _buildClassicLoginToggle(ThemeData theme) {
    return Center(
      child: TextButton.icon(
        onPressed: () => setState(() => _showClassicLogin = !_showClassicLogin),
        icon: Icon(
            _showClassicLogin
                ? Icons.keyboard_arrow_up_rounded
                : Icons.lock_outline_rounded,
            size: 16,
            color: theme.hintColor),
        label: Text(
          _showClassicLogin
              ? 'Hide password login'
              : 'Sign in with password instead',
          style: GoogleFonts.inter(fontSize: 13, color: theme.hintColor),
        ),
      ),
    );
  }

  Future<void> _checkPendingEmailLink() async {
    final pendingLink =
        OfflineService().getStringList('pending_email_link').firstOrNull;
    if (pendingLink == null || pendingLink.isEmpty) return;

    // We have a pending link but no email — show a dialog asking for it
    if (!mounted) return;
    final email = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Confirm your email'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Enter the email address you used to request the sign-in link.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'your@email.com'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Sign in'),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await OfflineService().setStringList('signin_email', [email]);
      await auth.handleAuthLink(pendingLink);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Sign-in failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email first')));
      return;
    }
    if (!_checkTerms()) return;
    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .sendLoginLink(email);
      setState(() => _isLinkSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to send link: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ── Email / password form ──────────────────────────────────────────────────
  Widget _buildEmailPasswordForm(
      BuildContext context, ThemeData theme, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!_showClassicLogin && !_isRegister) ...[
          const SizedBox(height: 4),
          Text('Password sign-in',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.hintColor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
        ],
        if (_isRegister) ...[
          _inputField(
              controller: _nameController,
              label: 'Full name',
              icon: Icons.person_outline,
              theme: theme,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Name is required' : null),
          const SizedBox(height: 12),
        ],
        _inputField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            theme: theme,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Email is required';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())) {
                return 'Enter a valid email';
              }
              return null;
            }),
        const SizedBox(height: 12),
        _inputField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          theme: theme,
          obscure: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onChanged: _isRegister ? (_) => setState(() {}) : null,
          validator: (v) {
            if ((v?.length ?? 0) < 6) return 'At least 6 characters';
            if (_isRegister && _getPasswordStrength(v!) < 2) {
              return 'Too weak — add numbers or symbols';
            }
            return null;
          },
        ),
        if (_isRegister && _passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildPasswordStrengthIndicator(theme),
        ],
        if (_isRegister) ...[
          const SizedBox(height: 12),
          _inputField(
            controller: _confirmPasswordController,
            label: 'Confirm password',
            icon: Icons.lock_outline,
            theme: theme,
            obscure: _obscureConfirmPassword,
            onToggleObscure: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword),
            validator: (v) =>
                v != _passwordController.text ? 'Passwords do not match' : null,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (isLoading || _isSubmitting) ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.topscoreBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppSpinner(strokeWidth: 2, color: Colors.white))
                : Text(_isRegister ? 'Create account' : 'Sign in',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        if (!_isRegister) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed:
                  isLoading ? null : () => context.push('/forgot-password'),
              child: Text('Forgot password?',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: theme.hintColor)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13),
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: theme.dividerColor.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.topscoreBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  // ── Password strength ──────────────────────────────────────────────────────
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
      Colors.green
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Row(
          children: List.generate(
              4,
              (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: i < strength
                            ? colors[strength]
                            : theme.dividerColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ))),
      const SizedBox(height: 4),
      Text(labels[strength],
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11,
              color: colors[strength],
              fontWeight: FontWeight.w500)),
    ]);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_checkTerms()) return;
    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_isRegister) {
        await auth.signUpWithEmail(email, password,
            displayName: _nameController.text.trim());
      } else {
        await auth.signInWithEmail(email, password);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_friendlyAuthError(e)),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyAuthError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found') || msg.contains('no user record')) {
      return 'No account found. Want to create one?';
    }
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Incorrect password. Try again or reset it.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'Account already exists. Try signing in.';
    }
    if (msg.contains('weak-password')) {
      return 'Password too weak. Add numbers or symbols.';
    }
    if (msg.contains('invalid-email')) {
      return 'Enter a valid email address.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Wait a moment and retry.';
    }
    if (msg.contains('network')) {
      return 'Network error. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  bool _checkTerms() {
    // Only check terms agreement when registering
    if (_isRegister && !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Privacy Policy to proceed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return true;
  }

  Widget _buildTermsCheckbox(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
            activeColor: AppColors.topscoreBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: AppColors.topscoreBlue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _launchUrl('https://topscoreapp.ai/terms'),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: AppColors.topscoreBlue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _launchUrl('https://topscoreapp.ai/privacy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
