import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';

import 'package:markdown/markdown.dart' as markdown;
import '../../models/flashcard_model.dart';
import '../../widgets/math_markdown.dart';
import '../../utils/markdown/mermaid_builder.dart';

class FlippableFlashcard extends StatefulWidget {
  final Flashcard card;

  const FlippableFlashcard({super.key, required this.card});

  @override
  State<FlippableFlashcard> createState() => _FlippableFlashcardState();
}

class _FlippableFlashcardState extends State<FlippableFlashcard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Animate from 0 to 180 degrees (in radians)
    _animation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Matrix4 for 3D rotation
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Adds depth perspective
            ..rotateY(_animation.value);

          // If the card is rotated more than 90 degrees, we are looking at the back
          final isShowingBack = _animation.value > pi / 2;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Transform(
            alignment: Alignment.center,
            transform: isShowingBack ? (transform..rotateY(pi)) : transform,
            child: Container(
              width: double.infinity,
              height: 450,
              padding: const EdgeInsets.all(32), // Increased padding for premium feel
              decoration: BoxDecoration(
                gradient: isShowingBack
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [Colors.white, const Color(0xFFF8FAFC)],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                borderRadius: BorderRadius.circular(32), // More rounded corners
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : Colors.blueGrey).withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 15),
                    spreadRadius: -5,
                  )
                ],
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: md.MarkdownBody(
                    data: cleanContent(
                        isShowingBack ? widget.card.back : widget.card.front),
                    selectable: true,
                    builders: {
                      'latex': LatexElementBuilder(),
                      'mermaid': MermaidElementBuilder(),
                    },
                    extensionSet: markdown.ExtensionSet(
                      [
                        ...markdown.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        MermaidBlockSyntax()
                      ],
                      [
                        markdown.EmojiSyntax(),
                        LatexSyntax(),
                        ...markdown.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                      ],
                    ),
                    styleSheet: md.MarkdownStyleSheet(
                      p: GoogleFonts.outfit( // Upgraded to Outfit
                        fontSize: 22,
                        fontWeight: isShowingBack
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: isShowingBack
                            ? (isDark ? Colors.white : const Color(0xFF1E293B))
                            : Colors.white,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                      h1: GoogleFonts.lexend( // Upgraded to Lexend
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isShowingBack
                            ? (isDark ? Colors.white : const Color(0xFF1E293B))
                            : Colors.white,
                      ),
                      listBullet: GoogleFonts.outfit(
                        fontSize: 18,
                        color: isShowingBack
                            ? (isDark ? Colors.white : const Color(0xFF1E293B))
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
