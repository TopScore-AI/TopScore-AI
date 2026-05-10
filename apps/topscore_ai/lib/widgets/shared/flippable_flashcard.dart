import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../models/flashcard_model.dart';
import '../gpt_markdown_wrapper.dart';
import '../math_markdown.dart';

class FlippableFlashcard extends StatelessWidget {
  final Flashcard card;

  const FlippableFlashcard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FlipCard(
      direction: FlipDirection.HORIZONTAL,
      side: CardSide.FRONT,
      speed: 400,
      front: _buildCardSide(
        context,
        content: card.front,
        isFront: true,
        isDark: isDark,
      ),
      back: _buildCardSide(
        context,
        content: card.back,
        isFront: false,
        isDark: isDark,
      ),
    );
  }

  Widget _buildCardSide(
    BuildContext context, {
    required String content,
    required bool isFront,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      height: 450,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: !isFront
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.surfaceElevatedDark, AppColors.backgroundDark]
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
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.blueGrey)
                .withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          )
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: SelectionArea(
            child: StyledGptMarkdown(
              cleanContent(content),
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: isFront ? FontWeight.w600 : FontWeight.w400,
                color: isFront
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.surfaceElevatedDark),
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
