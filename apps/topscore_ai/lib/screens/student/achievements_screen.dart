import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_card.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Achievements',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildXpOverview(context, user, theme, isDark),
            const SizedBox(height: 32),
            _buildCompetencySection(context, user, theme, isDark),
            const SizedBox(height: 32),
            _buildMilestonesSection(context, theme, isDark),
            const SizedBox(height: 32),
            _buildBadgesSection(context, user, theme, isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildXpOverview(
      BuildContext context, dynamic user, ThemeData theme, bool isDark) {
    final xp = user.xp as int? ?? 0;
    final level = user.level as int? ?? 1;
    final xpInLevel = xp % 1000;
    final progress = xpInLevel / 1000.0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      opacity: isDark ? 0.05 : 0.03,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.amber, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${1000 - xpInLevel} XP to Level ${level + 1}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$xpInLevel / 1000 XP',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                'Total: $xp XP',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencySection(
      BuildContext context, dynamic user, ThemeData theme, bool isDark) {
    final scores = user.competencyScores as Map<String, double>? ??
        {
          'Communication': 0.75,
          'Collaboration': 0.85,
          'Critical Thinking': 0.60,
          'Creativity': 0.70,
          'Citizenship': 0.50,
          'Digital Literacy': 0.90,
          'Self-Efficacy': 0.65,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CORE COMPETENCIES', 'CBC Baseline'),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: CustomPaint(
                  painter: _RadarChartPainter(
                    scores: scores,
                    primaryColor: AppColors.primary,
                    textColor: theme.colorScheme.onSurface,
                  ),
                  child: Container(),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: scores.entries.map((e) => _buildScoreChip(e.key, e.value, theme)).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreChip(String label, double score, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(score * 100).toInt()}%',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesSection(BuildContext context, ThemeData theme, bool isDark) {
    final milestones = [
      ('First Question', 'Asked your first AI Tutor question', true),
      ('Flashcard Master', 'Studied 50 flashcards', true),
      ('Quiz Hero', 'Scored 100% on a quiz', true),
      ('Collaborator', 'Joined a multiplayer session', false),
      ('Scholar', 'Reached Level 10', false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('LEARNING MILESTONES', 'Roadmap'),
        const SizedBox(height: 20),
        ...milestones.map((m) => _buildMilestoneTile(m.$1, m.$2, m.$3, theme, isDark)),
      ],
    );
  }

  Widget _buildMilestoneTile(String title, String desc, bool isDone, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? AppColors.primary.withValues(alpha: 0.3) : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDone ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isDone ? AppColors.primary : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context, dynamic user, ThemeData theme, bool isDark) {
    final badges = (user.badges as List<String>? ?? []).isNotEmpty
        ? user.badges as List<String>
        : ['Alpha Tester', 'Early Adopter', 'Streak Starter'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('EARNED BADGES', 'Collection'),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            return _buildBadgeItem(badges[index], theme, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildBadgeItem(String name, ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(FontAwesomeIcons.medal, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final Map<String, double> scores;
  final Color primaryColor;
  final Color textColor;

  _RadarChartPainter({
    required this.scores,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(centerX, centerY) * 0.75;

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

    // 1. Draw Spider Web (Grid)
    for (int i = 1; i <= 4; i++) {
      double r = radius * (i / 4);
      _drawPolygon(canvas, centerX, centerY, r, scores.length, paintLine);
    }

    // 2. Draw Spokes and Labels
    final angleStep = (2 * math.pi) / scores.length;
    final path = Path();
    final List<Offset> points = [];

    int index = 0;
    scores.forEach((label, score) {
      final angle = (index * angleStep) - (math.pi / 2);

      // Draw Spoke
      final spokeX = centerX + radius * math.cos(angle);
      final spokeY = centerY + radius * math.sin(angle);
      canvas.drawLine(
          Offset(centerX, centerY), Offset(spokeX, spokeY), paintLine);

      // Draw Label
      final labelRadius = radius * 1.25;
      final labelX = centerX + labelRadius * math.cos(angle);
      final labelY = centerY + labelRadius * math.sin(angle);

      // Simple label wrapping/truncation
      final shortLabel = label.length > 10 ? '${label.substring(0, 8)}..' : label;

      textPainter.text = TextSpan(
        text: shortLabel,
        style: GoogleFonts.poppins(
          color: textColor.withValues(alpha: 0.6),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(
              labelX - textPainter.width / 2, labelY - textPainter.height / 2));

      final valueRadius = radius * score.clamp(0.0, 1.0);

      final pointX = centerX + valueRadius * math.cos(angle);
      final pointY = centerY + valueRadius * math.sin(angle);
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
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  void _drawPolygon(
      Canvas canvas, double cx, double cy, double r, int sides, Paint paint) {
    final path = Path();
    final angleStep = (2 * math.pi) / sides;
    for (int i = 0; i < sides; i++) {
      final angle = (i * angleStep) - (math.pi / 2);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
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
