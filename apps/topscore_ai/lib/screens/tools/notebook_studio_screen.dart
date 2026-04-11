import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../main.dart'; // To access studyDb
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import 'quiz_study_screen.dart';
import 'flashcard_study_screen.dart';
import 'summary_study_screen.dart';
import '../../models/quiz_model.dart';
import '../../models/flashcard_model.dart';
import '../../widgets/bounce_wrapper.dart';
import '../../constants/colors.dart';

class NotebookStudioScreen extends StatefulWidget {
  final String sourceTitle; // e.g., "Cellular Respiration" or "Biology_Notes.pdf"
  final String curriculum;
  final String grade;
  final String? sourceText;

  const NotebookStudioScreen({
    super.key,
    required this.sourceTitle,
    required this.curriculum,
    required this.grade,
    this.sourceText,
  });

  @override
  State<NotebookStudioScreen> createState() => _NotebookStudioScreenState();
}

class _NotebookStudioScreenState extends State<NotebookStudioScreen> {
  final AIService _aiService = AIService();
  
  bool _isGeneratingQuiz = false;
  bool _isGeneratingFlashcards = false;
  bool _isGeneratingSummary = false;

  Future<void> _triggerGeneration(String type) async {
    final existing = await studyDb.getMaterialByTopic(type, widget.sourceTitle);
    
    if (existing != null) {
      if (!mounted) return;
      _navigateToMaterial(type, existing['jsonData']);
      return;
    }

    setState(() {
      if (type == 'quiz') _isGeneratingQuiz = true;
      if (type == 'flashcard') _isGeneratingFlashcards = true;
      if (type == 'summary') _isGeneratingSummary = true;
    });

    try {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userModel?.uid;
      if (userId == null) throw Exception("User not authenticated");

      String jsonData;
      
      if (type == 'quiz') {
        final quiz = await _aiService.generateQuiz(
          userId: userId,
          topic: widget.sourceTitle,
          curriculum: widget.curriculum,
          grade: widget.grade,
          sourceText: widget.sourceText,
        );
        jsonData = jsonEncode(quiz.toJson());
      } else if (type == 'flashcard') {
        final group = await _aiService.generateFlashcards(
          userId: userId,
          topic: widget.sourceTitle,
          curriculum: widget.curriculum,
          grade: widget.grade,
          sourceText: widget.sourceText,
        );
        jsonData = jsonEncode(group.toJson());
      } else {
        final summaryText = await _aiService.summarizeTopic(
          topic: widget.sourceTitle,
          level: widget.grade,
        );
        jsonData = jsonEncode({'summary': summaryText});
      }

      await studyDb.saveMaterial(
        type: type,
        topic: widget.sourceTitle,
        curriculum: widget.curriculum,
        grade: widget.grade,
        jsonData: jsonData,
      );

      if (!mounted) return;
      _navigateToMaterial(type, jsonData);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating $type: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (type == 'quiz') _isGeneratingQuiz = false;
          if (type == 'flashcard') _isGeneratingFlashcards = false;
          if (type == 'summary') _isGeneratingSummary = false;
        });
      }
    }
  }

  void _navigateToMaterial(String type, String jsonData) {
    Widget screen;
    final Map<String, dynamic> data = jsonDecode(jsonData);

    if (type == 'quiz') {
      screen = QuizStudyScreen(
        offlineQuiz: Quiz.fromJson(data),
        topic: widget.sourceTitle,
        curriculum: widget.curriculum,
        grade: widget.grade,
      );
    } else if (type == 'flashcard') {
      screen = FlashcardStudyScreen(
        flashcardSet: FlashcardSet.fromJson(data),
      );
    } else {
      screen = SummaryStudyScreen(
        topic: widget.sourceTitle,
        markdownContent: data['summary'],
      );
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium Hero Anchor Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            leading: const BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: _buildHeroAnchor(theme, isDark),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "STUDY MODULES",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 20),
                  _buildToolCard(
                    context: context,
                    title: "Practice Quiz",
                    subtitle: "Test your knowledge with AI-driven questions.",
                    icon: CupertinoIcons.checkmark_seal_fill,
                    color: const Color(0xFFF59E0B),
                    isGenerating: _isGeneratingQuiz,
                    onTap: () => _triggerGeneration('quiz'),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  _buildToolCard(
                    context: context,
                    title: "Flashcards",
                    subtitle: "Master key terms with flippable study cards.",
                    icon: CupertinoIcons.rectangle_on_rectangle_angled,
                    color: const Color(0xFF8B5CF6),
                    isGenerating: _isGeneratingFlashcards,
                    onTap: () => _triggerGeneration('flashcard'),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  _buildToolCard(
                    context: context,
                    title: "Executive Summary",
                    subtitle: "A condensed breakdown of the entire topic.",
                    icon: CupertinoIcons.doc_text_fill,
                    color: const Color(0xFF10B981),
                    isGenerating: _isGeneratingSummary,
                    onTap: () => _triggerGeneration('summary'),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAnchor(ThemeData theme, bool isDark) {
    return ClipRRect(
      child: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [AppColors.backgroundDark, AppColors.surfaceVariantDark]
                    : [const Color(0xFFE2E8F0), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Frosted Glass Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Decorative Icon
          Positioned(
            right: -30,
            bottom: -30,
            child: Icon(
              CupertinoIcons.doc_text_search,
              size: 200,
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.04) 
                  : Colors.black.withValues(alpha: 0.04),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .moveY(begin: 0, end: 10, duration: 3.seconds, curve: Curves.easeInOut),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    "STUDY STUDIO",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                const SizedBox(height: 12),
                Text(
                  widget.sourceTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(CupertinoIcons.square_grid_2x2_fill, 
                        size: 16, 
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      "${widget.curriculum} • ${widget.grade}",
                      style: GoogleFonts.inter(
                        fontSize: 15, 
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isGenerating,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    Widget cardContent = Row(
      children: [
        _PulsingIcon(
          icon: icon, 
          color: color, 
          isGenerating: isGenerating,
          isDark: isDark,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isGenerating ? "Analyzing material..." : subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (!isGenerating)
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
      ],
    );

    return BounceWrapper(
      onTap: isGenerating ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isGenerating 
                ? color.withValues(alpha: 0.5) 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            width: isGenerating ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isGenerating 
                  ? color.withValues(alpha: 0.15) 
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isGenerating ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isGenerating 
          ? Shimmer.fromColors(
              baseColor: color.withValues(alpha: 0.1),
              highlightColor: color.withValues(alpha: 0.3),
              child: cardContent,
            )
          : cardContent,
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isGenerating;
  final bool isDark;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.isGenerating,
    required this.isDark,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isGenerating) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGenerating && !oldWidget.isGenerating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isGenerating && oldWidget.isGenerating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(
                alpha: widget.isGenerating ? 0.3 + (_controller.value * 0.4) : 0.2,
              ),
            ),
            boxShadow: widget.isGenerating ? [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.2 * _controller.value),
                blurRadius: 15 * _controller.value,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: Icon(
            widget.icon, 
            color: widget.isGenerating 
                ? Color.lerp(widget.color, Colors.white, _controller.value * 0.3) 
                : widget.color, 
            size: 26,
          ),
        );
      },
    );
  }
}
