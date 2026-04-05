import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/quiz_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../services/xp_service.dart';

class QuizStudyScreen extends StatefulWidget {
  final Quiz offlineQuiz;
  final String topic;
  final String curriculum;
  final String grade;

  const QuizStudyScreen({
    super.key,
    required this.offlineQuiz,
    required this.topic,
    required this.curriculum,
    required this.grade,
  });

  @override
  State<QuizStudyScreen> createState() => _QuizStudyScreenState();
}

class _QuizStudyScreenState extends State<QuizStudyScreen>
    with SingleTickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _showResult = false;
  int _score = 0;
  List<int?> _userAnswers = [];
  bool _xpAwarded = false; // guard — award XP only once per quiz

  Timer? _timer;
  int _secondsLeft = 30;
  late AnimationController _progressAnim;
  final bool _timerEnabled = true;

  static const _secondsPerQuestion = 30;

  @override
  void initState() {
    super.initState();
    _userAnswers = List.filled(widget.offlineQuiz.questions.length, null);
    _progressAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: _secondsPerQuestion));
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressAnim.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (!_timerEnabled) return;
    _timer?.cancel();
    _secondsLeft = _secondsPerQuestion;
    _progressAnim.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        if (!_showResult) _autoSubmit();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _progressAnim.stop();
  }

  void _autoSubmit() {
    if (_selectedAnswerIndex == null) {
      _userAnswers[_currentQuestionIndex] = -1;
    }
    setState(() => _showResult = true);
  }

  void _selectAnswer(int index) {
    if (_showResult) return;
    setState(() {
      _selectedAnswerIndex = index;
      _userAnswers[_currentQuestionIndex] = index;
    });
  }

  void _submitAnswer() {
    if (_selectedAnswerIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an answer')));
      return;
    }
    _stopTimer();
    final currentQuestion = widget.offlineQuiz.questions[_currentQuestionIndex];
    if (_selectedAnswerIndex == currentQuestion.correctIndex) _score++;
    setState(() => _showResult = true);

    // Award XP once when the last question is answered
    final isLast =
        _currentQuestionIndex >= widget.offlineQuiz.questions.length - 1;
    if (isLast && !_xpAwarded) {
      _xpAwarded = true;
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null) {
        context
            .read<GamificationProvider>()
            .record(uid, ActivityType.quizCompleted);
      }
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex >= widget.offlineQuiz.questions.length - 1) {
      return;
    }
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswerIndex = _userAnswers[_currentQuestionIndex];
      _showResult = _userAnswers[_currentQuestionIndex] != null;
    });
    if (!_showResult) _startTimer();
  }

  void _previousQuestion() {
    if (_currentQuestionIndex <= 0) return;
    _stopTimer();
    setState(() {
      _currentQuestionIndex--;
      _selectedAnswerIndex = _userAnswers[_currentQuestionIndex];
      _showResult = _userAnswers[_currentQuestionIndex] != null;
    });
  }

  void _resetQuiz() {
    _stopTimer();
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _showResult = false;
      _score = 0;
      _userAnswers = List.filled(widget.offlineQuiz.questions.length, null);
    });
    _startTimer();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'hard':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiz = widget.offlineQuiz;

    final isLastQuestion = _currentQuestionIndex == quiz.questions.length - 1;
    final allAnswered = !_userAnswers.contains(null);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.topic,
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetQuiz,
              tooltip: 'Retry Quiz'),
        ],
      ),
      body: (allAnswered && _showResult && isLastQuestion)
          ? _buildResultsView(theme, isDark)
          : _buildQuizView(theme, isDark, quiz, isLastQuestion),
    );
  }

  Widget _buildQuizView(
      ThemeData theme, bool isDark, Quiz quiz, bool isLastQuestion) {
    final currentQuestion = quiz.questions[_currentQuestionIndex];
    final timerColor = _secondsLeft > 10 ? const Color(0xFF6C63FF) : Colors.red;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100]),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(quiz.title,
                        style: GoogleFonts.nunito(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
                // Custom label display
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _getDifficultyColor(quiz.difficulty),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(quiz.difficulty,
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
                  if (_timerEnabled) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: timerColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        Icon(Icons.timer_rounded, size: 14, color: timerColor),
                        const SizedBox(width: 4),
                        Text('${_secondsLeft}s',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: timerColor)),
                      ]),
                    ),
                  ],
                ]),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              Text('${_currentQuestionIndex + 1} / ${quiz.questions.length}',
                  style: GoogleFonts.nunito(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / quiz.questions.length,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                  ),
                ),
              ),
            ]),
            if (_timerEnabled && !_showResult) ...[
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1 - _progressAnim.value,
                    minHeight: 3,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  ),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Text(currentQuestion.questionText,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? Colors.white : Colors.black87,
                      )),
                ),
                const SizedBox(height: 20),
                ...List.generate(currentQuestion.options.length, (index) {
                  final isSelected = _selectedAnswerIndex == index;
                  final isCorrect = index == currentQuestion.correctIndex;
                  Color? bgColor;
                  Color? borderColor;
                  IconData? trailingIcon;

                  if (_showResult) {
                    if (isCorrect) {
                      bgColor = Colors.green.withValues(alpha: 0.1);
                      borderColor = Colors.green;
                      trailingIcon = Icons.check_circle;
                    } else if (isSelected) {
                      bgColor = Colors.red.withValues(alpha: 0.1);
                      borderColor = Colors.red;
                      trailingIcon = Icons.cancel;
                    }
                  } else if (isSelected) {
                    bgColor = const Color(0xFF6C63FF).withValues(alpha: 0.1);
                    borderColor = const Color(0xFF6C63FF);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _selectAnswer(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor ??
                              (isDark ? Colors.grey[850] : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor ??
                                (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!),
                            width: isSelected || (_showResult && isCorrect)
                                ? 2
                                : 1,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected || (_showResult && isCorrect)
                                  ? (borderColor ?? const Color(0xFF6C63FF))
                                  : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                                child: Text(
                              String.fromCharCode(65 + index),
                              style: GoogleFonts.nunito(
                                color: isSelected || (_showResult && isCorrect)
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(currentQuestion.options[index],
                                  style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : null))),
                          if (trailingIcon != null)
                            Icon(trailingIcon, color: borderColor),
                        ]),
                      ),
                    ),
                  );
                }),
                if (_showResult && currentQuestion.explanation.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(currentQuestion.explanation,
                                  style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: Colors.blue[900],
                                      height: 1.4))),
                        ]),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Row(children: [
            if (_currentQuestionIndex > 0) ...[
              Expanded(
                  child: OutlinedButton(
                onPressed: _previousQuestion,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Previous',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              )),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _showResult
                    ? (isLastQuestion ? null : _nextQuestion)
                    : _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _showResult
                      ? (isLastQuestion ? 'View Results' : 'Next Question')
                      : 'Submit Answer',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildResultsView(ThemeData theme, bool isDark) {
    final quiz = widget.offlineQuiz;
    final percentage = (_score / quiz.questions.length * 100).round();
    final Color gradeColor;
    final String gradeText;
    final IconData gradeIcon;

    if (percentage >= 80) {
      gradeColor = Colors.green;
      gradeText = 'Excellent!';
      gradeIcon = Icons.emoji_events;
    } else if (percentage >= 60) {
      gradeColor = Colors.orange;
      gradeText = 'Good Job!';
      gradeIcon = Icons.thumb_up;
    } else {
      gradeColor = Colors.red;
      gradeText = 'Keep Practicing!';
      gradeIcon = Icons.school;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [gradeColor, gradeColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Icon(gradeIcon, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(gradeText,
                style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You scored',
                style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16)),
            Text('$_score / ${quiz.questions.length}',
                style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold)),
            Text('$percentage%',
                style: GoogleFonts.nunito(color: Colors.white70, fontSize: 20)),
          ]),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quiz Summary',
                style: GoogleFonts.nunito(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSummaryRow('Topic', widget.topic),
            _buildSummaryRow('Difficulty', quiz.difficulty),
            _buildSummaryRow('Questions', '${quiz.questions.length}'),
            _buildSummaryRow('Correct', '$_score'),
            _buildSummaryRow('Incorrect', '${quiz.questions.length - _score}'),
          ]),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context); // Go back to library
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Done',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: ElevatedButton(
            onPressed: _resetQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Retry Quiz',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          )),
        ]),
      ]),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.nunito(color: Colors.grey[600], fontSize: 14)),
          Text(value,
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
