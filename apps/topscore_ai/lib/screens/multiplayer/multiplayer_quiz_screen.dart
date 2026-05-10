import '../../constants/colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/multiplayer_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_spinner.dart';

// ─── Kahoot colour palette ────────────────────────────────────────────────────
const _kColors = [
  Color(0xFFE21B3C), // Red   – triangle
  Color(0xFF1368CE), // Blue  – diamond
  Color(0xFFD89E00), // Yellow– circle
  Color(0xFF26890C), // Green – square
];
const _kIcons = [
  Icons.change_history_rounded,
  Icons.diamond_rounded,
  Icons.circle_rounded,
  Icons.square_rounded,
];

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

class _MultiplayerQuizScreenState extends State<MultiplayerQuizScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  int? _selectedAnswerIndex;
  bool _hasSubmitted = false;
  int? _correctAnswerIndex; // revealed after submission / time-up
  int _pointsEarned = 0;
  bool _showPointsPopup = false;

  List<Map<String, dynamic>> _leaderboard = [];
  bool _showLeaderboard = false;
  bool _isFinalLeaderboard = false;

  int _timeLeft = 20;
  int _totalTime = 20;
  Timer? _countdownTimer;

  // Countdown animation controller
  late AnimationController _timerAnim;
  late AnimationController _questionAnim;

  @override
  void initState() {
    super.initState();

    _timerAnim =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _questionAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    widget.multiplayerService.roomStateStream.listen(_onServerEvent);
  }

  void _onServerEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'];

    if (type == 'new_question') {
      setState(() {
        _selectedAnswerIndex = null;
        _hasSubmitted = false;
        _correctAnswerIndex = null;
        _pointsEarned = 0;
        _showPointsPopup = false;
        _showLeaderboard = false;
        _totalTime = data['duration'] ?? 20;
        _timeLeft = _totalTime;
      });
      _questionAnim.forward(from: 0);
      _startTimer();
    } else if (type == 'answer_result') {
      // Backend tells us if we were right and how many points
      final correct = data['correct_index'] as int?;
      final pts = data['points_earned'] as int? ?? 0;
      setState(() {
        _correctAnswerIndex = correct;
        _pointsEarned = pts;
        _showPointsPopup = pts > 0;
        _countdownTimer?.cancel();
      });
      if (pts > 0) HapticFeedback.mediumImpact();
      // Hide popup after 2s
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showPointsPopup = false);
      });
    } else if (type == 'intermediate_leaderboard') {
      setState(() {
        _leaderboard = List<Map<String, dynamic>>.from(data['leaderboard']);
        _showLeaderboard = true;
        _isFinalLeaderboard = false;
        _countdownTimer?.cancel();
      });
    } else if (type == 'game_finished') {
      setState(() {
        _leaderboard = List<Map<String, dynamic>>.from(data['leaderboard']);
        _showLeaderboard = true;
        _isFinalLeaderboard = true;
        _countdownTimer?.cancel();
      });
      _awardXp(_leaderboard);
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _timerAnim.duration = Duration(seconds: _totalTime);
    _timerAnim.forward(from: 0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _submitAnswer(int index) {
    if (_hasSubmitted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedAnswerIndex = index;
      _hasSubmitted = true;
    });
    _countdownTimer?.cancel();
    widget.multiplayerService.submitAnswer(
      widget.multiplayerService.currentQuestionIndex,
      index,
    );
  }

  void _awardXp(List<Map<String, dynamic>> lb) {
    try {
      final auth = context.read<AuthProvider>();
      final user = auth.userModel;
      if (user == null) return;
      final name = user.preferredName ?? user.displayName;
      final rank = lb.indexWhere((p) => p['name'] == name);
      if (rank == -1) return;
      final xp = rank == 0
          ? 100
          : rank == 1
              ? 50
              : rank == 2
                  ? 25
                  : 10;
      auth.awardXp(xp, 'Multiplayer Quiz – Rank ${rank + 1}');
    } catch (_) {}
  }

  Future<void> _confirmExit(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(
          widget.isHost ? "End Game?" : "Leave Game?",
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          widget.isHost
              ? "This will end the multiplayer quiz for everyone."
              : "Are you sure you want to leave this quiz?",
          style: GoogleFonts.nunito(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(widget.isHost ? "End Game" : "Leave"),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerAnim.dispose();
    _questionAnim.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showLeaderboard) {
      return _LeaderboardScreen(
        leaderboard: _leaderboard,
        isFinal: _isFinalLeaderboard,
        isHost: widget.isHost,
        onNext: () => widget.multiplayerService.nextQuestion(),
        onExit: () => _confirmExit(context),
      );
    }

    final service = widget.multiplayerService;
    final question = service.currentQuestion;

    if (question == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: AppSpinner(color: Colors.white),
        ),
      );
    }

    final isUrgent = _timeLeft <= 5 && !_hasSubmitted;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // 1. Background Blobs for Premium Depth
          Positioned(
            top: -100,
            left: -50,
            child: _Blob(
              color: AppColors.primaryPurple.withValues(alpha: 0.15),
              size: 300,
            ),
          ),
          Positioned(
            bottom: 50,
            right: -50,
            child: _Blob(
              color: AppColors.accentTeal.withValues(alpha: 0.1),
              size: 250,
            ),
          ),

          // 2. Main content ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(service),
                _buildTimerBar(isUrgent),
                const SizedBox(height: 16),
                _buildQuestionCard(question.questionText),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildAnswerGrid(question.options),
                ),
                if (_hasSubmitted) _buildWaitingBanner(),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // 3. Points popup ──────────────────────────────────────────────────
          if (_showPointsPopup) _PointsPopup(points: _pointsEarned),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(MultiplayerService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => _confirmExit(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  service.topic,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Q ${service.currentQuestionIndex + 1}',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Timer number
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _timeLeft <= 5
                  ? Colors.redAccent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$_timeLeft',
                style: GoogleFonts.outfit(
                  color: _timeLeft <= 5 ? Colors.redAccent : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Timer bar ──────────────────────────────────────────────────────────────
  Widget _buildTimerBar(bool isUrgent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AnimatedBuilder(
        animation: _timerAnim,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _totalTime > 0 ? _timeLeft / _totalTime : 0,
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              isUrgent ? Colors.redAccent : const Color(0xFF6366F1),
            ),
          ),
        ),
      ),
    );
  }

  // ── Question card ──────────────────────────────────────────────────────────
  Widget _buildQuestionCard(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.backgroundDark,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ).animate(controller: _questionAnim).fadeIn().slideY(begin: -0.15),
    );
  }

  // ── Answer grid ────────────────────────────────────────────────────────────
  Widget _buildAnswerGrid(List<String> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemCount: options.length,
        itemBuilder: (_, i) => _AnswerTile(
          text: options[i],
          index: i,
          color: _kColors[i % _kColors.length],
          icon: _kIcons[i % _kIcons.length],
          isSelected: _selectedAnswerIndex == i,
          isCorrect: _correctAnswerIndex == i,
          isWrong: _hasSubmitted &&
              _correctAnswerIndex != null &&
              _selectedAnswerIndex == i &&
              _correctAnswerIndex != i,
          isLocked: _hasSubmitted,
          onTap: () => _submitAnswer(i),
          delay: Duration(milliseconds: 80 * i),
        ),
      ),
    );
  }

  // ── Waiting banner ─────────────────────────────────────────────────────────
  Widget _buildWaitingBanner() {
    final color = _selectedAnswerIndex != null
        ? _kColors[_selectedAnswerIndex! % _kColors.length]
        : Colors.white24;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: AppSpinner(strokeWidth: 2, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Text(
            'Answer locked in! Waiting for others…',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.3);
  }
}

// ─── Answer tile ──────────────────────────────────────────────────────────────
class _AnswerTile extends StatelessWidget {
  final String text;
  final int index;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isLocked;
  final VoidCallback onTap;
  final Duration delay;

  const _AnswerTile({
    required this.text,
    required this.index,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    required this.isLocked,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    // Dim tiles that weren't selected once locked
    final dimmed = isLocked && !isSelected && !isCorrect;
    final effectiveColor = isCorrect
        ? Colors.green.shade600
        : isWrong
            ? Colors.red.shade700
            : color;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: dimmed ? 0.35 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              effectiveColor,
              effectiveColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!dimmed)
              BoxShadow(
                color: effectiveColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: isLocked ? null : onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white24,
            child: Stack(
              children: [
                // Watermark shape
                Positioned(
                  right: -12,
                  bottom: -12,
                  child: Icon(icon,
                      size: 72, color: Colors.white.withValues(alpha: 0.12)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon or result indicator
                      if (isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 22)
                      else if (isWrong)
                        const Icon(Icons.cancel_rounded,
                            color: Colors.white, size: 22)
                      else
                        Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(height: 8),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Selection border
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay, duration: 250.ms).scale(
          delay: delay,
          duration: 300.ms,
          begin: const Offset(0.85, 0.85),
          curve: Curves.easeOutBack,
        );
  }
}

// ─── Points popup ─────────────────────────────────────────────────────────────
class _PointsPopup extends StatelessWidget {
  final int points;
  const _PointsPopup({required this.points});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.6), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎯', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  '+$points pts',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                  ),
                ),
                Text(
                  'Correct!',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 350.ms,
                  curve: Curves.easeOutBack)
              .fadeIn(duration: 200.ms),
        ),
      ),
    );
  }
}

// ─── Leaderboard screen ───────────────────────────────────────────────────────
class _LeaderboardScreen extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard;
  final bool isFinal;
  final bool isHost;
  final VoidCallback onNext;
  final VoidCallback onExit;

  const _LeaderboardScreen({
    required this.leaderboard,
    required this.isFinal,
    required this.isHost,
    required this.onNext,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // 1. Background Blobs
          Positioned(
            top: -100,
            right: -50,
            child: _Blob(
              color: AppColors.primaryPurple.withValues(alpha: 0.15),
              size: 300,
            ),
          ),
          Positioned(
            bottom: 50,
            left: -50,
            child: _Blob(
              color: AppColors.accentTeal.withValues(alpha: 0.1),
              size: 250,
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Title
                Text(
                  isFinal ? '🏆  FINAL RESULTS' : '📊  LEADERBOARD',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ).animate().fadeIn().slideY(begin: -0.2),

                if (!isFinal && leaderboard.any((p) => (p['streak'] ?? 0) >= 3))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '🔥  Someone\'s on fire!',
                      style: GoogleFonts.inter(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(),
                  ),

                const SizedBox(height: 20),

                // Podium (top 3)
                if (leaderboard.isNotEmpty)
                  _buildPodium(leaderboard).animate().fadeIn(delay: 200.ms).scale(
                      begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),

                const SizedBox(height: 16),

                // Rest of players
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount:
                        leaderboard.length > 3 ? leaderboard.length - 3 : 0,
                    itemBuilder: (_, i) {
                      final p = leaderboard[i + 3];
                      return _buildPlayerRow(p, i + 4)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 80 * i))
                          .slideX(begin: 0.1);
                    },
                  ),
                ),

                // Action button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: isFinal
                      ? SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context)
                                .popUntil((r) => r.isFirst),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.backgroundDark,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            child: Text(
                              'Back to Home',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                        )
                      : isHost
                          ? Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: onNext,
                                    icon: const Icon(Icons.arrow_forward_rounded),
                                    label: Text(
                                      'Next Question',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: onExit,
                                    icon: const Icon(Icons.stop_rounded),
                                    label: Text(
                                      'End Game Early',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(
                                          color: Colors.redAccent),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Text(
                                  'Waiting for host…',
                                  style: GoogleFonts.inter(
                                      color: Colors.white54,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: onExit,
                                  icon: const Icon(Icons.exit_to_app, size: 18),
                                  label: const Text('Leave Game'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.redAccent),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> lb) {
    // Order: 2nd | 1st | 3rd
    final slots = [
      if (lb.length >= 2) (lb[1], 2, 90.0, Colors.grey.shade400),
      (lb[0], 1, 130.0, const Color(0xFFFFD700)),
      if (lb.length >= 3) (lb[2], 3, 70.0, const Color(0xFFCD7F32)),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: slots.map((s) {
        final (player, rank, height, color) = s;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _PodiumSlot(
              player: player, rank: rank, height: height, color: color),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> p, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(p['avatar'] ?? '👤', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if ((p['streak'] ?? 0) >= 2)
                  Text(
                    '${p['streak']} in a row 🔥',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          Text(
            '${p['score']} pts',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final double height;
  final Color color;

  const _PodiumSlot({
    required this.player,
    required this.rank,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final streak = player['streak'] ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (streak >= 3)
          const Text('🔥', style: TextStyle(fontSize: 20))
              .animate(onPlay: (c) => c.repeat())
              .shake(duration: 600.ms),
        Text(player['avatar'] ?? '👤', style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            player['name'] ?? '',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (streak >= 2)
          Text(
            '$streak streak!',
            style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 6),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$rank',
                style: GoogleFonts.outfit(
                  fontSize: rank == 1 ? 36 : 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                '${player['score']} pts',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
