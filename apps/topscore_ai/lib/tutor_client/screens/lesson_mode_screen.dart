import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/colors.dart';
import '../../../widgets/bounce_wrapper.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/tts_service.dart';
import '../../../services/ai_service.dart';
import '../widgets/hearts_row.dart';
import '../widgets/xp_bar.dart';

class LessonModeScreen extends StatefulWidget {
  final String language;
  final String topic;

  const LessonModeScreen({
    super.key,
    required this.language,
    required this.topic,
  });

  @override
  State<LessonModeScreen> createState() => _LessonModeScreenState();
}

class _LessonModeScreenState extends State<LessonModeScreen> with SingleTickerProviderStateMixin {
  final AIService _aiService = AIService();
  final TtsService _ttsService = TtsService();

  bool _isLoading = true;
  String? _errorMessage;
  
  // Active lesson data
  String _lessonTitle = 'Quest Lesson';
  List<dynamic> _exercises = [];
  int _currentExerciseIndex = 0;
  int _mistakesCount = 0;
  bool _isLessonComplete = false;

  // Duolingo-style gamification state
  int _hearts = 5;
  static const int _maxHearts = 5;
  int _xp = 0;
  static const int _xpPerCorrect = 10;

  bool _isFailed = false;

  final PageController _pageController = PageController();

  // Active answer states
  int? _selectedChoiceIndex; // for translate_to_target
  String? _selectedBlankWord; // for fill_blank
  final TextEditingController _textController = TextEditingController(); // for listen_and_type
  bool _isRecordingVoice = false; // for speak_phrase recording
  bool _voiceSpoken = false; // did they complete voice speech?
  String _voiceTranscript = '';
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _sttAvailable = false;

  // Bottom feedback sheet states
  bool _isChecked = false;
  bool _isAnswerCorrect = false;

  @override
  void initState() {
    super.initState();
    _fetchLesson();
    _ttsService.init();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _sttAvailable = await _speech.initialize(
        onError: (e) => debugPrint('STT lesson error: $e'),
        onStatus: (s) => debugPrint('STT lesson status: $s'),
      );
    } catch (e) {
      _sttAvailable = false;
      debugPrint('STT init failed: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textController.dispose();
    _ttsService.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _fetchLesson() async {
    try {
      final data = await _aiService.generateDuoLesson(
        language: widget.language,
        topic: widget.topic,
        gradeLevel: 'Grade 7',
      );

      if (mounted) {
        setState(() {
          _lessonTitle = data['title'] ?? 'Mastery Quest';
          _exercises = List.from(data['exercises'] ?? []);
          _isLoading = false;
        });

        // Autoplay voice if the first exercise is listen_and_type
        if (_exercises.isNotEmpty) {
          _speakCurrentPhraseIfNeeded();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getLangCode() {
    switch (widget.language.toLowerCase()) {
      case 'french': return 'fr-FR';
      case 'spanish': return 'es-ES';
      case 'german': return 'de-DE';
      case 'kiswahili': return 'sw-KE';
      case 'swahili': return 'sw-KE';
      case 'mandarin': return 'zh-CN';
      case 'chinese': return 'zh-CN';
      case 'italian': return 'it-IT';
      default: return 'en-US';
    }
  }

  Future<void> _speakPhrase(String text, {double rate = 1.0}) async {
    try {
      await _ttsService.setLanguage(_getLangCode());
      await _ttsService.setSpeechRate(rate);
      await _ttsService.speak(text);
    } catch (e) {
      debugPrint('[TTS Error]: $e');
    }
  }

  void _speakCurrentPhraseIfNeeded() {
    if (_currentExerciseIndex >= _exercises.length) return;
    final exercise = _exercises[_currentExerciseIndex];
    if (exercise['exercise_type'] == 'listen_and_type') {
      Future.delayed(const Duration(milliseconds: 400), () {
        _speakPhrase(exercise['target_language_text']);
      });
    }
  }

  bool _isAnswerInputted() {
    if (_currentExerciseIndex >= _exercises.length) return false;
    final exercise = _exercises[_currentExerciseIndex];
    final type = exercise['exercise_type'];

    if (type == 'translate_to_target') {
      return _selectedChoiceIndex != null;
    } else if (type == 'fill_blank') {
      return _selectedBlankWord != null;
    } else if (type == 'listen_and_type') {
      return _textController.text.trim().isNotEmpty;
    } else if (type == 'speak_phrase') {
      return _voiceSpoken;
    }
    return false;
  }

  void _checkAnswer() {
    if (_currentExerciseIndex >= _exercises.length) return;
    final exercise = _exercises[_currentExerciseIndex];
    final type = exercise['exercise_type'];
    final correctText = (exercise['target_language_text'] as String).trim();

    bool correct = false;

    if (type == 'translate_to_target') {
      if (_selectedChoiceIndex != null) {
        final selectedText = exercise['choices'][_selectedChoiceIndex!];
        correct = selectedText.toString().toLowerCase().trim() == correctText.toLowerCase();
      }
    } else if (type == 'fill_blank') {
      correct = _selectedBlankWord?.toLowerCase().trim() == correctText.toLowerCase();
    } else if (type == 'listen_and_type') {
      final input = _textController.text.trim().toLowerCase().replaceAll(RegExp(r'[.,!?]'), '');
      final targetClean = correctText.toLowerCase().replaceAll(RegExp(r'[.,!?]'), '');
      correct = input == targetClean;
    } else if (type == 'speak_phrase') {
      if (!_sttAvailable) {
        // STT unavailable on device — fall back to permissive simulation
        correct = _voiceSpoken;
      } else {
        final t = _voiceTranscript.toLowerCase().trim();
        final tgt = correctText.toLowerCase().trim();
        if (t.isEmpty) {
          correct = false;
        } else {
          correct = _levenshteinRatio(t, tgt) >= 0.7;
        }
      }
    }

    setState(() {
      _isChecked = true;
      _isAnswerCorrect = correct;
      if (correct) {
        _xp += _xpPerCorrect;
      } else {
        _mistakesCount++;
        _hearts = (_hearts - 1).clamp(0, _maxHearts);
        // Append incorrect question to the back of the queue for forgiving retry flow
        _exercises.add(Map.from(exercise));
      }
    });

    if (correct) {
      HapticFeedback.lightImpact();
      _speakPhrase(correctText);
    } else {
      HapticFeedback.heavyImpact();
      if (_hearts <= 0 && !_isFailed) {
        _isFailed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showOutOfHeartsOverlay());
      }
    }
  }

  void _showOutOfHeartsOverlay() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('💔', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Text('Out of hearts!',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'You\'ve run out of hearts on this quest. Take a breather and try again!',
          style: GoogleFonts.nunito(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) context.pop();
            },
            child: Text('Exit',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _hearts = _maxHearts;
                _isFailed = false;
                _isChecked = false;
                _currentExerciseIndex = 0;
                _mistakesCount = 0;
                _xp = 0;
                _selectedChoiceIndex = null;
                _selectedBlankWord = null;
                _textController.clear();
              });
              _pageController.jumpToPage(0);
            },
            child: Text('Retry',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _nextExercise() {
    setState(() {
      _isChecked = false;
      _selectedChoiceIndex = null;
      _selectedBlankWord = null;
      _textController.clear();
      _isRecordingVoice = false;
      _voiceSpoken = false;
      _voiceTranscript = '';

      if (_currentExerciseIndex < _exercises.length - 1) {
        _currentExerciseIndex++;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _speakCurrentPhraseIfNeeded();
      } else {
        _isLessonComplete = true;
      }
    });
  }

  Future<bool> _onWillPop() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Wait, don\'t go!',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You are doing great! Quitting now will lose your progress on this quest.',
          style: GoogleFonts.nunito(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Playing', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Quit', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
              const SizedBox(height: 24),
              Text(
                'Generating your Language Quest...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tailoring to your CBC grade level',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Quest Generation Failed',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _fetchLesson();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLessonComplete) {
      return _buildSummaryScreen(theme, isDark);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header Progress Area ───────────────────────────────────────
              _buildHeader(isDark),
              
              // ── Active Exercise Cards ──────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _exercises[index];
                    return _buildExerciseCard(exercise, isDark);
                  },
                ),
              ),

              // ── Persistent Interactive Bottom Checker ──────────────────────
              _buildBottomActionPanel(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI Builders
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    // Progress is proportion of completed cards out of total exercises
    // Total can change dynamically if they get answers wrong
    double progress = _exercises.isEmpty ? 0.0 : (_currentExerciseIndex / _exercises.length);
    if (progress > 1.0) progress = 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 26, color: Color(0xFF94A3B8)),
                onPressed: () async {
                  if (await _onWillPop() && mounted) {
                    context.pop();
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 14,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              HeartsRow(hearts: _hearts, max: _maxHearts, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 36, height: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _lessonTitle,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
                XpBar(xp: _xp, max: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(dynamic exercise, bool isDark) {
    final type = exercise['exercise_type'];
    final prompt = exercise['prompt_text'] ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Exercise Tag Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getExerciseTypeName(type),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: AppColors.primary,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Main Question Instruction Text
          Text(
            _getExerciseInstruction(type, prompt),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Dynamic Card Form Elements
          if (type == 'translate_to_target')
            _buildTranslateCard(exercise, isDark)
          else if (type == 'fill_blank')
            _buildFillBlankCard(exercise, isDark)
          else if (type == 'listen_and_type')
            _buildListenCard(exercise, isDark)
          else if (type == 'speak_phrase')
            _buildSpeakCard(exercise, isDark),
        ],
      ),
    );
  }

  Widget _buildTranslateCard(dynamic exercise, bool isDark) {
    final choices = List<String>.from(exercise['choices'] ?? []);

    return Column(
      children: List.generate(choices.length, (index) {
        final choice = choices[index];
        final isSelected = _selectedChoiceIndex == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BounceWrapper(
            onTap: _isChecked ? null : () {
              setState(() {
                _selectedChoiceIndex = index;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: isSelected ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey,
                        width: 1.5,
                      ),
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      choice,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                  _speakerPill(choice),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _speakerPill(String text) {
    return GestureDetector(
      onTap: () => _speakPhrase(text),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.volume_up_rounded,
            size: 18, color: AppColors.primary),
      ),
    );
  }

  Widget _buildFillBlankCard(dynamic exercise, bool isDark) {
    final choices = List<String>.from(exercise['choices'] ?? []);
    final prompt = exercise['prompt_text'] ?? '';
    
    // Replace blank '_____' with visual slot
    final parts = prompt.split('_____');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sentence Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 10,
            children: [
              if (parts.isNotEmpty)
                Text(
                  parts[0],
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              // The slot
              GestureDetector(
                onTap: _isChecked ? null : () {
                  setState(() {
                    _selectedBlankWord = null;
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(minWidth: 90),
                  height: 38,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _selectedBlankWord != null
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : (isDark ? Colors.black26 : Colors.white),
                    border: Border.all(
                      color: _selectedBlankWord != null ? AppColors.primary : Colors.grey[400]!,
                      style: _selectedBlankWord != null ? BorderStyle.solid : BorderStyle.none,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      if (_selectedBlankWord == null)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  child: _selectedBlankWord != null
                      ? Text(
                          _selectedBlankWord!,
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : Text(
                          '?',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              if (parts.length > 1)
                Text(
                  parts[1],
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Word Bank Chip grid
        Text(
          'SELECT CORRECT WORD:',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: choices.map((choice) {
            final isUsed = _selectedBlankWord == choice;

            return BounceWrapper(
              onTap: (_isChecked || isUsed) ? null : () {
                setState(() {
                  _selectedBlankWord = choice;
                });
              },
              child: Opacity(
                opacity: isUsed ? 0.35 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        choice,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _speakPhrase(choice),
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(Icons.volume_up_rounded,
                            size: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildListenCard(dynamic exercise, bool isDark) {
    final phraseText = exercise['target_language_text'] ?? '';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Giant Play Audio Button
            BounceWrapper(
              onTap: () => _speakPhrase(phraseText),
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(CupertinoIcons.volume_up, color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(width: 24),
            // Turtle "Slow Speech" Button
            BounceWrapper(
              onTap: () => _speakPhrase(phraseText, rate: 0.4),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.slow_motion_video_rounded, color: Colors.amber, size: 32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // Text field
        TextField(
          controller: _textController,
          enabled: !_isChecked,
          onChanged: (text) => setState(() {}),
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Type what you hear...',
            hintStyle: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeakCard(dynamic exercise, bool isDark) {
    final correctText = exercise['target_language_text'] ?? '';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Pronounce this out loud:',
                style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                correctText,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(CupertinoIcons.volume_up, color: AppColors.primary),
                onPressed: () => _speakPhrase(correctText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // Animated Microphone Speak Trigger (long-press to record)
        GestureDetector(
          onLongPressStart: (_) => _startListening(),
          onLongPressEnd: (_) => _stopListening(correctText),
          // Fall back: short tap kicks off the listener too for accessibility
          onTap: () async {
            if (_isChecked) return;
            if (!_sttAvailable) {
              setState(() {
                _voiceSpoken = true;
              });
            }
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecordingVoice ? Colors.redAccent.withValues(alpha: 0.2) : Colors.transparent,
                  border: Border.all(
                    color: _isRecordingVoice ? Colors.redAccent : AppColors.primary,
                    width: _isRecordingVoice ? 4 : 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecordingVoice ? Colors.redAccent : AppColors.primary,
                    ),
                    child: Icon(
                      _isRecordingVoice ? Icons.mic : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isRecordingVoice
                    ? 'Listening...'
                    : (_sttAvailable ? 'Hold to Speak' : 'Tap to Confirm'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _isRecordingVoice ? Colors.redAccent : AppColors.primary,
                ),
              ),
              if (_voiceTranscript.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"$_voiceTranscript"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startListening() async {
    if (_isChecked || !_sttAvailable) {
      if (!_sttAvailable) {
        setState(() => _voiceSpoken = true);
      }
      return;
    }
    setState(() {
      _isRecordingVoice = true;
      _voiceTranscript = '';
    });
    HapticFeedback.selectionClick();
    final localeId = _bcp47ForLanguage(widget.language);
    _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _voiceTranscript = r.recognizedWords;
        });
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  Future<void> _stopListening(String target) async {
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _voiceSpoken = _voiceTranscript.trim().isNotEmpty;
    });
  }

  String? _bcp47ForLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'french': return 'fr-FR';
      case 'spanish': return 'es-ES';
      case 'german': return 'de-DE';
      case 'italian': return 'it-IT';
      case 'portuguese': return 'pt-PT';
      case 'kiswahili':
      case 'swahili': return 'sw-KE';
      default: return null;
    }
  }

  double _levenshteinRatio(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (dist / maxLen);
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    final v0 = List<int>.filled(t.length + 1, 0);
    final v1 = List<int>.filled(t.length + 1, 0);
    for (var i = 0; i <= t.length; i++) {
      v0[i] = i;
    }
    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  Widget _buildBottomActionPanel(bool isDark) {
    final inputActive = _isAnswerInputted();

    if (!_isChecked) {
      // Normal checking bar
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            // Socratic Hint Dialog Button
            if (_exercises.isNotEmpty && _currentExerciseIndex < _exercises.length)
              IconButton(
                icon: const Icon(CupertinoIcons.lightbulb, color: Colors.amber, size: 28),
                onPressed: () {
                  final hint = _exercises[_currentExerciseIndex]['hint'] ?? 'Try your best!';
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          const Icon(CupertinoIcons.lightbulb_fill, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text('Socratic Hint', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      content: Text(hint, style: GoogleFonts.nunito(fontSize: 16)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Understood', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: inputActive ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                ),
                onPressed: inputActive ? _checkAnswer : null,
                child: Text(
                  'Check',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: inputActive ? Colors.white : (isDark ? Colors.white24 : const Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Answers checked bottom sheet representation
    final themeColor = _isAnswerCorrect ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final accentBg = _isAnswerCorrect 
        ? (isDark ? const Color(0x1522C55E) : const Color(0x0E22C55E))
        : (isDark ? const Color(0x15EF4444) : const Color(0x0EEF4444));

    final currentExercise = _exercises[_currentExerciseIndex];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: accentBg,
        border: Border(top: BorderSide(color: themeColor, width: 2.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isAnswerCorrect ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.clear_circled_solid,
                color: themeColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                _isAnswerCorrect ? 'Excellent job! You got it right' : 'Study this alternative:',
                style: GoogleFonts.poppins(
                  color: themeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isAnswerCorrect) ...[
            Text(
              'Correct Translation:',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              currentExercise['target_language_text'] ?? '',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            // Hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white70,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.lightbulb, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentExercise['hint'] ?? '',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              elevation: 0,
            ),
            onPressed: _nextExercise,
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScreen(ThemeData theme, bool isDark) {
    // Stars evaluation
    int starsCount = 3;
    String feedback = 'Absolute Perfection!';
    final int xp = _xp; // real earned XP

    if (_mistakesCount > 2) {
      starsCount = 1;
      feedback = 'Keep practicing, you will conquer this!';
    } else if (_mistakesCount > 0) {
      starsCount = 2;
      feedback = 'Fantastic effort, almost flawless!';
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Celebratory Header
              Text(
                'QUEST REWARDED!',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lessonTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),

              // Giant Star Display Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final active = index < starsCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 400 + (index * 200)),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Icon(
                            active ? CupertinoIcons.star_fill : CupertinoIcons.star,
                            color: active ? Colors.amber : Colors.grey[400],
                            size: index == 1 ? 72 : 54,
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Socratic Feedback Banner
              Text(
                feedback,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Finished with only $_mistakesCount mistake${_mistakesCount == 1 ? "" : "s"}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 48),

              // XP Reward Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.sparkles, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      '+$xp XP earned',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Complete quest button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                ),
                onPressed: () {
                  context.pop();
                },
                child: Text(
                  'Back to Quests',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper strings
  String _getExerciseTypeName(String type) {
    switch (type) {
      case 'fill_blank': return 'FILL IN THE BLANK';
      case 'translate_to_target': return 'TRANSLATION QUEST';
      case 'listen_and_type': return 'LISTENING QUEST';
      case 'speak_phrase': return 'SPEAKING QUEST';
      default: return 'LANGUAGE QUEST';
    }
  }

  String _getExerciseInstruction(String type, String prompt) {
    switch (type) {
      case 'fill_blank': return 'Complete the target sentence with the correct missing word:';
      case 'translate_to_target': return 'How do you translate: "$prompt"?';
      case 'listen_and_type': return 'Listen carefully and type the words you hear:';
      case 'speak_phrase': return 'Tap and hold to record your pronunciation:';
      default: return prompt;
    }
  }
}
