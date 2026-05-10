import '../../constants/colors.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../models/quiz_model.dart';
import '../../widgets/gpt_markdown_wrapper.dart';

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

  /// Maps the on-screen question index to the *original* question index
  /// in `widget.offlineQuiz.questions`. Enables shuffle while preserving
  /// original order for review / retry-wrong.
  List<int> _order = [];

  Timer? _timer;
  int _secondsLeft = 30;
  late AnimationController _progressAnim;

  // Configurable settings (previously hard-coded).
  bool _timerEnabled = true;
  int _secondsPerQuestion = 30;
  bool _shuffleEnabled = false;

  @override
  void initState() {
    super.initState();
    _order = List<int>.generate(widget.offlineQuiz.questions.length, (i) => i);
    _userAnswers = List.filled(widget.offlineQuiz.questions.length, null);
    _progressAnim = AnimationController(
        vsync: this, duration: Duration(seconds: _secondsPerQuestion));
    _startTimer();
  }

  /// Returns the question at the current *on-screen* index, honoring shuffle.
  QuizQuestion get _currentQuestion =>
      widget.offlineQuiz.questions[_order[_currentQuestionIndex]];

  @override
  void dispose() {
    _timer?.cancel();
    _progressAnim.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (!_timerEnabled) {
      _timer?.cancel();
      _progressAnim.stop();
      return;
    }
    _timer?.cancel();
    _secondsLeft = _secondsPerQuestion;
    _progressAnim.duration = Duration(seconds: _secondsPerQuestion);
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
    // Auto-submit = no answer selected, so it's wrong. No score increment.
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
    if (_selectedAnswerIndex == _currentQuestion.correctIndex) _score++;
    setState(() => _showResult = true);
  }

  void _nextQuestion() {
    if (_currentQuestionIndex >= _order.length - 1) {
      return;
    }
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswerIndex = _userAnswers[_currentQuestionIndex];
      // Treat sentinel -1 (auto-submit with no answer) as already-answered.
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
      _order =
          List<int>.generate(widget.offlineQuiz.questions.length, (i) => i);
      if (_shuffleEnabled) _order.shuffle(Random());
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _showResult = false;
      _score = 0;
      _userAnswers = List.filled(_order.length, null);
    });
    _startTimer();
  }

  /// Re-take only the questions the user got wrong last time.
  /// Questions answered correctly are excluded from the new deck.
  void _retryWrongOnly() {
    final wrong = <int>[];
    for (int i = 0; i < _order.length; i++) {
      final originalIndex = _order[i];
      final answer = _userAnswers[i];
      final correct = widget.offlineQuiz.questions[originalIndex].correctIndex;
      if (answer == null || answer != correct) {
        wrong.add(originalIndex);
      }
    }
    if (wrong.isEmpty) return;
    _stopTimer();
    setState(() {
      _order = wrong;
      if (_shuffleEnabled) _order.shuffle(Random());
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _showResult = false;
      _score = 0;
      _userAnswers = List.filled(_order.length, null);
    });
    _startTimer();
  }

  Future<void> _shareResult() async {
    final pct = (_score / _order.length * 100).round();
    final text =
        'I scored $_score/${_order.length} ($pct%) on "${widget.topic}" in TopScore AI! 🎯';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Sharing failed silently — nothing to recover from.
    }
  }

  Future<void> _showSettingsSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Quiz settings',
                    style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Timer',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      _timerEnabled
                          ? '$_secondsPerQuestion seconds per question'
                          : 'No time limit',
                      style: GoogleFonts.nunito(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 13)),
                  value: _timerEnabled,
                  onChanged: (v) {
                    setSheetState(() {});
                    setState(() {
                      _timerEnabled = v;
                      if (v && !_showResult) {
                        _startTimer();
                      } else {
                        _stopTimer();
                      }
                    });
                  },
                ),
                if (_timerEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [20, 30, 60].map((s) {
                        final selected = _secondsPerQuestion == s;
                        return ChoiceChip(
                          label: Text('${s}s'),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {});
                            setState(() {
                              _secondsPerQuestion = s;
                              if (!_showResult) _startTimer();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                const Divider(height: 24),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Shuffle questions',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                  subtitle: Text('Applied on next restart',
                      style: GoogleFonts.nunito(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 13)),
                  value: _shuffleEnabled,
                  onChanged: (v) {
                    setSheetState(() {});
                    setState(() => _shuffleEnabled = v);
                  },
                ),
              ],
            ),
          );
        });
      },
    );
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

    final isLastQuestion = _currentQuestionIndex == _order.length - 1;
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
              icon: const Icon(CupertinoIcons.settings),
              onPressed: _showSettingsSheet,
              tooltip: 'Settings'),
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
    final currentQuestion = _currentQuestion;
    final timerColor = _secondsLeft > 10 ? theme.primaryColor : Colors.red;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surfaceContainerLow),
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
              Text('${_currentQuestionIndex + 1} / ${_order.length}',
                  style: GoogleFonts.nunito(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / _order.length,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.primaryColor),
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
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
                        color:
                            isDark ? Colors.white : theme.colorScheme.onSurface,
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
                    bgColor = AppColors.aiAccent.withValues(alpha: 0.1);
                    borderColor = AppColors.aiAccent;
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
                                  ? (borderColor ?? AppColors.aiAccent)
                                  : (isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[300]),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                                child: Text(
                              String.fromCharCode(65 + index),
                              style: GoogleFonts.nunito(
                                color: isSelected || (_showResult && isCorrect)
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[600]),
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
                              child: StyledGptMarkdown(
                                  currentQuestion.explanation,
                                  style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: Colors.blue[isDark ? 200 : 900],
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
                  backgroundColor: AppColors.aiAccent,
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
    final percentage = (_score / _order.length * 100).round();
    final wrongCount = _order.length - _score;
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
            Lottie.asset(
              'assets/lottie/mission_clear.json',
              height: 140,
              repeat: false,
            ),
            const SizedBox(height: 8),
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
            Text('$_score / ${_order.length}',
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
            _buildSummaryRow('Questions', '${_order.length}'),
            _buildSummaryRow('Correct', '$_score'),
            _buildSummaryRow('Incorrect', '$wrongCount'),
          ]),
        ),
        const SizedBox(height: 16),
        // Secondary actions — Review answers / Share / Retry wrong only
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showReviewSheet(theme, isDark),
              icon: const Icon(CupertinoIcons.list_bullet, size: 16),
              label: const Text('Review answers'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _shareResult,
              icon: const Icon(CupertinoIcons.share, size: 16),
              label: const Text('Share result'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (wrongCount > 0)
              OutlinedButton.icon(
                onPressed: _retryWrongOnly,
                icon: const Icon(CupertinoIcons.refresh_bold, size: 16),
                label: Text('Retry $wrongCount wrong'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: OutlinedButton(
            onPressed: () {
              context.go('/home'); // Return to home screen not flashcards
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
              backgroundColor: AppColors.aiAccent,
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

  /// Bottom-sheet that walks the user through each question with their
  /// answer vs the correct answer highlighted.
  Future<void> _showReviewSheet(ThemeData theme, bool isDark) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(CupertinoIcons.list_bullet,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('Review answers',
                        style: GoogleFonts.nunito(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded)),
                  ]),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _order.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final q = widget.offlineQuiz.questions[_order[i]];
                      final userIdx = _userAnswers[i];
                      final isCorrect =
                          userIdx != null && userIdx == q.correctIndex;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: (isCorrect ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(
                                  isCorrect ? Icons.check_circle : Icons.cancel,
                                  color: isCorrect ? Colors.green : Colors.red,
                                  size: 18),
                              const SizedBox(width: 6),
                              Text('Q${i + 1}',
                                  style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                      fontSize: 13)),
                            ]),
                            const SizedBox(height: 8),
                            Text(q.questionText,
                                style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3)),
                            const SizedBox(height: 10),
                            ...List.generate(q.options.length, (oi) {
                              final isAnswer = oi == q.correctIndex;
                              final isUserPick =
                                  userIdx != null && userIdx == oi;
                              Color? bg;
                              Color? border;
                              if (isAnswer) {
                                bg = Colors.green.withValues(alpha: 0.1);
                                border = Colors.green;
                              } else if (isUserPick) {
                                bg = Colors.red.withValues(alpha: 0.1);
                                border = Colors.red;
                              }
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: border != null
                                      ? Border.all(color: border)
                                      : null,
                                ),
                                child: Row(children: [
                                  Text('${String.fromCharCode(65 + oi)}. ',
                                      style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Expanded(
                                      child: Text(q.options[oi],
                                          style: GoogleFonts.nunito(
                                              fontSize: 14))),
                                  if (isAnswer)
                                    const Icon(Icons.check,
                                        color: Colors.green, size: 16)
                                  else if (isUserPick)
                                    const Icon(Icons.close,
                                        color: Colors.red, size: 16),
                                ]),
                              );
                            }),
                            if (userIdx == null || userIdx == -1)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Not answered',
                                    style: GoogleFonts.nunito(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic)),
                              ),
                            if (q.explanation.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.lightbulb_outline,
                                          color: Colors.blue, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: StyledGptMarkdown(
                                              q.explanation,
                                              style: GoogleFonts.nunito(
                                                  fontSize: 13,
                                                  color: Colors
                                                      .blue[isDark ? 200 : 900],
                                                  height: 1.3))),
                                    ]),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 14)),
          Text(value,
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
