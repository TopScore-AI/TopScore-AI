import '../../constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../services/multiplayer_service.dart';
import '../../providers/auth_provider.dart';
import 'multiplayer_quiz_screen.dart';

// Kahoot-style avatar colours — one per player slot
const _avatarColors = [
  Color(0xFFE21B3C),
  Color(0xFF1368CE),
  Color(0xFFD89E00),
  Color(0xFF26890C),
  Color(0xFF9B59B6),
  Color(0xFFE67E22),
  Color(0xFF1ABC9C),
  Color(0xFFE91E63),
];

class MultiplayerLobbyScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;
  final String? hostId;

  const MultiplayerLobbyScreen({
    super.key,
    required this.roomCode,
    this.isHost = false,
    this.hostId,
  });

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  late MultiplayerService _multiplayerService;
  final List<Map<String, dynamic>> _players = [];
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _isHost = widget.isHost;
    _multiplayerService = MultiplayerService();
    _joinRoom();
  }

  Future<void> _joinRoom() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    try {
      _multiplayerService.roomStateStream.listen((data) {
        if (!mounted) return;

        setState(() {
          if (data['type'] == 'room_state') {
            _players.clear();
            _players.addAll(List<Map<String, dynamic>>.from(data['players']));
            _isHost = data['is_host'] ?? _isHost;
          } else if (data['type'] == 'player_joined') {
            final newPlayer = Map<String, dynamic>.from(data['player']);
            if (!_players.any((p) => p['id'] == newPlayer['id'])) {
              _players.add(newPlayer);

              if (widget.isHost && newPlayer['id'] != user.uid) {
                _notifyPlayerJoined(newPlayer['name']);
              }
            }
          } else if (data['type'] == 'player_left') {
            _players.removeWhere((p) => p['id'] == data['user_id']);
          } else if (data['type'] == 'game_started') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MultiplayerQuizScreen(
                  multiplayerService: _multiplayerService,
                  isHost: widget.isHost,
                ),
              ),
            );
          }
        });
      });

      await _multiplayerService.joinRoom(
        roomCode: widget.roomCode,
        userId: user.uid,
        name: user.preferredName ?? user.displayName,
      );

      // Immediately sync if service already received initial state
      if (_multiplayerService.players.isNotEmpty) {
        setState(() {
          _players.clear();
          _players.addAll(_multiplayerService.players);
          _isHost = _multiplayerService.players
              .any((p) => p['id'] == user.uid && p['is_host'] == true);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join room: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _notifyPlayerJoined(String name) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.person_add_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text("$name joined the game!",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareRoomCode() {
    final text = "Join my TopScore AI Quiz! Code: ${widget.roomCode}";
    SharePlus.instance.share(ShareParams(text: text));
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    // We don't dispose the service here because it's passed to the next screen
    super.dispose();
  }

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

          // 2. Main content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              _multiplayerService.topic,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'JOIN CODE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _copyRoomCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 40,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.roomCode,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 12,
                            color: Colors.white,
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(duration: 2500.ms, color: Colors.white24)
                          .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.02, 1.02),
                              duration: 2000.ms,
                              curve: Curves.easeInOut),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SmallActionButton(
                          icon: Icons.copy_rounded,
                          label: 'Copy',
                          onTap: _copyRoomCode,
                          isCopy: true,
                        ),
                        const SizedBox(width: 16),
                        _SmallActionButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          onTap: _shareRoomCode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${_players.length} player${_players.length == 1 ? "" : "s"} joined',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _players.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Lottie.asset('assets/lottie/loading.json',
                                    height: 80),
                                const SizedBox(height: 12),
                                Text('Waiting for players...',
                                    style: GoogleFonts.inter(
                                        color: Colors.white38, fontSize: 14)),
                              ],
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 100,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: _players.length,
                              itemBuilder: (_, i) {
                                final p = _players[i];
                                final color =
                                    _avatarColors[i % _avatarColors.length];
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            color,
                                            color.withValues(alpha: 0.7)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color:
                                                  color.withValues(alpha: 0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 6))
                                        ],
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          width: 2.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          p['avatar'] ??
                                              (p['name'] as String)
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 32,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      (p['name'] as String).split(' ').first,
                                      style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (p['is_host'] == true)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text('HOST',
                                            style: GoogleFonts.inter(
                                                color: Colors.amber,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5)),
                                      ),
                                  ],
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: Duration(milliseconds: 60 * i))
                                    .scale(
                                        begin: const Offset(0.5, 0.5),
                                        curve: Curves.easeOutBack);
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: _isHost
                          ? Column(
                              children: [
                                if (_players.length < 2)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                        'Need at least 2 players to start',
                                        style: GoogleFonts.plusJakartaSans(
                                            color: Colors.redAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                Container(
                                  width: double.infinity,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    gradient: _players.length >= 2
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF26890C),
                                              Color(0xFF2ECC71)
                                            ],
                                          )
                                        : null,
                                    color: _players.length < 2
                                        ? Colors.white10
                                        : null,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      if (_players.length >= 2)
                                        BoxShadow(
                                          color: const Color(0xFF26890C)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _players.length >= 2
                                        ? () => _multiplayerService.startGame()
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                    ),
                                    child: Text('Start Game  ▶',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5)),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Lottie.asset('assets/lottie/loading.json',
                                    height: 56),
                                Text('Waiting for host to start...',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isCopy;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isCopy = false,
  });

  @override
  State<_SmallActionButton> createState() => _SmallActionButtonState();
}

class _SmallActionButtonState extends State<_SmallActionButton> {
  bool _isActive = false;

  void _handleTap() {
    widget.onTap();
    if (widget.isCopy) {
      setState(() => _isActive = true);
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isActive = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isActive ? null : _handleTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isActive
              ? AppColors.accentTeal.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isActive
                ? AppColors.accentTeal.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(_isActive),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isActive ? Icons.check_rounded : widget.icon,
                size: 16,
                color: _isActive ? AppColors.accentTeal : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                _isActive ? 'Copied' : widget.label,
                style: GoogleFonts.plusJakartaSans(
                  color: _isActive ? AppColors.accentTeal : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
