import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/referral_service.dart';
import '../../config/app_theme.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  final ReferralService _referralService = ReferralService();
  bool _isRedeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isRedeeming = true);
    final success = await _referralService.redeemCode(code);
    setState(() => _isRedeeming = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Awesome! Referral bonus applied.'),
            backgroundColor: Colors.green,
          ),
        );
        _codeController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or already used referral code.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _shareReferral(String? code) {
    if (code == null || code.isEmpty) return;
    final text = "Join me on TopScore AI! Use my code $code to unlock a 3-day Premium trial and 500 bonus XP. Download here: https://topscoreapp.ai/download";
    SharePlus.instance.share(ShareParams(text: text));
  }

  void _copyCode(String? code) {
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied to clipboard!'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Refer & Earn', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // --- ILLUSTRATION ---
            Icon(Icons.card_giftcard_rounded, size: 80, color: AppColors.primary)
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 2.seconds)
                .shake(hz: 2, curve: Curves.easeInOut),
            const SizedBox(height: 24),

            Text(
              "Gift TopScore to Friends",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Invite your classmates to TopScore AI. When they join using your code, both of you get Premium access!",
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // --- YOUR CODE ---
            _sectionLabel('Your Referral Code'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      user?.referralCode ?? "GEN-REF-CODE",
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                    onPressed: () => _copyCode(user?.referralCode),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                    onPressed: () => _shareReferral(user?.referralCode),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

            const SizedBox(height: 40),

            // --- REDEEM CODE ---
            _sectionLabel('Have a code?'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'Enter friend\'s code',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRedeeming ? null : _redeemCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: _isRedeeming
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text('Redeem', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // --- REWARDS SUMMARY ---
            AppTheme.buildGlassContainer(
              context,
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  _rewardStat("Referrals", "${user?.referralCount ?? 0}"),
                  Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
                  _rewardStat("XP Earned", "${(user?.referralCount ?? 0) * 100}"),
                  Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
                  _rewardStat("Premium", "${(user?.referralCount ?? 0) * 3} Days"),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _rewardStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
