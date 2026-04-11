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
  final TextEditingController _nameController = TextEditingController();
  bool _nameInitialized = false;

  final List<String> _curriculums = CurriculumData.getCurriculums();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Dynamic grades based on the exact 2026 Kenyan education timeline
  List<String> get _availableGrades {
    if (_selectedCurriculum == null) return [];
    return CurriculumData.getGradesForCurriculum(_selectedCurriculum!);
  }

  Future<void> _finishSetup() async {
    if (_selectedCurriculum == null || _selectedGrade == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please provide your name, curriculum, and level to continue.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Single Source of Truth: Dual Writes (Local + Firestore) 
    // to ensure user is never prompted again regardless of sync status.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // 1. Local Write
    final offline = OfflineService();
    await offline.setStringList('onboarding_complete', ['true']);
    await offline.setStringList('user_profile', [
      _selectedCurriculum!,
      _selectedGrade!.toString(),
      _nameController.text.trim(),
    ]);

    // 2. Firestore Write
    if (mounted) {
      await authProvider.updateUserRole(
        role: 'student',
        grade: _selectedGrade!,
        preferredName: _nameController.text.trim(),
        curriculum: _selectedCurriculum,
        schoolName: 'Self Study', // Default for onboarding completion
      );
    }

    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Colors.white;

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
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            image: DecorationImage(
              image: const AssetImage('assets/images/auth_background.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.6),
                BlendMode.darken,
              ),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          "Welcome to TopScore AI",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Tell us what you're studying so the AI can align with your exact syllabus and grade level.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                      // --- Preferred Name ---
                      Builder(builder: (context) {
                        if (!_nameInitialized) {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final fullName = authProvider.userModel?.displayName ?? '';
                          _nameController.text = authProvider.userModel?.preferredName ?? fullName.split(' ').first;
                          _selectedCurriculum ??= authProvider.userModel?.curriculum;
                          _selectedGrade ??= authProvider.userModel?.grade != null ? authProvider.userModel!.gradeLabel : null;
                          _nameInitialized = true;
                        }
                        return TextField(
                          controller: _nameController,
                          style: GoogleFonts.nunito(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'What should your AI Tutor call you?',
                            labelStyle: GoogleFonts.nunito(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            hintText: 'e.g. Jay, Kariuki, Amina...',
                            hintStyle: GoogleFonts.nunito(
                              color: textColor.withValues(alpha: 0.4),
                            ),
                            filled: true,
                            fillColor: textColor.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            prefixIcon: Icon(Icons.person_outline, color: textColor.withValues(alpha: 0.5)),
                          ),
                        );
                      }),
                      const SizedBox(height: 36),

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
                                _selectedGrade = null; // Reset grade on curriculum change
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

                      // --- Grade Selection ---
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
