import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../main.dart'; // To access studyDb
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import 'quiz_study_screen.dart';
import '../../constants/colors.dart';
import '../../providers/gamification_provider.dart';
import '../../services/xp_service.dart';
import '../../utils/curriculum_utils.dart';
import '../../services/analytics_service.dart';

class QuizGeneratorScreen extends StatefulWidget {
  const QuizGeneratorScreen({super.key});

  @override
  State<QuizGeneratorScreen> createState() => _QuizGeneratorScreenState();
}

class _QuizGeneratorScreenState extends State<QuizGeneratorScreen> {
  final _topicController = TextEditingController();
  final _sourceTextController = TextEditingController();
  final _aiService = AIService();

  String _selectedCurriculum = 'CBC';
  String _selectedGrade = 'Grade 7';
  String _selectedDifficulty = 'Medium';
  int _questionCount = 5;
  bool _isLoading = false;
  double _buildProgress = 0.0;
  String? _statusMessage;

  final List<String> _curriculums = CurriculumData.getCurriculums();
  
  List<String> get _availableGrades => CurriculumData.getGradesForCurriculum(_selectedCurriculum);

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
            final normalizedGrade = CurriculumData.normalizeGrade(userGradeLabel, _selectedCurriculum);
            
            if (normalizedGrade != null && _availableGrades.contains(normalizedGrade)) {
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
    super.dispose();
  }

  Future<void> _generateQuiz() async {
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

      final quiz = await _aiService.generateQuiz(
        userId: userId,
        topic: topic,
        questionCount: _questionCount,
        difficulty: _selectedDifficulty,
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
        sourceText: sourceText.isNotEmpty ? sourceText : null,
      );

      // BUILD PHASE: Item-by-item progress
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
      
      // Auto-save for offline access
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

      // Award XP for generating a quiz
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null) {
        context
            .read<GamificationProvider>()
            .record(uid, ActivityType.quizGenerated);
      }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('AI Assessment',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildForm(theme, isDark),
          if (_isLoading) _buildLoadingOverlay(theme, isDark),
        ],
      ),
    );
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
                // Pulse Animation
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
                  baseColor: isDark ? Colors.white : Colors.black,
                  highlightColor: const Color(0xFFF59E0B),
                  child: Text(
                    _statusMessage ?? "Connecting...",
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),

                const SizedBox(height: 20),

                if (_buildProgress > 0)
                  Container(
                    width: 240,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
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
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ).animate().fadeIn().moveY(begin: 20, end: 0),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Smart Quiz",
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      Text("Instant assessments for any topic.",
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

          const SizedBox(height: 32),

          _buildLabel("TOPIC"),
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            decoration: _inputDecoration(
                isDark, "e.g., Cellular Respiration", Icons.explore_outlined),
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
                    _buildDropdown(isDark, _selectedCurriculum, _curriculums,
                        (v) {
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
                    _buildLabel("GRADE/LEVEL"),
                    const SizedBox(height: 12),
                    _buildDropdown(isDark, _selectedGrade, _availableGrades,
                        (v) => setState(() => _selectedGrade = v!)),
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
                    _buildDropdown(isDark, _selectedDifficulty, _difficulties,
                        (v) => setState(() => _selectedDifficulty = v!)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Container()), // Spacer
            ],
          ),

          const SizedBox(height: 24),

          _buildLabel("QUESTIONS: $_questionCount"),
          Slider(
            value: _questionCount.toDouble(),
            min: 3,
            max: 10,
            divisions: 7,
            activeColor: const Color(0xFFF59E0B),
            inactiveColor: isDark ? Colors.white12 : Colors.black12,
            onChanged: (v) => setState(() => _questionCount = v.round()),
          ),

          const SizedBox(height: 24),

          _buildLabel("CONTEXTUAL INPUT (OPTIONAL)"),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceTextController,
            maxLines: 4,
            decoration: _inputDecoration(
                isDark,
                "Paste specific content to test on...",
                Icons.auto_stories_outlined),
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _generateQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text("Launch AI Challenge",
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: const Color(0xFFF59E0B)));
  }

  Widget _buildDropdown(bool isDark, String value, List<String> items,
      Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
          items: items
              .map((i) => DropdownMenuItem(
                  value: i, child: Text(i, style: GoogleFonts.inter())))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFFF59E0B)),
      filled: true,
      fillColor: isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade100,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(20),
    );
  }
}
