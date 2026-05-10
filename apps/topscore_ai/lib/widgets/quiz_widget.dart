import '../../constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'experience_evaluation_modal.dart';
import 'gpt_markdown_wrapper.dart';

class QuizWidget extends StatefulWidget {
  final Map<String, dynamic> quizData;
  final Function(int score) onComplete;

  const QuizWidget({
    super.key,
    required this.quizData,
    required this.onComplete,
  });

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  bool _isCompleted = false;

  void _handleAnswer(int optionIndex) {
    if (_isAnswered) return;

    final correctIndex =
        widget.quizData['questions'][_currentIndex]['correct_index'];
    final isCorrect = optionIndex == correctIndex;

    // Haptic feedback: sharp click for correct, double-buzz for wrong
    if (isCorrect) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      Future.delayed(
          const Duration(milliseconds: 120), HapticFeedback.heavyImpact);
    }

    setState(() {
      _selectedOptionIndex = optionIndex;
      _isAnswered = true;
      if (isCorrect) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    final questions = widget.quizData['questions'] as List;
    if (_currentIndex < questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswered = false;
      });
    } else {
      setState(() {
        _isCompleted = true;
      });
      widget.onComplete(_score);
      // Trigger evaluation modal
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          ExperienceEvaluationModal.show(context, 'Quiz Feature');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final questions = widget.quizData['questions'] as List;
    final currentQuestion = questions[_currentIndex];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.surfaceElevatedDark
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Progress Bar (Top)
            _buildProgressBar(theme, questions.length),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isCompleted
                  ? _buildSummary(theme, questions.length)
                  : _buildQuestion(theme, currentQuestion, questions.length),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme, int total) {
    return Container(
      height: 6,
      width: double.infinity,
      color: theme.primaryColor.withValues(alpha: 0.05),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (_currentIndex + 1) / total,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor,
                theme.primaryColor.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(
    ThemeData theme,
    dynamic questionData,
    int totalQuestions,
  ) {
    final explainer = questionData['explanation'] ?? questionData['explainer'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "QUESTION ${_currentIndex + 1}",
              style: GoogleFonts.plusJakartaSans(
                color: theme.primaryColor.withValues(alpha: 0.6),
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    "Score: $_score",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.amber[800],
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Question Text
        Text(
          questionData['question_text'] ??
              questionData['question'] ??
              'No Question Text',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),

        // Options
        ...List.generate(questionData['options'].length, (index) {
          final option = questionData['options'][index];
          final correctIndex = questionData['correct_index'];

          Color borderColor = theme.dividerColor.withValues(alpha: 0.1);
          Color bgColor = theme.brightness == Brightness.dark 
              ? Colors.white.withValues(alpha: 0.02) 
              : Colors.black.withValues(alpha: 0.02);
          IconData? icon;

          if (_isAnswered) {
            if (index == correctIndex) {
              borderColor = Colors.green;
              bgColor = Colors.green.withValues(alpha: 0.1);
              icon = Icons.check_circle_rounded;
            } else if (index == _selectedOptionIndex) {
              borderColor = Colors.redAccent;
              bgColor = Colors.redAccent.withValues(alpha: 0.1);
              icon = Icons.cancel_rounded;
            }
          }

          return GestureDetector(
            onTap: () => _handleAnswer(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedOptionIndex == index && !_isAnswered
                      ? theme.primaryColor
                      : borderColor,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isAnswered && index == correctIndex ? Colors.green : theme.dividerColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      color: _isAnswered && index == correctIndex ? Colors.green : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + index),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isAnswered && index == correctIndex ? Colors.white : theme.dividerColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (icon != null) Icon(icon, size: 20, color: borderColor),
                ],
              ),
            ),
          );
        }),

        if (_isAnswered && explainer != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      "EXPLANATION",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StyledGptMarkdown(
                  explainer,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Next Button
        if (_isAnswered)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentIndex == totalQuestions - 1
                        ? "Finish Quiz"
                        : "Next Question",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummary(ThemeData theme, int total) {
    final percentage = (_score / total);
    return Column(
      children: [
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                color: percentage > 0.7 ? Colors.green : (percentage > 0.4 ? Colors.orange : Colors.redAccent),
              ),
            ),
            Column(
              children: [
                Text(
                  "${(percentage * 100).toInt()}%",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  "SCORE",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          percentage > 0.7 ? "Excellent Work!" : (percentage > 0.4 ? "Good Effort!" : "Keep Practicing!"),
          style: GoogleFonts.plusJakartaSans(
              fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          "You mastered $_score out of $total questions",
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 32),
        if (widget.quizData['source'] != null)
           Text(
            "Grounded in: ${widget.quizData['source']}",
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }
}
