import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../config/app_theme.dart';
import '../../widgets/bounce_wrapper.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/interest_update_sheet.dart';
import '../../data/career_database.dart';

class CareerCompassScreen extends StatefulWidget {
  const CareerCompassScreen({super.key});

  @override
  State<CareerCompassScreen> createState() => _CareerCompassScreenState();
}

class _CareerCompassScreenState extends State<CareerCompassScreen> {
  String? _selectedDomain;
  String? _expandedCareerTitle;

  // Map Interest Categories to Compass Directions/Domains
  final Map<String, String> _domainMapping = {
    'Technology & Coding': 'Tech',
    'Medicine & Health': 'Health',
    'Engineering': 'Eng',
    'Arts & Design': 'Arts',
    'Business & Finance': 'Biz',
    'Law & Justice': 'Law',
    'Sports & Fitness': 'Sport',
    'Media & Writing': 'Media',
    'Agriculture & Nature': 'Agri',
    'Teaching & Education': 'Edu',
    'Music & Performance': 'Music',
    'Public Service': 'Gov',
  };

  @override
  void initState() {
    super.initState();
    // Default to the first interest if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user?.interests != null && user!.interests!.isNotEmpty) {
        setState(() {
          _selectedDomain = user.interests!.first;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final interests = user?.interests ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fallback if no interests are set
    if (interests.isEmpty) {
      return _buildEmptyState(context, user?.uid ?? '');
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Career Compass",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => _showInterestSheet(context, user?.uid ?? ''),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : AppColors.primaryBlue,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [AppColors.primaryBlue, const Color(0xFF1E40AF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- TOP SECTION: RADAR & ADVICE BUTTON ---
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Provider.of<AuthProvider>(context, listen: false).reloadUser();
                  },
                  color: Colors.white,
                  backgroundColor: AppColors.primaryBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // RADAR CHART
                        AppTheme.buildGlassContainer(
                          context,
                          borderRadius: 24,
                          padding: const EdgeInsets.all(20),
                          opacity: 0.08,
                          child: Column(
                            children: [
                              Text(
                                "Your Interest Map",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 220,
                                child: CustomPaint(
                                  painter: RadarChartPainter(
                                    interests: interests,
                                    allDomains: _domainMapping,
                                    primaryColor: Colors.white,
                                  ),
                                  child: Container(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // MASTER AI ADVICE BUTTON
                        _buildMasterAiButton(context, user, interests),

                        const SizedBox(height: 32),

                        // DOMAIN SELECTOR (Horizontal Chips)
                        _buildDomainSelector(interests),

                        const SizedBox(height: 20),

                        // CAREER LIST (Category-specific)
                        _buildCareerList(user),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String uid) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(40),
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.compass, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 40),
            Text(
              "Chart Your Course",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Select your interests to generate your personalized career compass and AI study roadmap.",
              style: GoogleFonts.nunito(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _showInterestSheet(context, uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  "Choose Interests",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterAiButton(BuildContext context, dynamic user, List<String> interests) {
    return BounceWrapper(
      onTap: () {
        final gradeInfo = user?.grade != null ? "Grade ${user?.grade}" : "my grade";
        final curriculumInfo = user?.curriculum != null ? "the ${user?.curriculum} curriculum" : "my curriculum";
        final prompt = "I'm a student in $gradeInfo following $curriculumInfo. My interests are ${interests.join(', ')}. Based on my learning context, what comprehensive career advice and study paths do you have for me?";
        context.push('/ai-tutor', extra: {'initial_message': prompt});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.sparkles, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 12),
            Text(
              "Generate Full AI Roadmap",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainSelector(List<String> interests) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: interests.length,
        itemBuilder: (context, index) {
          final domain = interests[index];
          final isSelected = _selectedDomain == domain;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(domain),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedDomain = domain),
              selectedColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryBlue : Colors.white,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              pressElevation: 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCareerList(dynamic user) {
    final domain = _selectedDomain ?? (careerDb.keys.first);
    final careers = careerDb[domain] ?? [];

    return Column(
      children: List.generate(careers.length, (index) {
        final career = careers[index];
        final isExpanded = _expandedCareerTitle == career.title;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          child: AppTheme.buildGlassContainer(
            context,
            borderRadius: 20,
            padding: EdgeInsets.zero,
            opacity: isExpanded ? 0.15 : 0.08,
            child: Column(
              children: [
                ListTile(
                  onTap: () => setState(() => _expandedCareerTitle = isExpanded ? null : career.title),
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: career.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FaIcon(career.icon, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    career.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    career.description,
                    style: GoogleFonts.nunito(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: isExpanded ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                  ),
                ),
                if (isExpanded) _buildInlineAiDetail(career, user),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInlineAiDetail(CareerPath career, dynamic user) {
    final gradeLabel = user?.gradeLabel ?? "your level";
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          
          // AI INSIGHT HEADLINE
          Row(
            children: [
              const Icon(CupertinoIcons.sparkles, color: Color(0xFFFBDB5C), size: 16),
              const SizedBox(width: 8),
              Text(
                "AI INSIGHT FOR $gradeLabel",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFBDB5C),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // ADVICE TEXT
          Text(
            career.advice,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          
          // GRID OF DETAILS
          Row(
            children: [
              _buildDetailItem("Key Skills", career.skills.join(", "), CupertinoIcons.layers_alt),
              const SizedBox(width: 12),
              _buildDetailItem("Subjects", career.subjects.join(", "), CupertinoIcons.book),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailItem("Global Outlook", career.outlook, CupertinoIcons.graph_circle),
          
          const SizedBox(height: 20),
          
          // ACTION BUTTON
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                final prompt = "I'm interested in becoming a ${career.title}. What specific $gradeLabel topics in ${career.subjects.join('/')} should I prioritize to build a strong foundation?";
                context.push('/ai-tutor', extra: {'initial_message': prompt});
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white10,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Deep Dive with AI Tutor",
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: Colors.white60),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showInterestSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InterestUpdateSheet(userId: uid),
    );
  }
}

// --- CUSTOM PAINTER FOR RADAR CHART ---
class RadarChartPainter extends CustomPainter {
  final List<String> interests;
  final Map<String, String> allDomains;
  final Color primaryColor;

  RadarChartPainter({
    required this.interests,
    required this.allDomains,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(centerX, centerY) * 0.8;

    final paintLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final paintFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 1. Draw Spider Web (Grid)
    for (int i = 1; i <= 3; i++) {
      double r = radius * (i / 3);
      _drawPolygon(canvas, centerX, centerY, r, allDomains.length, paintLine);
    }

    // 2. Draw Spokes and Labels
    final angleStep = (2 * pi) / allDomains.length;
    final path = Path();
    final List<Offset> points = [];

    int index = 0;
    allDomains.forEach((fullInterest, shortLabel) {
      final angle = (index * angleStep) - (pi / 2);

      // Draw Spoke
      final spokeX = centerX + radius * cos(angle);
      final spokeY = centerY + radius * sin(angle);
      canvas.drawLine(Offset(centerX, centerY), Offset(spokeX, spokeY), paintLine);

      // Draw Label
      final labelRadius = radius * 1.25;
      final labelX = centerX + labelRadius * cos(angle);
      final labelY = centerY + labelRadius * sin(angle);

      textPainter.text = TextSpan(
        text: shortLabel,
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2));

      final hasInterest = interests.contains(fullInterest);
      final valueRadius = hasInterest ? radius * 0.95 : radius * 0.25;

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

    final dotPaint = Paint()..color = Colors.white;
    for (var point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  void _drawPolygon(Canvas canvas, double cx, double cy, double r, int sides, Paint paint) {
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
