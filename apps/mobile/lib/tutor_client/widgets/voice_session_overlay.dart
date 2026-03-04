import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';

/// Voice conversation phase — drives the UI state machine.
enum VoicePhase { listening, thinking, responding }

class VoiceSessionOverlay extends StatefulWidget {
  final VoicePhase phase;
  final String transcription;
  final double amplitude; // raw dB, typically -50 to 0
  final VoidCallback onClose;
  final VoidCallback onInterrupt;
  final CameraController? cameraController;
  final bool showCamera;
  final bool isMuted;
  final VoidCallback? onMuteToggle;

  const VoiceSessionOverlay({
    super.key,
    required this.phase,
    required this.transcription,
    required this.amplitude,
    required this.onClose,
    required this.onInterrupt,
    this.cameraController,
    this.showCamera = false,
    this.isMuted = false,
    this.onMuteToggle,
  });

  @override
  State<VoiceSessionOverlay> createState() => _VoiceSessionOverlayState();
}

class _VoiceSessionOverlayState extends State<VoiceSessionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _thinkingController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _thinkingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _thinkingController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  double get _normalizedAmplitude =>
      ((widget.amplitude + 50) / 50).clamp(0.0, 1.0);

  Color get _phaseColor {
    if (widget.isMuted && widget.phase == VoicePhase.listening) {
      return const Color(0xFFFF9800); // amber when muted
    }
    switch (widget.phase) {
      case VoicePhase.listening:
        return const Color(0xFF00C853); // green
      case VoicePhase.thinking:
        return const Color(0xFFFF9800); // amber
      case VoicePhase.responding:
        return const Color(0xFF6C63FF); // purple
    }
  }

  String get _statusText {
    if (widget.isMuted && widget.phase == VoicePhase.listening) return 'Muted';
    switch (widget.phase) {
      case VoicePhase.listening:
        return 'Listening...';
      case VoicePhase.thinking:
        return 'Thinking...';
      case VoicePhase.responding:
        return 'Speaking...';
    }
  }

  String get _subtitleText {
    if (widget.isMuted && widget.phase == VoicePhase.listening) {
      return 'Tap mic to unmute';
    }
    switch (widget.phase) {
      case VoicePhase.listening:
        return "Speak naturally, I'm listening";
      case VoicePhase.thinking:
        return 'Processing your message';
      case VoicePhase.responding:
        return 'Tap anywhere to interrupt';
    }
  }

  IconData get _phaseIcon {
    if (widget.isMuted && widget.phase == VoicePhase.listening) {
      return Icons.mic_off;
    }
    switch (widget.phase) {
      case VoicePhase.listening:
        return Icons.mic;
      case VoicePhase.thinking:
        return Icons.more_horiz;
      case VoicePhase.responding:
        return Icons.graphic_eq;
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap:
            widget.phase == VoicePhase.responding ? widget.onInterrupt : null,
        child: Stack(
          children: [
            // Layer 0: Camera preview or dark background
            Positioned.fill(child: _buildBackground()),

            // Layer 1: Blur + dark scrim
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ),

            // Layer 2: Content
            SafeArea(
              child: Stack(
                children: [
                  // LIVE badge
                  _buildLiveBadge(),

                  // Phase indicator (top)
                  _buildPhaseIndicator(),

                  // Centre orb
                  Center(child: _buildOrb()),

                  // Amplitude bars (below orb)
                  if (widget.phase == VoicePhase.listening && !widget.isMuted)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.of(context).size.height * 0.35,
                      child: _buildAmplitudeBars(),
                    ),

                  // Status + subtitle
                  Positioned(
                    bottom: 150,
                    left: 0,
                    right: 0,
                    child: _buildStatus(),
                  ),

                  // Close button
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: _buildCloseButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ──────────────────────────────────────────────────

  Widget _buildBackground() {
    if (widget.showCamera &&
        widget.cameraController != null &&
        widget.cameraController!.value.isInitialized) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: widget.cameraController!.value.previewSize?.height ?? 1,
            height: widget.cameraController!.value.previewSize?.width ?? 1,
            child: CameraPreview(widget.cameraController!),
          ),
        ),
      );
    }
    return Container(color: Colors.black);
  }

  Widget _buildLiveBadge() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4444).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing dot
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                          alpha: 0.5 + _pulseController.value * 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    return Positioned(
      top: 56,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPhaseDot(VoicePhase.listening, 'Listen'),
          _buildPhaseConnector(VoicePhase.listening),
          _buildPhaseDot(VoicePhase.thinking, 'Think'),
          _buildPhaseConnector(VoicePhase.thinking),
          _buildPhaseDot(VoicePhase.responding, 'Respond'),
        ],
      ),
    );
  }

  Widget _buildPhaseDot(VoicePhase phase, String label) {
    final isActive = widget.phase == phase;
    final isPast = widget.phase.index > phase.index;
    final color = isActive
        ? _phaseColor
        : isPast
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.25);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 12 : 8,
          height: isActive ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5), blurRadius: 8)
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseConnector(VoicePhase afterPhase) {
    final isPast = widget.phase.index > afterPhase.index;
    return Container(
      width: 30,
      height: 1.5,
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      color: isPast
          ? Colors.white.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildOrb() {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_pulseController, _rotationController, _thinkingController]),
      builder: (_, __) {
        double scale;
        double glowIntensity;

        switch (widget.phase) {
          case VoicePhase.listening:
            // Pulse with amplitude
            scale = 1.0 +
                (_normalizedAmplitude * 0.35) +
                (_pulseController.value * 0.05);
            glowIntensity = 0.25 + _normalizedAmplitude * 0.5;
          case VoicePhase.thinking:
            // Gentle breathing
            scale = 0.9 + (_thinkingController.value * 0.1);
            glowIntensity = 0.2 + _thinkingController.value * 0.15;
          case VoicePhase.responding:
            // Lively pulse
            scale = 1.0 + (_pulseController.value * 0.15);
            glowIntensity = 0.35 + _pulseController.value * 0.25;
        }

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(_rotationController.value * 2 * pi),
                colors: const [
                  Color(0xFF4285F4),
                  Color(0xFF9B72CB),
                  Color(0xFFD96570),
                  Color(0xFF4285F4),
                ],
                stops: const [0.0, 0.33, 0.66, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _phaseColor.withValues(alpha: glowIntensity),
                  blurRadius: 50 + (_normalizedAmplitude * 40),
                  spreadRadius: 10 + (_normalizedAmplitude * 15),
                ),
              ],
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: Icon(
                    _phaseIcon,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmplitudeBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        // Vary bar heights for a waveform look
        final variation = [0.6, 0.85, 1.0, 0.9, 1.0, 0.75, 0.55][i];
        final height = 12.0 + (_normalizedAmplitude * 44.0 * variation);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: _phaseColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildStatus() {
    return Column(
      children: [
        Text(
          _statusText,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _subtitleText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mute / unmute button
        if (widget.onMuteToggle != null) ...[
          InkWell(
            onTap: widget.onMuteToggle,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: widget.isMuted
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isMuted
                      ? Colors.orange.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(
                widget.isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
        // End call button
        InkWell(
          onTap: widget.onClose,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}
