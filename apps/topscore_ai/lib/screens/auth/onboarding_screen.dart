import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_service.dart';
import '../../constants/colors.dart';
import '../../utils/curriculum_utils.dart';
import '../../widgets/bounce_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String? _selectedCurriculum;
  String? _selectedGrade;
  final TextEditingController _nameController = TextEditingController();
  bool _nameInitialized = false;

  final List<String> _curriculums = CurriculumData.getCurriculums();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  List<String> get _availableGrades {
    if (_selectedCurriculum == null) return [];
    return CurriculumData.getGradesForCurriculum(_selectedCurriculum!);
  }

  Future<void> _nextPage() async {
    if (_currentPage == 0) {
       _pageController.nextPage(duration: 400.ms, curve: Curves.easeInOutCubic);
       return;
    }

    if (_currentPage == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please tell us your name.');
        return;
      }
      _pageController.nextPage(duration: 400.ms, curve: Curves.easeInOutCubic);
      return;
    }

    if (_currentPage == 2) {
      if (_selectedCurriculum == null || _selectedGrade == null) {
        _showError('Please select your curriculum and level.');
        return;
      }
      await _finishSetup();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _finishSetup() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final offline = OfflineService();
    await offline.setStringList('onboarding_complete', ['true']);
    await offline.setStringList('user_profile', [
      _selectedCurriculum!,
      _selectedGrade!,
      _nameController.text.trim(),
    ]);

    if (mounted) {
      await authProvider.updateUserRole(
        role: 'student',
        grade: _selectedGrade!,
        preferredName: _nameController.text.trim(),
        curriculum: _selectedCurriculum,
        schoolName: 'Self Study',
      );
    }

    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                image: DecorationImage(
                  image: const AssetImage('assets/images/auth_background.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.7),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    children: [
                      _buildWelcomeStep(),
                      _buildNameStep(),
                      _buildCurriculumStep(),
                    ],
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: List.generate(3, (index) {
          final active = index <= _currentPage;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ).animate(target: active ? 1 : 0).shimmer(
              duration: 1500.ms,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/lottie/achievement.json', height: 200, repeat: true),
          const SizedBox(height: 40),
          Text(
            "Welcome to TopScore AI",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          Text(
            "The future of learning is here. Let's personalize your experience to match your curriculum and goals.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    if (!_nameInitialized) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final fullName = authProvider.userModel?.displayName ?? '';
      _nameController.text = authProvider.userModel?.preferredName ?? fullName.split(' ').first;
      _nameInitialized = true;
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "First things first...",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 12),
          Text(
            "What should your AI Tutor call you?",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Amina, Kariuki...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              prefixIcon: const Icon(Icons.face_rounded, color: AppColors.primary),
            ),
          ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }

  Widget _buildCurriculumStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            "Almost there!",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 12),
          Text(
            "What are you studying?",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 32),

          Text(
            "CHOOSE CURRICULUM",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _curriculums.map((c) {
              final active = _selectedCurriculum == c;
              return _buildChip(c, active, () {
                setState(() {
                  _selectedCurriculum = c;
                  _selectedGrade = null;
                });
              });
            }).toList(),
          ),

          if (_selectedCurriculum != null) ...[
            const SizedBox(height: 32),
            Text(
              "SELECT YOUR LEVEL",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableGrades.map((g) {
                final active = _selectedGrade == g;
                return _buildChip(g, active, () {
                  setState(() => _selectedGrade = g);
                }, isSmall: true);
              }).toList(),
            ).animate().fadeIn(),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool active, VoidCallback onTap, {bool isSmall = false}) {
    return BounceWrapper(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 16 : 20,
          vertical: isSmall ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: active ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.7),
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: isSmall ? 13 : 15,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          if (_currentPage > 0)
            IconButton(
              onPressed: () {
                _pageController.previousPage(duration: 400.ms, curve: Curves.easeInOutCubic);
              },
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                padding: const EdgeInsets.all(16),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.backgroundDark,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Text(
                _currentPage == 2 ? "Start Learning" : "Continue",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
