import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:universal_io/io.dart';
import '../../shared/services/media_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import '../../services/feature_gate_service.dart';
import '../../widgets/premium_feature_dialog.dart';
import 'flashcard_study_screen.dart';
import '../../models/flashcard_model.dart';
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

  Uint8List? _pdfBytes;
  String? _pdfFilename;

  Future<void> _pickPdf() async {
    try {
      final results = await MediaPickerService.instance.pickFiles(
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (results.isEmpty) return;
      final picked = results.first;

      Uint8List? fileBytes = picked.bytes;
      if (fileBytes == null && picked.filePath != null) {
        fileBytes = await File(picked.filePath!).readAsBytes();
      }

      if (fileBytes == null) throw Exception("Could not read file data");

      setState(() {
        _pdfBytes = fileBytes;
        _pdfFilename = picked.name;
        if (_topicController.text.trim().isEmpty) {
          _topicController.text = picked.name.replaceAll('.pdf', '').replaceAll('_', ' ');
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking file: $e")),
        );
      }
    }
  }

  void _clearPdf() {
    setState(() {
      _pdfBytes = null;
      _pdfFilename = null;
    });
  }

  bool _isLoading = false;
  double _buildProgress = 0.0;
  String? _statusMessage;
  int _cardAmount = 5;
  String _selectedCurriculum = 'CBC';
  String _selectedGrade = 'Grade 7';

  final List<String> _curriculums = CurriculumData.getCurriculums();

  List<String> get _availableGrades =>
      CurriculumData.getGradesForCurriculum(_selectedCurriculum);

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logToolStarted('flashcard_generator');
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

  @override
  void dispose() {
    _topicController.dispose();
    _sourceTextController.dispose();
    super.dispose();
  }

  Future<void> _generateFlashcards() async {
    final user = context.read<AuthProvider>().userModel;
    if (!FeatureGateService.canGenerateFlashcards(user)) {
      await PremiumFeatureDialog.show(
        context,
        featureName: 'AI Flashcards',
        icon: Icons.style,
      );
      return;
    }

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

      final FlashcardSet flashcardSet;
      if (_pdfBytes != null) {
        setState(() => _statusMessage = "Analyzing document & generating flashcards... 📝");
        flashcardSet = await _aiService.generateFlashcardsFromFile(
          pdfBytes: _pdfBytes!,
          filename: _pdfFilename!,
          curriculum: _selectedCurriculum,
          grade: _selectedGrade,
          amount: _cardAmount,
        );
      } else {
        final sourceText = _sourceTextController.text.trim();
        flashcardSet = await _aiService.generateFlashcards(
          userId: userId,
          topic: topic,
          amount: _cardAmount,
          curriculum: _selectedCurriculum,
          grade: _selectedGrade,
          sourceText: sourceText.isNotEmpty ? sourceText : null,
        );
      }

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
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("AI Flashcards",
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
              child: _buildGlassInput(theme, isDark),
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildGlassInput(ThemeData theme, bool isDark) {
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
              Text("Create Flashcards",
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.primary)),
              const SizedBox(height: 8),
              Text("Enter a topic and let AI structure your knowledge.",
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: (isDark ? Colors.white : AppColors.text)
                          .withValues(alpha: 0.6))),
              const SizedBox(height: 32),
              _buildLabel("TOPIC"),
              const SizedBox(height: 10),
              _buildGlassTextField(
                controller: _topicController,
                hint: "e.g., Quantum Physics",
                icon: Icons.lightbulb_outline,
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
                        const SizedBox(height: 10),
                        _buildGlassDropdown(
                          _selectedCurriculum,
                          _curriculums,
                          isDark,
                          (v) => setState(() {
                            _selectedCurriculum = v!;
                            _selectedGrade = _availableGrades.first;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("GRADE"),
                        const SizedBox(height: 10),
                        _buildGlassDropdown(
                          _selectedGrade,
                          _availableGrades,
                          isDark,
                          (v) => setState(() => _selectedGrade = v!),
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
                activeColor: theme.primaryColor,
                inactiveColor: (isDark ? Colors.white : AppColors.primary)
                    .withValues(alpha: 0.1),
                onChanged: (v) => setState(() => _cardAmount = v.round()),
              ),
              const SizedBox(height: 24),
              _buildLabel("SOURCE MATERIAL (OPTIONAL)"),
              const SizedBox(height: 10),
              _buildGlassTextField(
                controller: _sourceTextController,
                hint: "Paste your study notes here...",
                icon: Icons.description_outlined,
                isDark: isDark,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              _buildLabel("OR UPLOAD PDF STUDY DOCUMENT"),
              const SizedBox(height: 10),
              _buildPdfUploadSelector(isDark),
              const SizedBox(height: 40),
              _buildActionButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfUploadSelector(bool isDark) {
    return GestureDetector(
      onTap: _pickPdf,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pdfFilename != null
                ? AppColors.primary
                : (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.1),
            width: _pdfFilename != null ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _pdfFilename != null ? Icons.picture_as_pdf_rounded : Icons.cloud_upload_outlined,
              color: _pdfFilename != null ? AppColors.primary : (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.4),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pdfFilename ?? "Select PDF Document",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _pdfFilename != null
                          ? (isDark ? Colors.white : AppColors.primary)
                          : (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_pdfFilename != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "File ready to build flashcards",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_pdfFilename != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                onPressed: _clearPdf,
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppColors.primary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.3)),
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
    return Container(
      width: double.infinity,
      height: 60,
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
        onPressed: _generateFlashcards,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          "CREATE FLASHCARDS",
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 48,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.05, 1.05),
                    duration: 800.ms),
                const SizedBox(height: 32),
                Shimmer.fromColors(
                  baseColor: isDark
                      ? Colors.white70
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  highlightColor: theme.primaryColor,
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
                      color: isDark
                          ? Colors.white12
                          : AppColors.text.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 200 * _buildProgress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.primaryColor,
                              theme.primaryColor.withValues(alpha: 0.8)
                            ],
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
}
