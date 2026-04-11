import 'package:flutter/material.dart';
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

class _FlashcardArtifactWidgetState extends State<FlashcardArtifactWidget> {
  int _currentIndex = 0;
  bool _isFlipped = false;

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
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = (widget.flashcardData['cards'] as List?) ?? [];
    if (cards.isEmpty) return const SizedBox.shrink();

    final currentCard = cards[_currentIndex];
    final title = widget.flashcardData['topic'] ?? widget.flashcardData['title'] ?? 'Flashcard Deck';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF252525)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withAlpha(50),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  "${_currentIndex + 1}/${cards.length}",
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _flip,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final rotate = Tween(begin: 3.14, end: 0.0).animate(animation);
                  return AnimatedBuilder(
                    animation: rotate,
                    child: child,
                    builder: (context, child) {
                      final isUnder = (ValueKey(_isFlipped) != child!.key);
                      final value = isUnder ? (rotate.value - 3.14) : rotate.value;
                      
                      // Ensure values are finite to prevent "invalid matrix" errors
                      if (!value.isFinite) {
                        return child;
                      }

                      final transformMatrix = Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Use standard perspective index
                        ..rotateY(value);

                      return Transform(
                        transform: transformMatrix,
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                  );
                },
                child: Container(
                  key: ValueKey(_isFlipped),
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isFlipped
                        ? theme.primaryColor.withAlpha(12)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.primaryColor.withAlpha(25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _isFlipped
                            ? currentCard['back'] ?? currentCard['answer'] ?? ''
                            : currentCard['front'] ?? currentCard['question'] ?? '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _isFlipped ? theme.primaryColor : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _previous : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: theme.primaryColor,
                ),
                TextButton.icon(
                  onPressed: _flip,
                  icon: const Icon(Icons.flip_rounded, size: 18),
                  label: Text(_isFlipped ? "Show Front" : "Show Back"),
                ),
                IconButton(
                  onPressed: _currentIndex < cards.length - 1 ? _next : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                  color: theme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
