import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/app_spinner.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoggedIn = authProvider.isAuthenticated;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(
          "Account Deletion",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.text,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : AppColors.text,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(isDark),
            const SizedBox(height: 40),
            _buildSection(
              isDark,
              "How to Delete Your Account",
              "At TopScore AI, we respect your privacy and provide a simple way to delete your account and all associated data.",
            ),
            _buildSteps(isDark, isLoggedIn),
            const SizedBox(height: 32),
            _buildSection(
              isDark,
              "What Data is Deleted?",
              "When you delete your account, the following data is permanently removed from our systems:\n\n"
                  "• Your profile information (name, email, school, grade)\n"
                  "• Your complete study history and learning progress\n"
                  "• All uploaded documents and generated study materials\n"
                  "• AI Tutor chat history and personalized insights",
            ),
            _buildSection(
              isDark,
              "Data Retention & Exceptions",
              "• Permanent Erasure: Your data will be permanently erased from our active databases within 30 days of your request.\n"
                  "• Backups: Residual data may remain in our encrypted secure backups for up to 90 days before being overwritten.\n"
                  "• Legal Obligations: We may retain certain transaction records (e.g., M-Pesa references) as required by Kenyan tax and financial laws.\n"
                  "• Anonymized Data: We may keep anonymized usage data for research and platform improvement, but this data will not be linked to you.",
            ),
            const SizedBox(height: 16),
            if (isLoggedIn)
              _buildDeleteButton(context, authProvider, isDark)
            else
              _buildSignInPrompt(context, isDark),
            const SizedBox(height: 40),
            _buildContactInfo(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.delete_forever_rounded,
          size: 64,
          color: AppColors.error,
        ),
      ),
    );
  }

  Widget _buildSection(bool isDark, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(bool isDark, bool isLoggedIn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepRow(isDark, "1", "Sign in to your TopScore AI account."),
          const SizedBox(height: 16),
          _buildStepRow(isDark, "2", "Go to your Profile settings."),
          const SizedBox(height: 16),
          _buildStepRow(isDark, "3", "Tap the 'Delete Account' button at the bottom."),
          const SizedBox(height: 16),
          _buildStepRow(isDark, "4", "Confirm your request in the security dialog."),
        ],
      ),
    );
  }

  Widget _buildStepRow(bool isDark, String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.topscoreBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(
      BuildContext context, AuthProvider authProvider, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isDeleting ? null : () => _confirmDeletion(context, authProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isDeleting
            ? const AppSpinner(color: Colors.white, strokeWidth: 2)
            : Text(
                "Permanently Delete My Account",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.topscoreBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            "To verify your identity and protect your data, please sign in to request deletion.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.topscoreBlue,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.topscoreBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Sign In to Delete"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(bool isDark) {
    return Center(
      child: Column(
        children: [
          Text(
            "Cannot access your account?",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Email support@topscoreapp.ai",
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.topscoreBlue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(
      BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This action is permanent and cannot be undone. "
          "All your study history, files, and progress will be lost forever.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      try {
        await authProvider.deleteAccount();
        messenger.showSnackBar(
          const SnackBar(content: Text("Account deleted successfully.")),
        );
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("Error deleting account: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }
}
