import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_service.dart';
import '../../constants/colors.dart';
import '../../utils/curriculum_utils.dart';

/// Streamlined, single-step onboarding to capture explicit profile data
/// (Curriculum & Grade) for the FastAPI Hybrid Architecture.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Hybrid Architecture State: Explicit Profile Boundaries
  String? _selectedCurriculum;
  String? _selectedGrade;

  final List<String> _curriculums = CurriculumData.getCurriculums();

  // Dynamic grades based on the exact 2026 Kenyan education timeline
  List<String> get _availableGrades {
    if (_selectedCurriculum == null) return [];
    return CurriculumData.getGradesForCurriculum(_selectedCurriculum!);
  }

  Future<void> _finishSetup() async {
    if (_selectedCurriculum == null || _selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select both your curriculum and level to continue.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Save to OfflineService for local persistence
    final offline = OfflineService();
    await offline
        .setStringList('user_profile', [_selectedCurriculum!, _selectedGrade!]);
    await offline.setStringList('onboarding_complete', ['true']);

    // Sync to AuthProvider + Firestore so the router's
    // isProfileComplete (grade != null) guard passes
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.updateUserRole(
        role: 'student',
        grade: _selectedGrade!,
        schoolName: '',
        curriculum: _selectedCurriculum,
      );
    }

    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    // Force chip colors based on theme
    final chipThemeOverride = Theme.of(context).copyWith(
      chipTheme: ChipThemeData(
        backgroundColor: textColor.withValues(alpha: 0.15),
        selectedColor: textColor,
        labelStyle: TextStyle(color: textColor),
        secondaryLabelStyle: TextStyle(color: AppColors.edupoaBlue),
        disabledColor: textColor.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
      ),
    );

    return Theme(
      data: chipThemeOverride,
      child: Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          children: [
            // Background Decorative Element
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      "Welcome to TopScore AI",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Tell us what you're studying so the AI can align with your exact syllabus and grade level.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: textColor.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // --- Curriculum Selection ---
                    Text(
                      "Select Curriculum",
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _curriculums.map((curriculum) {
                        final isSelected = _selectedCurriculum == curriculum;
                        return ChoiceChip(
                          label: Text(
                            curriculum,
                            style: TextStyle(
                              color: isSelected ? AppColors.edupoaBlue : textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCurriculum = curriculum;
                              _selectedGrade =
                                  null; // Reset grade on curriculum change
                            });
                          },
                          selectedColor: textColor,
                          color: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return textColor;
                            }
                            return textColor.withValues(alpha: 0.15);
                          }),
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : textColor.withValues(alpha: 0.3),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),

                    // --- Grade Selection (Visible only after Curriculum is chosen) ---
                    if (_selectedCurriculum != null) ...[
                      Text(
                        "Select Level",
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _availableGrades.map((grade) {
                          final isSelected = _selectedGrade == grade;
                          return ChoiceChip(
                            label: Text(
                              grade,
                              style: TextStyle(
                                color: isSelected ? AppColors.edupoaBlue : textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            showCheckmark: false,
                            onSelected: (selected) {
                              setState(() => _selectedGrade = grade);
                            },
                            selectedColor: textColor,
                            color: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return textColor;
                              }
                              return textColor.withValues(alpha: 0.15);
                            }),
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : textColor.withValues(alpha: 0.3),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          );
                        }).toList(),
                      ),
                    ],

                    const Spacer(),

                    // --- Call to Action ---
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: ElevatedButton(
                        onPressed: _finishSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.edupoaBlue,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: Text(
                          "Start Learning",
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
