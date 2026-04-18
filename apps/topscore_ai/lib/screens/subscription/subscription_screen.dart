import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/paystack_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_config.dart';
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

  // Stored in KES
  int _selectedAmount = 1000;
  int _selectedDays = 30;

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
        callbackUrl: AppConfig.paystackCallback,
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
              callbackUrl: AppConfig.paystackCallback,
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
              callbackUrl: AppConfig.paystackCallback,
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
      await auth.updateSubscription(_selectedDays);
      await auth.refreshUser();
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
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    const SizedBox(height: 8),
                    if (expiry != null) ...[
                      Text(
                        'Valid until ${DateFormat('dd MMM yyyy').format(expiry)}',
                        style: GoogleFonts.dmSans(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${expiry.difference(DateTime.now()).inDays} days remaining',
                        style: GoogleFonts.dmSans(
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

            if (!isSubscribed) ...[
              Text("Choose Plan", 
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              _buildPlanTile(
                title: "Weekly Access",
                price: "KES 300",
                days: 7,
                amount: 300,
                isSelected: _selectedAmount == 300,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildPlanTile(
                title: "Monthly Access",
                price: "KES 1,000",
                days: 30,
                amount: 1000,
                isSelected: _selectedAmount == 1000,
                theme: theme,
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
                onPressed: _isLoading ? null : _initiatePaystackPayment,
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.lock, color: Colors.white, size: 20),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Pay $_selectedAmount KES with Paystack',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09A5DB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '• Unlimited AI Tutor Sessions\n• High-Fidelity PDF Analysis\n• Expert Flashcards & Quizzes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security_rounded, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Secure payment via Paystack',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTile({
    required String title,
    required String price,
    required int days,
    required int amount,
    required bool isSelected,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: () => setState(() {
        _selectedAmount = amount;
        _selectedDays = days;
      }),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withValues(alpha: 0.1) : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(price, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 20, color: theme.primaryColor)),
                ],
              ),
            ),
            if (isSelected) 
              Icon(Icons.check_circle, color: theme.primaryColor)
            else
              const Icon(Icons.circle_outlined, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
