import '../../constants/colors.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../models/quiz_model.dart';
import '../../widgets/gpt_markdown_wrapper.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/bounce_wrapper.dart';

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
    final timerColor = _secondsLeft > 10 ? AppColors.primary : Colors.redAccent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
            border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05))),
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QUESTION ${_currentQuestionIndex + 1} OF ${_order.length}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 1.2,
                  ),
                ),
                if (_timerEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(CupertinoIcons.timer, size: 14, color: timerColor),
                      const SizedBox(width: 6),
                      Text(
                        '${_secondsLeft}s',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: timerColor,
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _order.length,
                minHeight: 6,
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Text(
                    currentQuestion.questionText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ).animate(key: ValueKey(_currentQuestionIndex)).fadeIn().slideY(begin: 0.1, curve: Curves.easeOutCubic),
                const SizedBox(height: 20),
                const SizedBox(height: 24),
                ...List.generate(currentQuestion.options.length, (index) {
                  final isSelected = _selectedAnswerIndex == index;
                  final isCorrectReveal = _showResult && index == currentQuestion.correctIndex;
                  final isWrongReveal = _showResult && isSelected && index != currentQuestion.correctIndex;

                  Color borderColor = theme.dividerColor.withValues(alpha: 0.1);
                  Color accentColor = AppColors.primary;
                  IconData? icon;

                  if (isCorrectReveal) {
                    accentColor = Colors.green;
                    borderColor = Colors.green;
                    icon = Icons.check_circle_rounded;
                  } else if (isWrongReveal) {
                    accentColor = Colors.redAccent;
                    borderColor = Colors.redAccent;
                    icon = Icons.cancel_rounded;
                  } else if (isSelected && !_showResult) {
                    accentColor = AppColors.primary;
                    borderColor = AppColors.primary;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BounceWrapper(
                      onTap: () => _selectAnswer(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected || isCorrectReveal
                              ? accentColor.withValues(alpha: 0.05)
                              : (isDark ? AppColors.surfaceElevatedDark : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected || isCorrectReveal
                                ? borderColor
                                : theme.dividerColor.withValues(alpha: 0.1),
                            width: (isSelected || isCorrectReveal) ? 2 : 1.5,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected || isCorrectReveal
                                  ? accentColor
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index),
                                style: GoogleFonts.outfit(
                                  color: isSelected || isCorrectReveal
                                      ? Colors.white
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              currentQuestion.options[index],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (icon != null)
                            Icon(icon, color: accentColor, size: 24),
                        ]),
                      ),
                    ),
                  ).animate(delay: Duration(milliseconds: 100 * index)).fadeIn().slideX(begin: 0.05);
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

    if (percentage >= 80) {
      gradeColor = Colors.green;
      gradeText = 'Excellent!';
    } else if (percentage >= 60) {
      gradeColor = Colors.orange;
      gradeText = 'Good Job!';
    } else {
      gradeColor = Colors.redAccent;
      gradeText = 'Keep Practicing!';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        GlassCard(
          padding: const EdgeInsets.all(32),
          borderRadius: 32,
          opacity: isDark ? 0.1 : 0.05,
          child: Column(children: [
            Lottie.asset(
              'assets/lottie/mission_clear.json',
              height: 160,
              repeat: false,
            ),
            const SizedBox(height: 16),
            Text(
              gradeText,
              style: GoogleFonts.plusJakartaSans(
                color: gradeColor,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildScoreStat('SCORE', '$_score/${_order.length}'),
                const SizedBox(width: 40),
                _buildScoreStat('ACCURACY', '$percentage%'),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'QUIZ SUMMARY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            _buildSummaryRow('Topic', widget.topic),
            _buildSummaryRow('Difficulty', quiz.difficulty),
            _buildSummaryRow('Questions', '${_order.length}'),
            _buildSummaryRow('Correct', '$_score', valueColor: Colors.green),
            _buildSummaryRow('Incorrect', '$wrongCount', valueColor: Colors.redAccent),
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

  Widget _buildScoreStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
