import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/paystack_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';
import '../../config/api_config.dart';
import 'paystack_checkout_screen.dart';
import 'paystack_web_checkout_bridge.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PaystackService _paystackService = PaystackService();
  bool _isLoading = false;
  String? _errorMessage;

  // Stored in KES; multiplied x100 when sent to Paystack (kobo)
  final int _selectedAmount = 1000;

  Future<void> _initiatePaystackPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final user = auth.userModel;
      if (user == null) throw Exception('User not logged in');

      final result = await _paystackService.initializeTransaction(
        userId: user.uid,
        email:
            user.email.isNotEmpty ? user.email : '${user.uid}@topscoreapp.ai',
        amount: _selectedAmount * 100, // KES -> kobo
        callbackUrl: ApiConfig.paystackCallback,
      );

      if (!mounted) return;

      if (kIsWeb) {
        // Web: in-app iframe checkout
        final verifyResult = await Navigator.push<PaystackVerifyResult>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PaystackWebCheckout(
              authorizationUrl: result.authorizationUrl,
              reference: result.reference,
              callbackUrl: ApiConfig.paystackCallback,
            ),
          ),
        );
        if (!mounted) return;
        if (verifyResult != null && verifyResult.isSuccess) {
          await _activateSubscription();
        } else if (verifyResult != null) {
          setState(() => _errorMessage =
              'Payment status: ${verifyResult.status}. If you paid, contact support.');
        }
      } else {
        // Mobile: in-app WebView checkout
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
        if (checkoutResult == null || checkoutResult.error == 'cancelled') {
          return;
        }
        if (checkoutResult.success) {
          await _activateSubscription();
        } else {
          setState(() => _errorMessage = checkoutResult.error ??
              'Payment was not completed. Please try again.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _activateSubscription() async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.updateSubscription(30);
      // Re-read from Firestore to ensure local model is fully in sync
      await auth.refreshUser();
      // Force-refresh JWT token so claims reflect new plan
      await SubscriptionService().refreshSubscriptionStatus();
    } catch (e) {
      if (kDebugMode) debugPrint('Subscription activation warning: $e');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final isSubscribed = auth.hasActiveSubscription;
    final expiry = auth.userModel?.subscriptionExpiry;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSubscribed ? 'Your Subscription' : 'Upgrade to Premium',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Active subscription banner
            if (isSubscribed) ...[
              AppTheme.buildGlassContainer(
                context,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.check, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text('Premium Active',
                        style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    const SizedBox(height: 8),
                    if (expiry != null) ...[
                      Text(
                        'Valid until ${DateFormat('dd MMM yyyy').format(expiry)}',
                        style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${expiry.difference(DateTime.now()).inDays} days remaining',
                        style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                expiry.difference(DateTime.now()).inDays <= 3
                                    ? Colors.orange
                                    : Colors.green),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            AppTheme.buildGlassContainer(
              context,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.star, size: 48, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text('Monthly Access',
                      style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Text('KES 1,000 / month',
                      style: GoogleFonts.nunito(
                          fontSize: 18,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  const Text('\u2022 Unlimited tool calling'),
                  const Text('\u2022 Web search'),
                  const Text('\u2022 Image Upload'),
                  const Text('\u2022 Graph Generation'),
                  const Text('\u2022 Standard document chat'),
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
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed:
                  (isSubscribed || _isLoading) ? null : _initiatePaystackPayment,
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : Icon(
                      isSubscribed ? Icons.check_circle : Icons.lock,
                      color: Colors.white,
                      size: 20),
              label: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      isSubscribed
                          ? 'Already Subscribed'
                          : 'Pay Securely with Paystack',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSubscribed ? Colors.grey : const Color(0xFF09A5DB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            if (!isSubscribed) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card,
                      size: 20,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text('Card  \u2022  M-Pesa  \u2022  Bank Transfer',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Your subscription will be activated immediately after payment is confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
