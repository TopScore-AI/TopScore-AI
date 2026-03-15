import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/survey_model.dart';
import '../../constants/colors.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  double _rating = 0;
  final _favoriteController = TextEditingController();
  final _improvementController = TextEditingController();
  final _testimonialController = TextEditingController();
  bool _consent = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _favoriteController.dispose();
    _improvementController.dispose();
    _testimonialController.dispose();
    super.dispose();
  }

  Future<void> _submitSurvey() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide consent for the testimonial')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    final survey = SurveyResponse(
      id: '',
      userId: user?.uid ?? 'anonymous',
      userName: user?.displayName ?? 'Anonymous Student',
      rating: _rating,
      favoriteFeature: _favoriteController.text.trim(),
      improvementSuggestions: _improvementController.text.trim(),
      testimonial: _testimonialController.text.trim(),
      consentToPublicity: _consent,
      createdAt: DateTime.now(),
    );

    try {
      await FirestoreService().createSurveyResponse(survey);
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting survey: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thank You!'),
        content: const Text(
          'Your feedback helps us make TopScore AI better for everyone. Your testimonial might be featured on our landing page soon!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Pop dialog
              Navigator.of(context).pop(); // Go back from screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "User Experience Survey",
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "We'd love to hear from you!",
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your feedback helps us improve and inspire other students.",
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("How would you rate TopScore AI?"),
              const SizedBox(height: 12),
              _buildRatingBar(),
              const SizedBox(height: 32),

              _buildSectionTitle("What is your favorite feature?"),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _favoriteController,
                hint: "e.g., AI Tutor, Photo Scanner, Past Papers...",
                validator: (v) => v!.isEmpty ? 'This field is required' : null,
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("How can we improve for you?"),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _improvementController,
                hint: "Share your suggestions or missing features",
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              _buildSectionTitle("Write a short testimonial"),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _testimonialController,
                hint: "What do you love most about using TopScore AI?",
                maxLines: 4,
                validator: (v) => v!.isEmpty ? 'Please share your experience' : null,
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consent,
                    onChanged: (val) => setState(() => _consent = val!),
                    activeColor: AppColors.primaryBlue,
                  ),
                  Expanded(
                    child: Text(
                      "I agree to let TopScore AI use my testimonial and name on their website and promotional materials.",
                      style: GoogleFonts.nunito(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Submit Feedback",
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRatingBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          onPressed: () => setState(() => _rating = index + 1.0),
          icon: Icon(
            index < _rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 40,
          ),
        );
      }),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.nunito(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(color: Colors.grey),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
