import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import '../config/api_config.dart';
import '../shared/services/gemini_live_service.dart';
import '../shared/services/audio_service.dart';
import '../shared/utils/face_blur_utils.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  StreamSubscription<Uint8List>? _audioStreamSub;
  StreamSubscription? _amplitudeSub;
  final GeminiLiveService _geminiService = GeminiLiveService();
  final AudioService _audioService = AudioService();
  
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isMultimodal = false;
  Timer? _videoCaptureTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isMuted = false;
  double _localAudioLevel = 0.0;
  double _remoteAudioLevel = 0.0;
  
  String _lastAIResponse = "Listening...";
  String _lastUserMessage = "";
  late AnimationController _bgController;

  // Siri-like animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _setupGeminiListeners();

    // Automatically start the service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connect();
    });
  }

  void _setupGeminiListeners() {
    _geminiService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isConnected = status == GeminiLiveStatus.setupComplete;
          _isConnecting = status == GeminiLiveStatus.connecting || status == GeminiLiveStatus.connected;
        });
        
        if (status == GeminiLiveStatus.error) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gemini Live connection error"), backgroundColor: Colors.redAccent),
          );
        }
      }
    });

    _geminiService.audioStream.listen((base64Audio) {
      _audioService.playAudioFromBase64('data:audio/pcm;base64,$base64Audio');
      if (mounted) {
        setState(() {
          _remoteAudioLevel = 0.8; // Mock level for visualizer when AI speaks
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _remoteAudioLevel = 0.0);
        });
      }
    });

        _geminiService.interruptionStream.listen((_) {
      _audioService.stop();
      if (mounted) {
        setState(() {
          _remoteAudioLevel = 0.0;
          _lastAIResponse = "(Interrupted)";
        });
      }
    });

    _geminiService.transcriptionStream.listen((data) {
      if (mounted) {
        setState(() {
          if (data['type'] == 'output') {
            _lastAIResponse = data['text'];
          } else if (data['type'] == 'input') {
            _lastUserMessage = data['text'];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _bgController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _videoCaptureTimer?.cancel();
    _cameraController?.dispose();
    _amplitudeSub?.cancel();
    _audioStreamSub?.cancel();
    _geminiService.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_isConnecting || _isConnected) return;

    setState(() => _isConnecting = true);

    var micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission is required")),
        );
      }
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
      final response = await http.get(Uri.parse(ApiConfig.getGeminiLiveTokenUrl(userId)));
      
      if (response.statusCode != 200) throw Exception("Failed to get token");

      final data = jsonDecode(response.body);
      await _geminiService.connect(data['url'], data['token'], data['system_instruction'] ?? 'You are a helpful AI tutor.');

      final audioStream = await _audioService.startPcmStream();
      _audioStreamSub = audioStream?.listen((data) {
        if (!_isMuted && _isConnected) {
          final base64Pcm = base64Encode(data);
          _geminiService.sendAudio(base64Pcm);
        }
      });

      _amplitudeSub = _audioService.onAmplitudeChanged.listen((amp) {
        if (mounted && !_isMuted) {
          setState(() {
            final minDb = -50.0;
            if (amp.current < minDb) {
              _localAudioLevel = 0.0;
            } else {
              _localAudioLevel = 1.0 - (amp.current / minDb);
            }
          });
        } else if (mounted && _isMuted && _localAudioLevel > 0) {
          setState(() => _localAudioLevel = 0.0);
        }
      });
      
      HapticFeedback.mediumImpact();
    } catch (e) {
      developer.log("Connection failed: $e", name: "VoiceChatScreen");
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_isMultimodal) {
      _stopVideoStreaming();
    } else {
      await _startVideoStreaming();
    }
  }

  Future<void> _startVideoStreaming() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isMultimodal = true;
        });
        
        _videoCaptureTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (_isMultimodal && _isCameraInitialized && _isConnected) {
            try {
              final image = await _cameraController!.takePicture();
              final base64Image = await FaceBlurUtils.processAndBlurFaces(image.path);
              _geminiService.sendVideoFrame(base64Image);
            } catch (e) {
              developer.log("Error capturing frame: $e");
            }
          }
        });
      }
    } catch (e) {
      developer.log("Camera init failed: $e");
    }
  }

  void _stopVideoStreaming() {
    _videoCaptureTimer?.cancel();
    _cameraController?.dispose();
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        _isMultimodal = false;
      });
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    HapticFeedback.lightImpact();
  }

  Future<void> _disconnect() async {
    _amplitudeSub?.cancel();
    _audioStreamSub?.cancel();
    await _audioService.stopPcmStream();
    await _geminiService.disconnect();
    if (mounted) {
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
            _buildBackground(),
            if (_isMultimodal && _isCameraInitialized)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: CameraPreview(_cameraController!),
                ),
              ),

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
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                math.cos(_bgController.value * math.pi * 2),
                math.sin(_bgController.value * math.pi * 2),
              ),
              end: Alignment(
                math.cos((_bgController.value + 0.5) * math.pi * 2),
                math.sin((_bgController.value + 0.5) * math.pi * 2),
              ),
              colors: [
                const Color(0xFF03001C),
                Color.lerp(const Color(0xFF0C134F), const Color(0xFF1D267D), _bgController.value) ?? const Color(0xFF0C134F),
                Color.lerp(const Color(0xFF1D267D), const Color(0xFF5C469C), _bgController.value) ?? const Color(0xFF1D267D),
                Colors.black,
              ],
              stops: const [0.0, 0.4, 0.8, 1.0],
            ),
          ),
        );
      },
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
          IconButton(
            onPressed: _toggleCamera,
            icon: Icon(
              _isMultimodal ? Icons.videocam : Icons.videocam_off,
              color: _isMultimodal ? Colors.blueAccent : Colors.white70,
              size: 28,
            ),
          ),
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
            "Waking up TopScore AI...",
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
            : (_remoteAudioLevel > 0.05 ? "TopScore AI" : "Listening..."));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              status,
              key: ValueKey(status),
              style: TextStyle(
                color: _isMuted ? Colors.redAccent : Colors.white.withValues(alpha: 0.8),
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_lastUserMessage.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                '"$_lastUserMessage"',
                key: ValueKey(_lastUserMessage),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          if (_lastUserMessage.isNotEmpty) const SizedBox(height: 12),
          if (_lastAIResponse != "Listening..." && _lastAIResponse != "(Interrupted)")
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _lastAIResponse,
                key: ValueKey(_lastAIResponse),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 15, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildGlassControlButton(
          onPressed: _toggleMute,
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          color: _isMuted ? Colors.redAccent : Colors.white,
          label: _isMuted ? "Unmute" : "Mute",
        ),
        _buildGlassControlButton(
          onPressed: _disconnect,
          icon: Icons.call_end,
          color: Colors.red,
          label: "End",
          isLarge: true,
        ),
        _buildGlassControlButton(
          onPressed: _toggleCamera,
          icon: _isMultimodal ? Icons.videocam : Icons.videocam_off,
          color: _isMultimodal ? Colors.blueAccent : Colors.white,
          label: _isMultimodal ? "Vision ON" : "Vision OFF",
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

    for (int i = 0; i < 3; i++) {
      final paint = Paint()..style = PaintingStyle.fill;
      double layerOpacity = 0.4 - (i * 0.1);
      Color baseColor = isMuted
          ? Colors.redAccent
          : (i == 0
              ? const Color(0xFFD4ADFC)
              : (i == 1 ? const Color(0xFF5C469C) : const Color(0xFF1D267D)));

      paint.color = baseColor.withValues(alpha: layerOpacity);
      double layerPulse = math.sin((wave * 2 * math.pi) + (i * math.pi / 2)) * 10;
      double levelScale = 1.0 + (localAudioLevel * 2.0) + (remoteAudioLevel * 1.5);
      double radius = (baseRadius + (pulse * 5) + layerPulse) * levelScale;
      canvas.drawCircle(center, radius, paint);
    }

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.8),
          (isMuted ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.5));

    canvas.drawCircle(center, baseRadius * 0.5 + (pulse * 2), corePaint);
  }

  @override
  bool shouldRepaint(covariant SiriOrbPainter oldDelegate) => true;
}










