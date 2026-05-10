import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import '../../services/feature_gate_service.dart';
import '../../widgets/premium_feature_dialog.dart';
import '../../widgets/bounce_wrapper.dart';
import '../../services/multiplayer_service.dart';
import 'quiz_study_screen.dart';
import '../../constants/colors.dart';
import '../../services/analytics_service.dart';
import '../../utils/curriculum_utils.dart';

enum QuizMode { solo, multiplayer }

class QuizGeneratorScreen extends StatefulWidget {
  const QuizGeneratorScreen({super.key});

  @override
  State<QuizGeneratorScreen> createState() => _QuizGeneratorScreenState();
}

class _QuizGeneratorScreenState extends State<QuizGeneratorScreen> {
  QuizMode _currentMode = QuizMode.solo;
  
  // Solo controllers
  final _topicController = TextEditingController();
  final _sourceTextController = TextEditingController();
  
  // Multiplayer controllers
  final _joinCodeController = TextEditingController();
  final _multiplayerService = MultiplayerService();

  String _selectedCurriculum = 'CBC';
  String _selectedGrade = 'Grade 7';
  String _selectedDifficulty = 'Medium';
  int _questionCount = 5;
  bool _isLoading = false;
  double _buildProgress = 0.0;
  String? _statusMessage;

  final List<String> _curriculums = CurriculumData.getCurriculums();

  List<String> get _availableGrades =>
      CurriculumData.getGradesForCurriculum(_selectedCurriculum);

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logToolStarted('quiz_generator');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userModel;
      if (user != null && user.curriculum != null) {
        setState(() {
          final cur = user.curriculum == '8-4-4' ? '844' : user.curriculum!;
          if (_curriculums.contains(cur)) {
            _selectedCurriculum = cur;

            final userGradeLabel = user.gradeLabel.split(' ').last;
            final normalizedGrade = CurriculumData.normalizeGrade(
                userGradeLabel, _selectedCurriculum);

            if (normalizedGrade != null &&
                _availableGrades.contains(normalizedGrade)) {
              _selectedGrade = normalizedGrade;
            } else {
              _selectedGrade = _availableGrades.first;
            }
          }
        });
      }
    });
  }

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];

  @override
  void dispose() {
    _topicController.dispose();
    _sourceTextController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }


  Future<void> _generateSoloQuiz() async {
    final user = context.read<AuthProvider>().userModel;
    if (!FeatureGateService.canGenerateQuiz(user)) {
      await PremiumFeatureDialog.show(
        context,
        featureName: 'Quiz Generation',
        icon: Icons.quiz,
      );
      return;
    }

    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _buildProgress = 0.0;
      _statusMessage = "Connecting to AI... 🧠";
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userModel?.uid;
      if (userId == null) return;
      final sourceText = _sourceTextController.text.trim();

      setState(() => _statusMessage = "Generating your quiz... 📝");

      final quiz = await AIService().generateQuiz(
        userId: userId,
        topic: topic,
        questionCount: _questionCount,
        difficulty: _selectedDifficulty,
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
        sourceText: sourceText.isNotEmpty ? sourceText : null,
      );

      final questions = quiz.questions;
      for (int i = 0; i < questions.length; i++) {
        if (!mounted) return;
        setState(() {
          _buildProgress = (i + 1) / questions.length;
          _statusMessage =
              "Building question ${i + 1} of ${questions.length}... ✨";
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }

      setState(() {
        _isLoading = false;
      });

      await studyDb.saveMaterial(
        type: 'quiz',
        topic: _topicController.text,
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
        jsonData: jsonEncode(questions.map((q) => q.toJson()).toList()),
      );

      AnalyticsService.instance.logMaterialGenerated(
        type: 'quiz',
        topic: _topicController.text,
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizStudyScreen(
            offlineQuiz: quiz,
            topic: topic,
            curriculum: _selectedCurriculum,
            grade: _selectedGrade,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _buildProgress = 0.0;
        });
      }
    }
  }

  Future<void> _hostMultiplayer() async {
    final user = context.read<AuthProvider>().userModel;
    if (!FeatureGateService.canPlayMultiplayerQuiz(user)) {
      await PremiumFeatureDialog.show(
        context,
        featureName: 'Multiplayer Quiz',
        icon: Icons.sports_esports,
      );
      return;
    }

    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic for the lobby')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Preparing AI Battleground... ⚔️";
      _buildProgress = 0.0;
    });

    try {
      final userId = user!.uid;
      final specs = AIService.mapLevelToSpecs(user.gradeLabel);
      
      final generatedQuiz = await AIService().generateQuiz(
        userId: userId,
        topic: topic,
        curriculum: specs['curriculum']!,
        grade: specs['grade']!,
        questionCount: _questionCount,
      );

      if (!mounted) return;
      setState(() => _statusMessage = "Setting up the lobby... 🛡️");

      final roomCode = await _multiplayerService.createRoom(
        hostId: userId,
        quiz: generatedQuiz,
      );

      if (mounted) {
        context.push('/multiplayer-lobby/$roomCode?isHost=true');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to host: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _joinMultiplayer() {
    final code = _joinCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }
    context.push('/multiplayer-lobby/$code?isHost=false');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('AI Assessment',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.primary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [AppColors.backgroundDark, AppColors.surfaceElevatedDark]
                      : [const Color(0xFFF8FAFC), Colors.white],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildGlassForm(theme, isDark),
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildGlassForm(ThemeData theme, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? Colors.white : AppColors.primary)
                  .withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeSelector(isDark),
              const SizedBox(height: 32),
              
              if (_currentMode == QuizMode.multiplayer) ...[
                _buildLabel("JOIN EXISTING ROOM"),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassTextField(
                        controller: _joinCodeController,
                        hint: "000000",
                        icon: Icons.vpn_key_outlined,
                        isDark: isDark,
                        textAlign: TextAlign.center,
                        letterSpacing: 8,
                        maxLength: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    BounceWrapper(
                      onTap: _joinMultiplayer,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white10)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                    Expanded(child: Divider(color: Colors.white10)),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              _buildLabel(_currentMode == QuizMode.solo ? "QUIZ TOPIC" : "HOST NEW BATTLE (TOPIC)"),
              const SizedBox(height: 12),
              _buildGlassTextField(
                controller: _topicController,
                hint: "e.g., Quantum Physics",
                icon: Icons.explore_outlined,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("CURRICULUM"),
                        const SizedBox(height: 12),
                        _buildGlassDropdown(_selectedCurriculum, _curriculums,
                            isDark, (v) {
                          setState(() {
                            _selectedCurriculum = v!;
                            _selectedGrade = _availableGrades.first;
                          });
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("GRADE"),
                        const SizedBox(height: 12),
                        _buildGlassDropdown(_selectedGrade, _availableGrades,
                            isDark, (v) => setState(() => _selectedGrade = v!)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("DIFFICULTY"),
                        const SizedBox(height: 12),
                        _buildGlassDropdown(_selectedDifficulty, _difficulties,
                            isDark, (v) => setState(() => _selectedDifficulty = v!)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Container()),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel("QUESTIONS: $_questionCount"),
              Slider(
                value: _questionCount.toDouble(),
                min: 3,
                max: 10,
                divisions: 7,
                activeColor: AppColors.primary,
                inactiveColor: (isDark ? Colors.white : AppColors.primary)
                    .withValues(alpha: 0.1),
                onChanged: (v) => setState(() => _questionCount = v.round()),
              ),
              if (_currentMode == QuizMode.solo) ...[
                const SizedBox(height: 24),
                _buildLabel("CONTEXTUAL INPUT (OPTIONAL)"),
                const SizedBox(height: 12),
                _buildGlassTextField(
                  controller: _sourceTextController,
                  hint: "Paste specific content to test on...",
                  icon: Icons.auto_stories_outlined,
                  isDark: isDark,
                  maxLines: 4,
                ),
              ],
              const SizedBox(height: 48),
              _buildActionButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(bool isDark) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              title: "Solo Challenge",
              icon: Icons.person_rounded,
              isSelected: _currentMode == QuizMode.solo,
              isDark: isDark,
              onTap: () => setState(() => _currentMode = QuizMode.solo),
            ),
          ),
          Expanded(
            child: _ModeButton(
              title: "Multiplayer Battle",
              icon: Icons.groups_rounded,
              isSelected: _currentMode == QuizMode.multiplayer,
              isDark: isDark,
              onTap: () => setState(() => _currentMode = QuizMode.multiplayer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.start,
    double? letterSpacing,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textAlign: textAlign,
      maxLength: maxLength,
      style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          letterSpacing: letterSpacing,
          color: isDark ? Colors.white : AppColors.primary),
      decoration: InputDecoration(
        hintText: hint,
        counterText: "",
        hintStyle: TextStyle(
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.3),
            letterSpacing: 0),
        prefixIcon: Icon(icon,
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.4)),
        filled: true,
        fillColor:
            (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildGlassDropdown(
      String value, List<String> items, bool isDark, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : AppColors.primary)
              .withValues(alpha: 0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white60 : AppColors.primary),
          dropdownColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      i,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isDark) {
    final title = _currentMode == QuizMode.solo 
        ? "LAUNCH AI CHALLENGE" 
        : "CREATE MULTIPLAYER LOBBY";

    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _currentMode == QuizMode.solo ? _generateSoloQuiz : _hostMultiplayer,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.primary));
  }

  Widget _buildLoadingOverlay(ThemeData theme, bool isDark) {
    return Positioned.fill(
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.psychology,
                      color: Color(0xFFF59E0B), size: 54),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    duration: 1.seconds),
                const SizedBox(height: 32),
                Shimmer.fromColors(
                  baseColor: isDark
                      ? Colors.white70
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  highlightColor: theme.primaryColor,
                  child: Text(
                    _statusMessage ?? "Connecting...",
                    style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 20),
                if (_buildProgress > 0)
                  Container(
                    width: 240,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white12
                          : AppColors.text.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 240 * _buildProgress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  _buildProgress > 0
                      ? "${(_buildProgress * 100).toInt()}% READY"
                      : "TOP-SCORE AI ENGINE...",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: isDark
                        ? Colors.white38
                        : AppColors.text.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ).animate().fadeIn().moveY(begin: 20, end: 0),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BounceWrapper(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 18, 
              color: isSelected 
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? Colors.white38 : AppColors.primary.withValues(alpha: 0.4))
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected 
                    ? (isDark ? Colors.white : AppColors.primary)
                    : (isDark ? Colors.white38 : AppColors.primary.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
