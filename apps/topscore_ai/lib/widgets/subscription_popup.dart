import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/paystack_service.dart';
import '../constants/colors.dart';
import '../screens/subscription/paystack_checkout_screen.dart';
import '../screens/subscription/paystack_web_checkout_bridge.dart';
import '../config/app_config.dart';

class SubscriptionPopup extends StatefulWidget {
  const SubscriptionPopup({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SubscriptionPopup(),
    );
  }

  @override
  State<SubscriptionPopup> createState() => _SubscriptionPopupState();
}

class _SubscriptionPopupState extends State<SubscriptionPopup> {
  final PaystackService _paystackService = PaystackService();
  bool _isMonthly = true;
  bool _isLoading = false;

  Future<void> _initiatePayment() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userModel;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final amount = _isMonthly ? 1000 : 300;
      final planName = _isMonthly ? 'Monthly Premium' : 'Weekly Premium';

      final result = await _paystackService.initializeTransaction(
        userId: user.uid,
        email: user.email,
        amount: amount * 100, // Kobo
        planName: planName,
        // callbackUrl removed for secure backend handling
      );

      if (!mounted) return;

      dynamic checkoutResult;

      if (kIsWeb) {
        checkoutResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaystackWebCheckout(
              authorizationUrl: result.authorizationUrl,
              reference: result.reference,
              callbackUrl: '${AppConfig.backendBaseUrl}/paystack/callback',
            ),
          ),
        );
      } else {
        checkoutResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaystackCheckoutScreen(
              authorizationUrl: result.authorizationUrl,
              reference: result.reference,
            ),
          ),
        );
      }

      if (checkoutResult != null && checkoutResult is PaystackCheckoutResult && checkoutResult.success) {
        if (mounted) {
           await authProvider.refreshUser();
           if (!mounted) return;
           Navigator.pop(context); // Close popup on success
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Welcome to Premium! 🚀'), backgroundColor: AppColors.success),
           );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 400),
         child: Container(
           padding: const EdgeInsets.all(24),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               // Header
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const SizedBox(width: 24),
                   IconButton(
                     onPressed: () => Navigator.pop(context),
                     icon: const Icon(CupertinoIcons.xmark, color: Colors.black45, size: 20),
                   ),
                 ],
               ),
               
               Icon(CupertinoIcons.star_circle_fill, size: 64, color: AppColors.primary),
               const SizedBox(height: 16),
               Text(
                 "Upgrade to Premium",
                 style: GoogleFonts.plusJakartaSans(
                   fontSize: 24,
                   fontWeight: FontWeight.bold,
                   color: AppColors.text,
                 ),
               ),
               const SizedBox(height: 8),
               Text(
                 "You've reached your free daily limit. Upgrade now for unlimited access to your AI Tutor and resources.",
                 textAlign: TextAlign.center,
                 style: GoogleFonts.plusJakartaSans(
                   fontSize: 14,
                   color: AppColors.textSecondary,
                 ),
               ),
               
               const SizedBox(height: 24),
               
               // Plan Selection
               _buildPlanOption(
                 title: "Weekly Access",
                 price: "KES 300",
                 subtitle: "/week",
                 isSelected: !_isMonthly,
                 onTap: () => setState(() => _isMonthly = false),
               ),
               const SizedBox(height: 12),
               _buildPlanOption(
                 title: "Monthly Full Access",
                 price: "KES 1,000",
                 subtitle: "/month",
                 isSelected: _isMonthly,
                 badge: "BEST VALUE",
                 onTap: () => setState(() => _isMonthly = true),
               ),
               
               const SizedBox(height: 24),
               
               // Benefits
               _buildBenefit("Unlimited AI Tutor & Conversations"),
               _buildBenefit("Full CBC, 8-4-4 & IGCSE Library"),
               _buildBenefit("AI Composition & Insha Grading"),
               _buildBenefit("Offline Study Mode Across Devices"),
               
               const SizedBox(height: 32),
               
               // Upgrade Button
               SizedBox(
                 width: double.infinity,
                 height: 54,
                 child: ElevatedButton(
                   onPressed: _isLoading ? null : _initiatePayment,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.primary,
                     foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     elevation: 0,
                   ),
                   child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        "Upgrade Now",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                 ),
               ),
               
               const SizedBox(height: 16),
               Text(
                 "Secure payment via Paystack",
                 style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textLight),
               ),
             ],
           ),
         ),
       ),
    );
  }

  Widget _buildPlanOption({
    required String title,
    required String price,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 2,
          ),
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: isSelected ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(CupertinoIcons.checkmark_seal_fill, color: AppColors.success, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
