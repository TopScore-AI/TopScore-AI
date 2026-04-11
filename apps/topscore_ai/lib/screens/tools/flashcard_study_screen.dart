import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/flashcard_model.dart';
import '../../widgets/virtual_lab/flippable_flashcard.dart';


class FlashcardStudyScreen extends StatefulWidget {
  final FlashcardSet flashcardSet;

  const FlashcardStudyScreen({
    super.key,
    required this.flashcardSet,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  int _currentIndex = 0;


  // Swipe Physics State
  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta;
      _isDragging = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    // If dragged far enough to the left (Next)
    if (_dragPosition.dx < -100) {
      _nextCard();
    }
    // If dragged far enough to the right (Previous)
    else if (_dragPosition.dx > 100 && _currentIndex > 0) {
      _prevCard();
    }
    // Otherwise, snap back to center
    else {
      setState(() {
        _dragPosition = Offset.zero;
      });
    }
  }

  void _nextCard() {
    setState(() {
      _dragPosition = Offset.zero;
      if (_currentIndex < widget.flashcardSet.cards.length) {
        _currentIndex++;
      }
    });
  }

  void _prevCard() {
    setState(() {
      _dragPosition = Offset.zero;
      if (_currentIndex > 0) {
        _currentIndex--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.flashcardSet.topic,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildDeckArea(theme, isDark),
    );
  }

  Widget _buildDeckArea(ThemeData theme, bool isDark) {
    if (_currentIndex >= widget.flashcardSet.cards.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration_rounded,
                size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              "Deck Completed!",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You've reviewed all cards.",
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Finish Custom Study",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Card (The "next" card peeking out)
                if (_currentIndex < widget.flashcardSet.cards.length - 1)
                  Transform.scale(
                    scale: 0.95,
                    child: Transform.translate(
                      offset: const Offset(0, 20),
                      child: FlippableFlashcard(
                        card: widget.flashcardSet.cards[_currentIndex + 1],
                      ),
                    ),
                  ),

                // Foreground Card (The one being interacted with)
                GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: AnimatedContainer(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuart,
                    transform: (_dragPosition.dx.isFinite && _dragPosition.dy.isFinite)
                        ? (Matrix4.translationValues(
                            _dragPosition.dx, _dragPosition.dy, 0)
                          ..rotateZ(_dragPosition.dx / 1000))
                        : Matrix4.identity(),
                    transformAlignment: Alignment.center,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 48,
                      child: FlippableFlashcard(
                        card: widget.flashcardSet.cards[_currentIndex],
                      ),
                    ),
                  ),
                ),

                // Swiping Arrows (Overlays)
                if (_isDragging) ...[
                  // Next Arrow (Left Swipe)
                  Positioned(
                    right: 20 +
                        (_dragPosition.dx < 0
                            ? _dragPosition.dx.abs() / 10
                            : 0),
                    child: Opacity(
                      opacity: (_dragPosition.dx < 0
                          ? (_dragPosition.dx.abs() / 150).clamp(0.0, 1.0)
                          : 0.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                  // Previous Arrow (Right Swipe)
                  if (_currentIndex > 0)
                    Positioned(
                      left: 20 +
                          (_dragPosition.dx > 0 ? _dragPosition.dx / 10 : 0),
                      child: Opacity(
                        opacity: (_dragPosition.dx > 0
                            ? (_dragPosition.dx / 150).clamp(0.0, 1.0)
                            : 0.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10)
                            ],
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: theme.colorScheme.primary, size: 32),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Premium Progress Indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Card ${_currentIndex + 1} of ${widget.flashcardSet.cards.length}",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      "${((_currentIndex + 1) / widget.flashcardSet.cards.length * 100).toInt()}% Done",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:
                        (_currentIndex + 1) / widget.flashcardSet.cards.length,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
