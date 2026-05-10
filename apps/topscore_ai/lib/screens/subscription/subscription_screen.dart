import '../../constants/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/paystack_service.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_config.dart';
import 'paystack_checkout_screen.dart';
import '../../widgets/app_spinner.dart';
import 'paystack_web_checkout_bridge.dart';

// ─── Plan definition ────────────────────────────────────────────────────────

class _Plan {
  final String id;
  final String title;
  final String price;
  final String period;
  final String badge;
  final int amount; // KES
  final int days;
  final bool isPopular;

  const _Plan({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.badge,
    required this.amount,
    required this.days,
    this.isPopular = false,
  });
}

const _plans = [
  _Plan(
    id: 'weekly',
    title: 'Weekly',
    price: 'KES 300',
    period: '/ week',
    badge: 'Try it out',
    amount: 300,
    days: 7,
  ),
  _Plan(
    id: 'monthly',
    title: 'Monthly',
    price: 'KES 1,000',
    period: '/ month',
    badge: 'Best value',
    amount: 1000,
    days: 30,
    isPopular: true,
  ),
  _Plan(
    id: 'termly',
    title: 'Termly',
    price: 'KES 2,500',
    period: '/ term',
    badge: 'Save 17%',
    amount: 2500,
    days: 90,
  ),
];

const _features = [
  (
    icon: CupertinoIcons.chat_bubble_2_fill,
    label: 'Unlimited AI Tutor sessions'
  ),
  (icon: CupertinoIcons.doc_text_fill, label: 'Full PDF analysis & summaries'),
  (
    icon: CupertinoIcons.rectangle_on_rectangle_angled,
    label: 'Unlimited flashcard sets'
  ),
  (
    icon: CupertinoIcons.checkmark_seal_fill,
    label: 'Unlimited quiz generation'
  ),
  (icon: CupertinoIcons.waveform, label: 'Live voice AI tutor'),
  (icon: CupertinoIcons.person_3_fill, label: 'Group study sessions'),
  (icon: CupertinoIcons.star_fill, label: 'Priority support'),
];

// ─── Screen ─────────────────────────────────────────────────────────────────

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PaystackService _paystackService = PaystackService();
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedPlanId = 'monthly';
  bool _awaitingActivation = false;
  DateTime? _expiryAtPurchaseStart;
  bool _autoClosed = false;

  _Plan get _selectedPlan => _plans.firstWhere((p) => p.id == _selectedPlanId);

  Future<void> _initiatePaystackPayment() async {
    final auth = context.read<AuthProvider>();

    // 1. If already subscribed, show the 'Already Subscribed' popup
    // unless they've already seen it or we want to allow extension after confirmation.
    if (auth.hasActiveSubscription) {
      final shouldProceed = await _showAlreadySubscribedPopup();
      if (shouldProceed != true) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _awaitingActivation = true;
      _expiryAtPurchaseStart = auth.userModel?.subscriptionExpiry;
      _autoClosed = false;
    });

    try {
      final user = auth.userModel;
      if (user == null) throw Exception('Please sign in to continue.');

      final plan = _selectedPlan;

      final result = await _paystackService.initializeTransaction(
        userId: user.uid,
        email:
            user.email.isNotEmpty ? user.email : '${user.uid}@topscoreapp.ai',
        amount: plan.amount * 100, // KES → kobo (Paystack smallest unit)
        planName: 'TopScore Premium – ${plan.title}',
        callbackUrl: AppConfig.paystackCallback,
      );

      if (!mounted) return;

      if (kIsWeb) {
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
          await _activateSubscription(plan);
        } else if (verifyResult != null) {
          setState(() {
            _errorMessage =
                'Payment status: ${verifyResult.status}. If you paid, contact support.';
            _awaitingActivation = false;
          });
        } else {
          setState(() => _awaitingActivation = false);
        }
      } else {
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
          setState(() => _awaitingActivation = false);
          return;
        }
        if (checkoutResult.success) {
          await _activateSubscription(plan);
        } else {
          setState(() {
            _errorMessage = checkoutResult.error ??
                'Payment was not completed. Please try again.';
            _awaitingActivation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _awaitingActivation = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _activateSubscription(_Plan plan) async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.updateSubscription(plan.days);
      await auth.refreshUser();
      await SubscriptionService().refreshSubscriptionStatus();
    } catch (e) {
      if (kDebugMode) debugPrint('Subscription activation warning: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Welcome to Premium! ${plan.title} plan activated.',
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _maybeAutoClose(AuthProvider auth) {
    if (_autoClosed || !_awaitingActivation) return;
    final isSubscribed = auth.hasActiveSubscription;
    final newExpiry = auth.userModel?.subscriptionExpiry;
    final extended = _expiryAtPurchaseStart != null &&
        newExpiry != null &&
        newExpiry.isAfter(_expiryAtPurchaseStart!);
    if (!isSubscribed && !extended) return;
    _autoClosed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  Future<bool?> _showAlreadySubscribedPopup() async {
    final auth = context.read<AuthProvider>();
    final expiry = auth.userModel?.subscriptionExpiry;
    final expiryStr =
        expiry != null ? DateFormat('MMMM dd, yyyy').format(expiry) : 'N/A';

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.star_fill,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                "Already Subscribed!",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You currently have an active Premium subscription until $expiryStr.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, true), // Proceed with extension
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Extend Anyway",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false), // Cancel
                  child: Text(
                    "Keep Current Plan",
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final isSubscribed = auth.hasActiveSubscription;
    final expiry = auth.userModel?.subscriptionExpiry;
    _maybeAutoClose(auth);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isSubscribed ? 'Your Subscription' : 'Go Premium',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: isSubscribed
          ? _buildActiveState(context, theme, isDark, expiry)
          : _buildUpgradeState(context, theme, isDark),
    );
  }

  // ── Active subscription view ───────────────────────────────────────────────

  Widget _buildActiveState(
      BuildContext context, ThemeData theme, bool isDark, DateTime? expiry) {
    final daysLeft = expiry?.difference(DateTime.now()).inDays ?? 0;
    final isExpiringSoon = daysLeft <= 5;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Premium Active',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (expiry != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Valid until ${DateFormat('dd MMM yyyy').format(expiry)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isExpiringSoon
                          ? '⚠️  Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}'
                          : '$daysLeft days remaining',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Features you have
          Text(
            'YOUR BENEFITS',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          ..._features.map((f) => _FeatureRow(
                icon: f.icon,
                label: f.label,
                theme: theme,
              )),

          const SizedBox(height: 32),

          // Renew / extend option
          if (expiry != null && daysLeft <= 10) ...[
            _buildRenewBanner(theme, isDark, daysLeft),
            const SizedBox(height: 32),
          ],

          // Renew button always available
          OutlinedButton.icon(
            onPressed: () => setState(() {}), // scroll to plans
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Extend Subscription'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: theme.primaryColor),
              foregroundColor: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 48),

          // Plan selector for renewal
          Text(
            'RENEW / EXTEND',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          ..._plans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlanTile(
                  plan: plan,
                  isSelected: _selectedPlanId == plan.id,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                  theme: theme,
                  isDark: isDark,
                ),
              )),
          const SizedBox(height: 24),
          _buildPayButton(theme),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildRenewBanner(ThemeData theme, bool isDark, int daysLeft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your subscription expires in $daysLeft day${daysLeft == 1 ? '' : 's'}. Renew now to keep uninterrupted access.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Upgrade view ───────────────────────────────────────────────────────────

  Widget _buildUpgradeState(
      BuildContext context, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero gradient header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unlock Your Full Potential',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Get unlimited access to every feature — AI tutor, quizzes, flashcards, and more.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Features list
                Text(
                  'EVERYTHING INCLUDED',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                ..._features.map((f) => _FeatureRow(
                      icon: f.icon,
                      label: f.label,
                      theme: theme,
                    )),

                const SizedBox(height: 32),

                // Plan selector
                Text(
                  'CHOOSE YOUR PLAN',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                ..._plans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlanTile(
                        plan: plan,
                        isSelected: _selectedPlanId == plan.id,
                        onTap: () => setState(() => _selectedPlanId = plan.id),
                        theme: theme,
                        isDark: isDark,
                      ),
                    )),

                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.dmSans(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Pay button
                _buildPayButton(theme),

                const SizedBox(height: 16),

                // Trust signals
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Text(
                      'Secure payment via Paystack · Cancel anytime',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton(ThemeData theme) {
    final plan = _selectedPlan;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _initiatePaystackPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: AppSpinner(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Pay ${plan.price} · ${plan.title}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Reusable widgets ────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Icon(Icons.check_circle_rounded,
              size: 18, color: Colors.green.shade400),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isDark;

  const _PlanTile({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.07)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.primaryColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  width: 2,
                ),
                color: isSelected ? theme.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: plan.isPopular
                              ? theme.primaryColor
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          plan.badge,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: plan.isPopular
                                ? Colors.white
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.days} days access',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.price,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: isSelected
                        ? theme.primaryColor
                        : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  plan.period,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
