import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().userModel;

    // Default CBC Competencies if none exist
    final competencies = user?.competencyScores ?? {
      'Communication': 0.65,
      'Collaboration': 0.80,
      'Critical Thinking': 0.45,
      'Creativity': 0.70,
      'Self-Efficacy': 0.55,
      'Digital Literacy': 0.90,
      'Citizenship': 0.50,
    };

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Achievements', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CORE COMPETENCIES (CBC RADAR) ---
            _sectionLabel('CBC Core Competencies'),
            const SizedBox(height: 12),
            AppTheme.buildGlassContainer(
              context,
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    height: 240,
                    child: CustomPaint(
                      painter: CompetencyRadarPainter(
                        scores: competencies,
                        primaryColor: AppColors.primary,
                        textColor: theme.colorScheme.onSurface,
                      ),
                      child: Container(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your highest competency is ${competencies.entries.reduce((a, b) => a.value > b.value ? a : b).key}!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

            const SizedBox(height: 32),

            // --- BADGE VAULT ---
            _sectionLabel('Badge Vault'),
            const SizedBox(height: 16),
            _buildBadgeVault(user?.badges ?? []),

            const SizedBox(height: 32),

            // --- PROGRESS ROADMAP ---
            _sectionLabel('Milestone Roadmap'),
            const SizedBox(height: 16),
            _buildRoadmap(user?.level ?? 1, user?.xp ?? 0),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildBadgeVault(List<String> userBadges) {
    final allBadges = [
      ('Early Bird', 'Joined TopScore in its first month', Icons.wb_twilight_rounded, Colors.amber),
      ('Math Whiz', 'Completed 50+ Calculus problems', Icons.calculate_rounded, Colors.blue),
      ('Polyglot', 'Mastered basics of 3 languages', Icons.translate_rounded, Colors.green),
      ('Quiz Master', 'Won 10 Multiplayer battles', Icons.emoji_events_rounded, Colors.purple),
      ('Deep Researcher', 'Summarized 100+ PDF pages', Icons.auto_stories_rounded, Colors.orange),
      ('Night Owl', 'Studied 5 days in a row after 9 PM', Icons.dark_mode_rounded, Colors.indigo),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: allBadges.length,
      itemBuilder: (context, i) {
        final b = allBadges[i];
        final hasBadge = userBadges.contains(b.$1);

        return Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: hasBadge ? b.$4.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasBadge ? b.$4.withValues(alpha: 0.5) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                b.$3,
                color: hasBadge ? b.$4 : Colors.grey.withValues(alpha: 0.3),
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: hasBadge ? () => _shareBadge(b.$1, b.$2) : null,
              child: Text(
                b.$1,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: hasBadge ? b.$4 : Colors.grey,
              ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: Duration(milliseconds: i * 100)).scale();
      },
    );
  }

  void _shareBadge(String name, String desc) {
    final text = "I just earned the '$name' badge on TopScore AI! 🏆 $desc. Download and study with me: https://topscoreapp.ai/download";
    SharePlus.instance.share(ShareParams(text: text));
  }

  Widget _buildRoadmap(int level, int xp) {
    return Column(
      children: List.generate(5, (i) {
        final milestoneLevel = (i + 1) * 5;
        final isCompleted = level >= milestoneLevel;
        final isNext = level < milestoneLevel && (i == 0 || level >= (i * 5));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.success : (isNext ? AppColors.primary : Colors.grey.withValues(alpha: 0.2)),
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ),
                if (i < 4)
                  Container(
                    width: 2,
                    height: 60,
                    color: isCompleted ? AppColors.success : Colors.grey.withValues(alpha: 0.2),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Milestone: Level $milestoneLevel',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isCompleted ? AppColors.success : (isNext ? AppColors.primary : Colors.grey),
                    ),
                  ),
                  Text(
                    _getMilestoneDesc(milestoneLevel),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  if (isNext) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (xp % 5000) / 5000,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  String _getMilestoneDesc(int level) {
    switch (level) {
      case 5: return "TopScore Novice - Unlocks custom AI avatars";
      case 10: return "Knowledge Seeker - Unlocks advanced analytics";
      case 15: return "Scholar - Unlocks early access to new tools";
      case 20: return "Master - Unlocks premium themes";
      case 25: return "Legend - Exclusive badge and lifetime recognition";
      default: return "Keep learning to reach the next milestone!";
    }
  }
}

class CompetencyRadarPainter extends CustomPainter {
  final Map<String, double> scores;
  final Color primaryColor;
  final Color textColor;

  CompetencyRadarPainter({
    required this.scores,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(centerX, centerY) * 0.75;
    final sides = scores.length;

    final paintLine = Paint()
      ..color = textColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final paintFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Draw Background Grid
    for (int i = 1; i <= 4; i++) {
      double r = radius * (i / 4);
      _drawPolygon(canvas, centerX, centerY, r, sides, paintLine);
    }

    // 2. Draw Spokes and Labels
    final angleStep = (2 * pi) / sides;
    final path = Path();
    final List<Offset> points = [];

    int index = 0;
    scores.forEach((label, score) {
      final angle = (index * angleStep) - (pi / 2);

      // Draw Spoke
      final spokeX = centerX + radius * cos(angle);
      final spokeY = centerY + radius * sin(angle);
      canvas.drawLine(Offset(centerX, centerY), Offset(spokeX, spokeY), paintLine);

      // Draw Label
      final labelRadius = radius * 1.28;
      final labelX = centerX + labelRadius * cos(angle);
      final labelY = centerY + labelRadius * sin(angle);

      textPainter.text = TextSpan(
        text: label.split(' ').join('\n'),
        style: GoogleFonts.poppins(
          color: textColor.withValues(alpha: 0.6),
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2));

      // Plot Point
      final valueRadius = radius * score.clamp(0.1, 1.0);
      final pointX = centerX + valueRadius * cos(angle);
      final pointY = centerY + valueRadius * sin(angle);
      points.add(Offset(pointX, pointY));

      if (index == 0) {
        path.moveTo(pointX, pointY);
      } else {
        path.lineTo(pointX, pointY);
      }
      index++;
    });

    path.close();
    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintBorder);

    final dotPaint = Paint()..color = primaryColor;
    for (var point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  void _drawPolygon(
      Canvas canvas, double cx, double cy, double r, int sides, Paint paint) {
    final path = Path();
    final angleStep = (2 * pi) / sides;
    for (int i = 0; i < sides; i++) {
      final angle = (i * angleStep) - (pi / 2);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
