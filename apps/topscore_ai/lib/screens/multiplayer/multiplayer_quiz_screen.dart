import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/multiplayer_service.dart';

class MultiplayerQuizScreen extends StatefulWidget {
  final MultiplayerService multiplayerService;
  final bool isHost;

  const MultiplayerQuizScreen({
    super.key,
    required this.multiplayerService,
    required this.isHost,
  });

  @override
  State<MultiplayerQuizScreen> createState() => _MultiplayerQuizScreenState();
}

class _MultiplayerQuizScreenState extends State<MultiplayerQuizScreen> {
  int? _selectedAnswerIndex;
  bool _hasSubmitted = false;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    widget.multiplayerService.roomStateStream.listen((data) {
      if (mounted) {
        setState(() {
          if (data['type'] == 'new_question') {
            _selectedAnswerIndex = null;
            _hasSubmitted = false;
          } else if (data['type'] == 'game_finished') {
            _leaderboard = List<Map<String, dynamic>>.from(data['leaderboard']);
          }
        });
      }
    });
  }

  void _submitAnswer(int index) {
    if (_hasSubmitted) return;
    setState(() {
      _selectedAnswerIndex = index;
      _hasSubmitted = true;
    });
    widget.multiplayerService.submitAnswer(
      widget.multiplayerService.currentQuestionIndex,
      index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final service = widget.multiplayerService;

    if (service.status == MultiplayerStatus.finished) {
      return _buildLeaderboardView(theme, isDark);
    }

    if (service.currentQuestion == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = service.currentQuestion!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Question ${service.currentQuestionIndex + 1}",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.isHost)
            TextButton.icon(
              onPressed: () => widget.multiplayerService.nextQuestion(),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text("Next"),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Question Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)
                ],
              ),
              child: Text(
                question.questionText,
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ).animate().fadeIn().scale(),
            const SizedBox(height: 32),
            // Options
            ...List.generate(question.options.length, (index) {
              final isSelected = _selectedAnswerIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _submitAnswer(index),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.black26 : Colors.white),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                                child: Text(String.fromCharCode(65 + index),
                                    style: TextStyle(
                                        color: isSelected ? Colors.white : null,
                                        fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              question.options[index],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: (100 * index).ms).slideX();
            }),
            const Spacer(),
            if (_hasSubmitted)
              Center(
                child: Text(
                  "Answer Submitted! Waiting for next question...",
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 2.seconds),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardView(ThemeData theme, bool isDark) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 80),
              const SizedBox(height: 16),
              Text(
                "GAME OVER!",
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final p = _leaderboard[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text("#${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(p['name'], style: const TextStyle(color: Colors.white, fontSize: 18)),
                          ),
                          Text("${p['score']} pts", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn().moveY(begin: 100),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Exit to Home", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
