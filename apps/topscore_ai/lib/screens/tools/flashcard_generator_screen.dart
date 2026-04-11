import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../main.dart'; // Access studyDb
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import 'flashcard_study_screen.dart';
import '../../constants/colors.dart';
import '../../utils/curriculum_utils.dart';
import '../../services/analytics_service.dart';

class FlashcardGeneratorScreen extends StatefulWidget {
  const FlashcardGeneratorScreen({super.key});

  @override
  State<FlashcardGeneratorScreen> createState() =>
      _FlashcardGeneratorScreenState();
}

class _FlashcardGeneratorScreenState extends State<FlashcardGeneratorScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _sourceTextController = TextEditingController();
  final AIService _aiService = AIService();

  bool _isLoading = false;
  double _buildProgress = 0.0;
  String? _statusMessage;
  int _cardAmount = 5;
  String _selectedCurriculum = 'CBC';
  String _selectedGrade = 'Grade 7';

  final List<String> _curriculums = CurriculumData.getCurriculums();
  
  List<String> get _availableGrades => CurriculumData.getGradesForCurriculum(_selectedCurriculum);

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logToolStarted('flashcard_generator');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userModel;
      if (user != null && user.curriculum != null) {
        setState(() {
          // Normalize 8-4-4 to 844 for current dropdown selection
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

  @override
  void dispose() {
    _topicController.dispose();
    _sourceTextController.dispose();
    super.dispose();
  }

  Future<void> _generateFlashcards() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a topic first.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _buildProgress = 0.0;
      _statusMessage = "Connecting to AI... 🧠";
    });

    try {
      final userId = context.read<AuthProvider>().userModel?.uid;
      if (userId == null) return;

      setState(() => _statusMessage = "Generating flashcards... 📝");

      final sourceText = _sourceTextController.text.trim();

      final flashcardSet = await _aiService.generateFlashcards(
        userId: userId,
        topic: topic,
        amount: _cardAmount,
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
        sourceText: sourceText.isNotEmpty ? sourceText : null,
      );

      // BUILD PHASE: Process cards one-by-one for premium feedback
      final cards = flashcardSet.cards;
      for (int i = 0; i < cards.length; i++) {
        if (!mounted) return;
        setState(() {
          _buildProgress = (i + 1) / cards.length;
          _statusMessage = "Building card ${i + 1} of ${cards.length}... ✨";
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }

      setState(() => _statusMessage = "Saving your deck... 💾");

      await studyDb.saveMaterial(
        type: 'flashcard',
        topic: topic,
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
        jsonData: jsonEncode(flashcardSet.toJson()),
      );

      if (!mounted) return;


      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FlashcardStudyScreen(flashcardSet: flashcardSet),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Error: ${e.toString().replaceFirst('Exception: ', '')}")),
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
      
      AnalyticsService.instance.logMaterialGenerated(
        type: 'flashcards',
        topic: _topicController.text,
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("AI Flashcards",
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
          _buildInputSection(theme, isDark),
          if (_isLoading) _buildLoadingOverlay(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme, bool isDark) {
    return Positioned.fill(
      child: Container(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF6C63FF),
                    size: 48,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.05, 1.05),
                    duration: 800.ms),
                const SizedBox(height: 32),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.white : Colors.black,
                  highlightColor: const Color(0xFF6C63FF),
                  child: Text(
                    _statusMessage ?? "Connecting...",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_buildProgress > 0)
                  Container(
                    width: 200,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 200 * _buildProgress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _buildProgress > 0
                      ? "${(_buildProgress * 100).toInt()}% READY"
                      : "TOP-SCORE AI ENGINE...",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.4),
                  ),
                ),
              ],
            ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Generate Concept Cards",
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text("Enter a topic and let AI structure your knowledge.",
              style: GoogleFonts.inter(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary)),
          const SizedBox(height: 32),
          _buildLabel("TOPIC"),
          const SizedBox(height: 10),
          TextField(
            controller: _topicController,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            decoration: _inputDecoration(
                isDark, "e.g., Quantum Physics", Icons.lightbulb_outline),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("CURRICULUM"),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurriculum,
                          isExpanded: true,
                          dropdownColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                          items: _curriculums
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c, style: GoogleFonts.inter())))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedCurriculum = v;
                                _selectedGrade = _availableGrades.first;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("GRADE/LEVEL"),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGrade,
                          isExpanded: true,
                          dropdownColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                          items: _availableGrades
                              .map((g) => DropdownMenuItem(
                                  value: g, child: Text(g, style: GoogleFonts.inter())))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedGrade = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLabel("CARD DENSITY: $_cardAmount"),
          Slider(
            value: _cardAmount.toDouble(),
            min: 3,
            max: 20,
            divisions: 17,
            activeColor: const Color(0xFF6C63FF),
            inactiveColor: isDark ? Colors.white12 : Colors.black12,
            onChanged: (v) => setState(() => _cardAmount = v.round()),
          ),
          const SizedBox(height: 24),
          _buildLabel("SOURCE MATERIAL (OPTIONAL)"),
          const SizedBox(height: 10),
          TextField(
            controller: _sourceTextController,
            maxLines: 5,
            decoration: _inputDecoration(isDark,
                "Paste your study notes here...", Icons.description_outlined),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _generateFlashcards,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("Generate Study Library",
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: const Color(0xFF6C63FF)));
  }

  InputDecoration _inputDecoration(bool isDark, String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
      filled: true,
      fillColor: isDark ? AppColors.surfaceElevatedDark : Colors.grey.shade100,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(20),
    );
  }
}
