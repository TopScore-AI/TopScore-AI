import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/multiplayer_service.dart';
import '../../providers/auth_provider.dart';
import 'multiplayer_quiz_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _multiplayerService = MultiplayerService();
    _joinRoom();
  }

  Future<void> _joinRoom() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    try {
      await _multiplayerService.joinRoom(
        roomCode: widget.roomCode,
        userId: user.uid,
        name: user.displayName,
      );
      
      _multiplayerService.roomStateStream.listen((data) {
        if (data['type'] == 'player_joined' || data['type'] == 'player_left') {
          // In a real app, the server would send the full list.
          // For now, we'll manually keep track or wait for a full sync msg.
          // For the MVP, we assume the server sends 'player_count'
          if (mounted) {
            setState(() {
              // Hack: server sends player info on join
              if (data['type'] == 'player_joined') {
                _players.add(data['player']);
              }
            });
          }
        } else if (data['type'] == 'game_started') {
          if (mounted) {
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
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join room: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    // We don't dispose the service here because it's passed to the next screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Multiplayer Lobby',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "JOIN CODE",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                widget.roomCode,
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ).animate().shimmer(duration: 2.seconds),
            const SizedBox(height: 48),
            Text(
              "PLAYERS JOINED",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  final player = _players[index];
                  return Card(
                    elevation: 0,
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        child: Text(player['name'][0].toUpperCase()),
                      ),
                      title: Text(player['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1);
                },
              ),
            ),
            if (widget.isHost)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _players.isNotEmpty ? () => _multiplayerService.startGame() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Start Game",
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            if (!widget.isHost)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Waiting for host to start..."),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
