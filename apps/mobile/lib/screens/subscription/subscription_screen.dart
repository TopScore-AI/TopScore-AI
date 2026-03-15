import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/paystack_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';
import '../../config/api_config.dart';
import '../../services/recaptcha_service.dart';
import 'package:intl/intl.dart';
import 'paystack_checkout_screen.dart';
import '../../utils/responsive_layout.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PaystackService _paystackService = PaystackService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load and show reCAPTCHA on subscription page
    RecaptchaService.loadRecaptchaScript();
    RecaptchaService.showBadge();
  }

  @override
  void dispose() {
    // Hide reCAPTCHA badge when leaving subscription
    RecaptchaService.hideBadge();
    super.dispose();
  }

  // Selected Plan
  final int _selectedAmount = 1000; // KES 1,000

  Future<void> _initiatePaystackPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();

      // Guard: Prevent paying if already active
      if (auth.hasActiveSubscription) {
        _showAlreadyActiveAlert();
        return;
      }

      final user = auth.userModel;
      if (user == null) throw Exception("User not logged in");

      final result = await _paystackService.initializeTransaction(
        userId: user.uid,
        email:
            user.email.isNotEmpty ? user.email : "${user.uid}@topscoreapp.ai",
        amount: _selectedAmount * 100, // Backend expects cents
        callbackUrl:
            kIsWeb ? null : '${ApiConfig.paystackCallback}?client=mobile',
      );

      if (!mounted) return;

      if (kIsWeb) {
        // Web: open in a new tab and show manual verify dialog
        if (await canLaunchUrl(Uri.parse(result.authorizationUrl))) {
          await launchUrl(Uri.parse(result.authorizationUrl),
              mode: LaunchMode.platformDefault);
          if (mounted) _showVerifyDialog(result.reference);
        } else {
          throw Exception("Could not launch checkout URL");
        }
      } else {
        // Mobile: open in-app WebView checkout
        final checkoutResult = await Navigator.push<PaystackCheckoutResult>(
          context,
          MaterialPageRoute(
            builder: (_) => PaystackCheckoutScreen(
              authorizationUrl: result.authorizationUrl,
              reference: result.reference,
              callbackUrl: ApiConfig.paystackCallback,
            ),
          ),
        );

        if (!mounted) return;
        _handleCheckoutResult(checkoutResult);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckoutResult(PaystackCheckoutResult? result) async {
    if (result == null || result.error == 'cancelled') return;

    if (result.success && result.verifyResult != null) {
      await _activateSubscription();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error ?? 'Payment was not completed. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVerifyDialog(String reference) {
    showAdaptiveDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: const Text('Did you complete the payment on Paystack?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _verifyPayment(reference);
            },
            child: const Text('Yes, Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPayment(String reference) async {
    setState(() => _isLoading = true);
    try {
      final result = await _paystackService.verifyTransaction(reference);
      if (result.isSuccess) {
        await _activateSubscription();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Payment status: ${result.status}. If you paid, please contact support.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Activates the user's premium subscription after successful payment.
  ///
  /// 1. Updates Firestore and local UserModel via AuthProvider
  /// 2. Refreshes the Firebase ID token to pick up custom claims
  ///    set by the backend webhook (plan: 'premium')
  /// 3. Shows success feedback and pops back
  Future<void> _activateSubscription() async {
    try {
      final auth = context.read<AuthProvider>();

      // 1. Update Firestore + local model (30-day subscription)
      await auth.updateSubscription(30);

      // 2. Force-refresh the Firebase ID token so custom claims
      //    (set by the Paystack webhook) are available immediately
      await SubscriptionService().refreshSubscriptionStatus();
    } catch (e) {
      debugPrint('Subscription activation warning: $e');
      // Non-fatal — the webhook already updated the backend.
      // The next token refresh will pick up the claims.
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment Verified! Welcome to Premium.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showAlreadyActiveAlert() {
    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Subscription'),
        content: const Text(
          'You already have an active Premium subscription. '
          'You can only renew once your current subscription expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Upgrade to Premium',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: CenterContent(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTheme.buildGlassContainer(
              context,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.star, size: 48, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    'Monthly Access',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'KES 1,000 / month',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('• Unlimited tool calling'),
                  const Text('• Web search'),
                  const Text('• Image Upload'),
                  const Text('• Graph Generation'),
                  const Text('• Standard document chat'),
                  const SizedBox(height: 20),
                  _buildSubscriptionStatus(auth),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Paystack Payment Button
            ElevatedButton.icon(
              onPressed: (_isLoading || auth.hasActiveSubscription)
                  ? null
                  : _initiatePaystackPayment,
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : Icon(
                      auth.hasActiveSubscription
                          ? Icons.check_circle
                          : Icons.lock,
                      color: Colors.white,
                      size: 20,
                    ),
              label: _isLoading
                  ? _buildLoading()
                  : Text(
                      auth.hasActiveSubscription
                          ? 'Subscription Active'
                          : 'Pay Securely with Paystack',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: auth.hasActiveSubscription
                    ? Colors.green
                    : const Color(0xFF09A5DB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Accepted methods
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.credit_card,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  'Card  •  M-Pesa  •  Bank Transfer',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Your subscription will be activated immediately after payment is confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatus(AuthProvider auth) {
    if (!auth.hasActiveSubscription ||
        auth.userModel?.subscriptionExpiry == null) {
      return const SizedBox.shrink();
    }

    final expiry = auth.userModel!.subscriptionExpiry!;
    final formattedDate = DateFormat('MMM dd, yyyy').format(expiry);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
            'Premium until $formattedDate',
            style: GoogleFonts.nunito(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator.adaptive(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        strokeWidth: 2,
      ),
    );
  }
}
