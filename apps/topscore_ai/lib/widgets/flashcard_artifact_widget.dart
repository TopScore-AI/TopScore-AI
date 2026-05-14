import '../../constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class FlashcardArtifactWidget extends StatefulWidget {
  final Map<String, dynamic> flashcardData;

  const FlashcardArtifactWidget({
    super.key,
    required this.flashcardData,
  });

  @override
  State<FlashcardArtifactWidget> createState() => _FlashcardArtifactWidgetState();
}

class _FlashcardArtifactWidgetState extends State<FlashcardArtifactWidget>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isFlipped = false;
  late final PageController _pageController;
  late final AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _next() {
    final cards = widget.flashcardData['cards'] as List;
    if (_currentIndex < cards.length - 1) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cards = (widget.flashcardData['cards'] as List?) ?? [];
    if (cards.isEmpty) return const SizedBox.shrink();

    final title = widget.flashcardData['topic'] ?? widget.flashcardData['title'] ?? 'Flashcard Deck';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceElevatedDark
            : const Color(0xFFFFF9F0), // Paper-like color
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.15),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with integrated index
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${_currentIndex + 1} / ${cards.length}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
              ],
            ),
          ),

          const Divider(height: 1),

          // Swipeable Card Area
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              itemCount: cards.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _isFlipped = false;
                });
              },
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final card = cards[index];
                final source = card['source'] ?? widget.flashcardData['source'];
                final isCurrentFlipped = index == _currentIndex && _isFlipped;

                return GestureDetector(
                  onTap: () {
                    if (index == _currentIndex) _flip();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.transparent, // Capture taps
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final rotate = Tween(begin: 3.14 / 2, end: 0.0).animate(
                          CurvedAnimation(parent: animation, curve: Curves.easeOutBack)
                        );
                        return AnimatedBuilder(
                          animation: rotate,
                          child: child,
                          builder: (context, child) {
                            final value = rotate.value;
                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.002)
                                ..rotateX(value),
                              alignment: Alignment.center,
                              child: child,
                            );
                          },
                        );
                      },
                      child: Center(
                        key: ValueKey('${index}_$isCurrentFlipped'),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isCurrentFlipped ? "ANSWER" : "QUESTION",
                                style: GoogleFonts.plusJakartaSans(
                                  letterSpacing: 2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: theme.primaryColor.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isCurrentFlipped
                                    ? card['back'] ?? card['answer'] ?? ''
                                    : card['front'] ?? card['question'] ?? '',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (source != null) ...[
                                const SizedBox(height: 12),
                                _buildSourceGrounding(theme, source),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Swipe hint
          if (cards.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Swipe or use arrows to navigate',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),

          const Divider(height: 1),

          // Bottom Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circularButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: _currentIndex > 0 ? _previous : null,
                  theme: theme,
                  isDark: isDark,
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  onPressed: _flip,
                  child: Row(
                    children: [
                      Icon(Icons.flip_rounded, size: 18, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _isFlipped ? "See Question" : "See Answer",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _circularButton(
                  icon: Icons.arrow_forward_ios_rounded,
                  onPressed: _currentIndex < cards.length - 1 ? _next : null,
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceGrounding(ThemeData theme, String source) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Source: $source",
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circularButton({
    required IconData icon,
    VoidCallback? onPressed,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isEnabled = onPressed != null;
    final iconColor = isEnabled
        ? theme.primaryColor
        : isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.15);
    final bgColor = isEnabled
        ? theme.primaryColor.withValues(alpha: 0.1)
        : isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        color: iconColor,
        disabledColor: iconColor,
      ),
    );
  }
}
