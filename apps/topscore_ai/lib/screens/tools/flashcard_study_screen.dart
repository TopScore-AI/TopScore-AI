import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/flashcard_model.dart';
import '../../widgets/shared/flippable_flashcard.dart';


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

  /// Live deck — mutable so we can shuffle or filter to unknown-only.
  late List<Flashcard> _deck;

  /// Marks tallied across the current session. Keyed by the card's identity
  /// (index into the original set) so Review-Unknown works correctly.
  final Map<int, bool> _knownMarks = {}; // true = known, false = unknown

  // Swipe Physics State
  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _deck = List<Flashcard>.from(widget.flashcardSet.cards);
  }

  int _identityOf(Flashcard card) => widget.flashcardSet.cards.indexOf(card);

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

    // Horizontal swipes: navigate.
    if (_dragPosition.dx < -100) {
      _nextCard();
      return;
    }
    if (_dragPosition.dx > 100 && _currentIndex > 0) {
      _prevCard();
      return;
    }
    // Vertical swipes: mark known/unknown on the current card.
    if (_dragPosition.dy < -120) {
      _markCurrent(known: true);
      return;
    }
    if (_dragPosition.dy > 120) {
      _markCurrent(known: false);
      return;
    }
    setState(() => _dragPosition = Offset.zero);
  }

  void _markCurrent({required bool known}) {
    if (_currentIndex >= _deck.length) return;
    final id = _identityOf(_deck[_currentIndex]);
    if (id != -1) _knownMarks[id] = known;
    _nextCard();
  }

  void _nextCard() {
    setState(() {
      _dragPosition = Offset.zero;
      if (_currentIndex < _deck.length) {
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

  void _shuffle() {
    setState(() {
      _deck.shuffle(Random());
      _currentIndex = 0;
      _dragPosition = Offset.zero;
    });
  }

  void _restart() {
    setState(() {
      _deck = List<Flashcard>.from(widget.flashcardSet.cards);
      _currentIndex = 0;
      _knownMarks.clear();
      _dragPosition = Offset.zero;
    });
  }

  void _reviewUnknownOnly() {
    final unknown = widget.flashcardSet.cards
        .where((c) {
          final id = _identityOf(c);
          // Keep cards not marked, and cards explicitly marked unknown
          return _knownMarks[id] != true;
        })
        .toList();
    if (unknown.isEmpty) return;
    setState(() {
      _deck = unknown;
      _currentIndex = 0;
      _knownMarks.clear();
      _dragPosition = Offset.zero;
    });
  }

  int get _knownCount =>
      _knownMarks.values.where((v) => v == true).length;
  int get _unknownCount =>
      _knownMarks.values.where((v) => v == false).length;

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
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.shuffle),
            tooltip: 'Shuffle deck',
            onPressed: _deck.isEmpty ? null : _shuffle,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Restart session',
            onPressed: _restart,
          ),
        ],
      ),
      body: _buildDeckArea(theme, isDark),
    );
  }

  Widget _buildDeckArea(ThemeData theme, bool isDark) {
    if (_currentIndex >= _deck.length) {
      return _buildCompletion(theme, isDark);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Card (The "next" card peeking out)
                if (_currentIndex < _deck.length - 1)
                  Transform.scale(
                    scale: 0.95,
                    child: Transform.translate(
                      offset: const Offset(0, 20),
                      child: FlippableFlashcard(
                        card: _deck[_currentIndex + 1],
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
                        card: _deck[_currentIndex],
                      ),
                    ),
                  ),
                ),

                // Swiping Overlays (Horizontal)
                if (_isDragging && _dragPosition.dx.abs() > _dragPosition.dy.abs()) ...[
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

                // Vertical-swipe overlays (known / unknown)
                if (_isDragging && _dragPosition.dy.abs() > _dragPosition.dx.abs()) ...[
                  if (_dragPosition.dy < 0)
                    Positioned(
                      top: 16 + (_dragPosition.dy.abs() / 8),
                      child: _SwipeBadge(
                        label: 'KNOW IT',
                        color: Colors.green,
                        icon: CupertinoIcons.checkmark_circle_fill,
                        opacity: (_dragPosition.dy.abs() / 150).clamp(0.0, 1.0),
                      ),
                    ),
                  if (_dragPosition.dy > 0)
                    Positioned(
                      bottom: 16 + (_dragPosition.dy / 8),
                      child: _SwipeBadge(
                        label: 'REVIEW',
                        color: Colors.orange,
                        icon: CupertinoIcons.clock_fill,
                        opacity: (_dragPosition.dy / 150).clamp(0.0, 1.0),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Inline action buttons — tap alternative to vertical swipes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: CupertinoIcons.clock,
                label: 'Review',
                color: Colors.orange,
                onTap: () => _markCurrent(known: false),
              ),
              _ActionButton(
                icon: CupertinoIcons.arrow_uturn_left,
                label: 'Back',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                onTap: _currentIndex > 0 ? _prevCard : null,
              ),
              _ActionButton(
                icon: CupertinoIcons.checkmark,
                label: 'Know it',
                color: Colors.green,
                onTap: () => _markCurrent(known: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress indicator
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
                      "Card ${_currentIndex + 1} of ${_deck.length}",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      "${((_currentIndex + 1) / _deck.length * 100).toInt()}% Done",
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
                    value: (_currentIndex + 1) / _deck.length,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (_knownMarks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatChip(
                          icon: CupertinoIcons.checkmark_circle_fill,
                          color: Colors.green,
                          label: '$_knownCount known'),
                      _StatChip(
                          icon: CupertinoIcons.clock_fill,
                          color: Colors.orange,
                          label: '$_unknownCount to review'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletion(ThemeData theme, bool isDark) {
    final unknownAvailable = _unknownCount > 0 ||
        _knownMarks.length < widget.flashcardSet.cards.length;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
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
              "$_knownCount known · $_unknownCount to review",
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (unknownAvailable)
                  ElevatedButton.icon(
                    onPressed: _reviewUnknownOnly,
                    icon: const Icon(CupertinoIcons.clock_fill, size: 16),
                    label: const Text('Review unknown'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(CupertinoIcons.refresh, size: 16),
                  label: const Text('Restart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Finish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final double opacity;

  const _SwipeBadge({
    required this.label,
    required this.color,
    required this.icon,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
