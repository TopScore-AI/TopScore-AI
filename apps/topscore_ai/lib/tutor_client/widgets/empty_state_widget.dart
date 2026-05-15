import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyStateWidget extends StatefulWidget {
  final bool isDark;
  final ThemeData theme;
  final void Function(String prompt)? onSuggestionTap;
  final String? userName;
  final List<Map<String, String>> suggestions;

  const EmptyStateWidget({
    super.key,
    required this.isDark,
    required this.theme,
    this.onSuggestionTap,
    this.userName,
    this.suggestions = const [],
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Color _getFeatureColor(String title) {
    if (title.contains('Mathematics')) return const Color(0xFF6366F1); // Indigo
    if (title.contains('STEM')) return const Color(0xFF10B981);        // Emerald/Teal
    if (title.contains('Coding')) return const Color(0xFF8B5CF6);      // Violet
    if (title.contains('Language')) return const Color(0xFFF59E0B);    // Amber
    return const Color(0xFF06B6D4);                                    // Cyan
  }

  void _handleSuggestionTap(Map<String, String> s) {
    if (widget.onSuggestionTap == null) return;
    final title = s['title'] ?? '';
    final subtitle = s['subtitle'] ?? '';
    
    String prompt;
    if (title.contains('Mathematics')) {
      prompt = "I want to Learn Mathematics! $subtitle";
    } else if (title.contains('STEM')) {
      prompt = "I'd like to Explore STEM! $subtitle";
    } else if (title.contains('Coding')) {
      prompt = "Let's Learn Coding! Can you open a P5.js code lab for me?";
    } else if (title.contains('Language')) {
      prompt = "I want to Learn a New Language! Let's start a lesson.";
    } else {
      prompt = "Let's learn something else! What interesting topics do you recommend?";
    }
    
    widget.onSuggestionTap!(prompt);
  }

  Widget _buildSuggestionCard(Map<String, String> s, bool isDark, bool isCompact, int index) {
    final title = s['title'] ?? '';
    final subtitle = s['subtitle'] ?? '';
    final emoji = s['emoji'] ?? '✨';
    final featureColor = _getFeatureColor(title);
    
    // Cards are now more uniform and Gemini-like
    final double cardWidth = isCompact ? double.infinity : 315;
    
    final cardBg = isDark 
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white;
        
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSuggestionTap(s),
          borderRadius: BorderRadius.circular(16),
          splashColor: featureColor.withValues(alpha: 0.05),
          highlightColor: featureColor.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF64748B),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    final displaySuggestions = widget.suggestions.isNotEmpty
        ? widget.suggestions
        : const [
            {"emoji": "📐", "title": "Learn Mathematics", "subtitle": "Master equations, calculus & geometry"},
            {"emoji": "🧪", "title": "Explore STEM", "subtitle": "Dive into physics, chemistry & biology"},
            {"emoji": "💻", "title": "Learn Coding", "subtitle": "Build graphic apps with visual blocks"},
            {"emoji": "🗣️", "title": "Learn a New Language", "subtitle": "Practice conversations with a coach"},
            {"emoji": "✨", "title": "Learn something else", "subtitle": "Ask any question about any topic"}
          ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mascot Greeting
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          widget.theme.primaryColor,
                          const Color(0xFF8B5CF6),
                          const Color(0xFFEC4899),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        widget.userName != null && widget.userName!.isNotEmpty
                            ? 'Hello, ${widget.userName}'
                            : 'Hello there!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 40 : 56,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How can I help you learn today?',
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF64748B),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // App Features Suggestions Title
              FadeTransition(
                opacity: _fadeAnimation,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: displaySuggestions.asMap().entries.map((e) => _buildSuggestionCard(e.value, widget.isDark, isCompact, e.key)).toList(),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
