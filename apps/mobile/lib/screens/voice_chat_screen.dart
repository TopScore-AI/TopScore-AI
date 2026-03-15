import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  Room? _room;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isMuted = false;
  double _localAudioLevel = 0.0;
  double _remoteAudioLevel = 0.0;

  // Siri-like animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Automatically start the service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connect();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  String _tokenServerUrl(String userId) =>
      ApiConfig.getGeminiLiveTokenUrl(userId);

  Future<void> _connect() async {
    if (_isConnecting || _isConnected) return;

    setState(() {
      _isConnecting = true;
    });

    // 1. Ask for mic permissions
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      developer.log("Microphone permission denied", name: "VoiceChatScreen");
      if (mounted) {
        setState(() => _isConnecting = false);

        if (kIsWeb) {
          _showWebMicPermissionGuide();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Microphone permission is required for TopScore AI Voice",
              ),
            ),
          );
        }
      }
      return;
    }

    try {
      // 2. Get Token from backend (secret stays server-side, client connects directly to LiveKit)
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
      final response = await http.get(Uri.parse(_tokenServerUrl(userId)));
      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.body}");
      }

      final data = jsonDecode(response.body);
      final String token = data['token'];
      final String url = data['url'];

      // 3. Connect to LiveKit
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await room.connect(url, token);

      // Listen for remote tracks (AI response)
      room.createListener().on<TrackSubscribedEvent>((event) {
        if (event.track is RemoteAudioTrack) {
          event.track.start();
          developer.log("Subscribed to remote audio track",
              name: "VoiceChatScreen");
        }
      });

      // Start audio playback for the room
      await room.startAudio();

      // Listen for active speakers (VAD)
      room.createListener().on<ActiveSpeakersChangedEvent>((event) {
        if (mounted) {
          setState(() {
            // Reset levels
            _localAudioLevel = 0.0;
            _remoteAudioLevel = 0.0;

            for (var participant in event.speakers) {
              if (participant is LocalParticipant) {
                _localAudioLevel = participant.audioLevel;
              } else {
                // Take the loudest remote speaker for the visualizer
                _remoteAudioLevel =
                    math.max(_remoteAudioLevel, participant.audioLevel);
              }
            }
          });
        }
      });

      // 4. Turn on Mic
      await room.localParticipant?.setMicrophoneEnabled(true);

      if (mounted) {
        setState(() {
          _room = room;
          _isConnected = true;
          _isConnecting = false;
          _isMuted = false;
        });
        // Haptic feedback for connection
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      developer.log("Connection failed: $e", name: "VoiceChatScreen");
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleMute() async {
    if (_room == null) return;
    final newMute = !_isMuted;
    await _room!.localParticipant?.setMicrophoneEnabled(!newMute);
    setState(() {
      _isMuted = newMute;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _disconnect() async {
    await _room?.disconnect();
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      Navigator.of(context).pop();
    }
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Immersive background
            _buildBackground(),

            // Content
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const Spacer(),
                  _buildVisualizer(),
                  const Spacer(),
                  _buildStatusText(),
                  const SizedBox(height: 40),
                  _buildControls(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF03001C), // Deep dark blue
            Color(0xFF0C134F), // Midnight blue
            Color(0xFF1D267D), // Dark purple hint
            Colors.black,
          ],
          stops: [0.0, 0.4, 0.8, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Subtle glowing orb top right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Subtle glowing orb bottom left
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70, size: 28),
          ),
          const SizedBox(width: 48), // Spacer to keep icon left
          const SizedBox(width: 48), // Spacer for center alignment
        ],
      ),
    );
  }

  Widget _buildVisualizer() {
    if (_isConnecting) {
      return const Column(
        children: [
          CircularProgressIndicator(color: Colors.blueAccent),
          SizedBox(height: 20),
          Text(
            "Initializing Session...",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      );
    }

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _waveController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 200 + (20 * _pulseController.value),
                height: 200 + (20 * _pulseController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _isMuted
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : Colors.blueAccent.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Siri-like orb
              CustomPaint(
                size: const Size(160, 160),
                painter: SiriOrbPainter(
                  pulse: _pulseController.value,
                  wave: _waveController.value,
                  isMuted: _isMuted,
                  localAudioLevel: _localAudioLevel,
                  remoteAudioLevel: _remoteAudioLevel,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusText() {
    String status = _isConnecting
        ? "Connecting..."
        : (_isMuted
            ? "Muted"
            : (_remoteAudioLevel > 0.05 ? "Speaking..." : "Listening..."));
    return Text(
      status,
      style: TextStyle(
        color:
            _isMuted ? Colors.redAccent : Colors.white.withValues(alpha: 0.8),
        fontSize: 22,
        fontWeight: FontWeight.w300,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute Toggle
        _buildGlassControlButton(
          onPressed: _toggleMute,
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          color: _isMuted ? Colors.redAccent : Colors.white,
          label: _isMuted ? "Unmute" : "Mute",
        ),

        // End Session
        _buildGlassControlButton(
          onPressed: _disconnect,
          icon: Icons.call_end,
          color: Colors.red,
          label: "End",
          isLarge: true,
        ),

        // Refresh/Re-connect (hidden if connected)
        Opacity(
          opacity: _isConnected ? 0.3 : 1.0,
          child: _buildGlassControlButton(
            onPressed: _isConnected ? null : _connect,
            icon: Icons.refresh,
            color: Colors.white,
            label: "Retry",
          ),
        ),
      ],
    );
  }

  Widget _buildGlassControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color color,
    required String label,
    bool isLarge = false,
  }) {
    double size = isLarge ? 80 : 60;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(icon, color: color, size: isLarge ? 36 : 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  void _showWebMicPermissionGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.mic_off, color: Colors.orange),
            SizedBox(width: 12),
            Text("Microphone Restricted"),
          ],
        ),
        content: const Text(
          "Your browser is blocking microphone access. To use live voice:\n\n"
          "1. Click the lock icon 🔒 next to the web address.\n"
          "2. Toggle the Microphone switch to \"Allow\".\n"
          "3. Refresh the page to start chatting!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _connect();
            },
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }
}

class SiriOrbPainter extends CustomPainter {
  final double pulse;
  final double wave;
  final bool isMuted;
  final double localAudioLevel;
  final double remoteAudioLevel;

  SiriOrbPainter({
    required this.pulse,
    required this.wave,
    required this.isMuted,
    required this.localAudioLevel,
    required this.remoteAudioLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.4;

    // Draw multiple layers
    for (int i = 0; i < 3; i++) {
      final paint = Paint()..style = PaintingStyle.fill;

      double layerOpacity = 0.4 - (i * 0.1);
      Color baseColor = isMuted
          ? Colors.redAccent
          : (i == 0
              ? const Color(0xFFD4ADFC)
              : (i == 1 ? const Color(0xFF5C469C) : const Color(0xFF1D267D)));

      paint.color = baseColor.withValues(alpha: layerOpacity);

      double layerPulse =
          math.sin((wave * 2 * math.pi) + (i * math.pi / 2)) * 10;

      // Scale based on audio levels (VAD)
      double levelScale =
          1.0 + (localAudioLevel * 2.0) + (remoteAudioLevel * 1.5);
      double radius = (baseRadius + (pulse * 5) + layerPulse) * levelScale;

      canvas.drawCircle(center, radius, paint);
    }

    // Core glow
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.8),
          (isMuted ? Colors.redAccent : Colors.blueAccent)
              .withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.5));

    canvas.drawCircle(center, baseRadius * 0.5 + (pulse * 2), corePaint);
  }

  @override
  bool shouldRepaint(covariant SiriOrbPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.wave != wave ||
      oldDelegate.isMuted != isMuted ||
      oldDelegate.localAudioLevel != localAudioLevel ||
      oldDelegate.remoteAudioLevel != remoteAudioLevel;
}
