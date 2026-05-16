import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../models/flashcard_model.dart';
import '../gpt_markdown_wrapper.dart';
import '../math_markdown.dart';
import '../topscore_watermark.dart';

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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return TopScoreWatermark(
      opacity: 0.3,
      isDark: isFront || isDark,
      child: Container(
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
                      : [Colors.white, const Color(0xFFF1F5F9)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.85),
                  ],
                ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isFront
                ? Colors.white.withValues(alpha: 0.1)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : primaryColor.withValues(alpha: 0.1)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.blueGrey)
                  .withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -2,
            )
          ],
        ),
        child: Stack(
          children: [
            // Decorative accent for the side
            Positioned(
              top: -20,
              right: -20,
              child: Icon(
                isFront ? Icons.help_outline_rounded : Icons.lightbulb_outline_rounded,
                size: 100,
                color: (isFront ? Colors.white : primaryColor).withValues(alpha: 0.05),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SelectionArea(
                  child: StyledGptMarkdown(
                    cleanContent(content),
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: isFront ? FontWeight.w700 : FontWeight.w500,
                      color: isFront
                          ? Colors.white
                          : (isDark ? Colors.white : AppColors.surfaceElevatedDark),
                      height: 1.4,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
