import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_result.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInit = false;
  bool _isLensMode = true; // Default to Lens Mode
  bool _isCapturing = false;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_scanController);
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras[0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInit = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();

    try {
      final XFile file = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, CameraResult(file: file, isLens: _isLensMode));
      }
    } catch (e) {
      debugPrint("Capture error: $e");
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Center(
            child: CameraPreview(_controller!),
          ),

          // Scan Overlay Animation (Lens Mode)
          if (_isLensMode && !_isCapturing)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Moving Line
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.2 +
                          (MediaQuery.of(context).size.height *
                              0.5 *
                              _scanAnimation.value),
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                          gradient: LinearGradient(
                            colors: [
                              Colors.cyanAccent.withValues(alpha: 0),
                              Colors.cyanAccent,
                              Colors.cyanAccent.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Corners
                    _buildCorners(),
                  ],
                );
              },
            ),

          // Top Controls
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            _isLensMode ? Colors.cyanAccent : Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLensMode ? Icons.auto_awesome : Icons.camera_alt,
                        color: _isLensMode ? Colors.cyanAccent : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isLensMode ? "AI LENS MODE" : "PHOTO MODE",
                        style: TextStyle(
                          color: _isLensMode ? Colors.cyanAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48), // Spacer to balance the close button
              ],
            ),
          ),

          // Mode Selector & Capture Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Mode Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeButton("PHOTO", !_isLensMode),
                      _buildModeButton("LENS", _isLensMode),
                    ],
                  ),
                ),

                // Capture Button
                GestureDetector(
                  onTap: _takePicture,
                  child: _isCapturing
                      ? const CircularProgressIndicator(
                          color: Colors.cyanAccent)
                      : Container(
                          height: 80,
                          width: 80,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLensMode
                                  ? Colors.cyanAccent
                                  : Colors.white,
                            ),
                            child: Icon(
                              _isLensMode ? Icons.bolt : Icons.camera_alt,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isLensMode ? "Point & Solve" : "Snap to Chat",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => _isLensMode = label == "LENS");
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCorners() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Stack(
          children: [
            // Top Left
            Positioned(top: 0, left: 0, child: _corner(top: true, left: true)),
            // Top Right
            Positioned(
                top: 0, right: 0, child: _corner(top: true, left: false)),
            // Bottom Left
            Positioned(
                bottom: 0, left: 0, child: _corner(top: false, left: true)),
            // Bottom Right
            Positioned(
                bottom: 0, right: 0, child: _corner(top: false, left: false)),
          ],
        ),
      ),
    );
  }

  Widget _corner({required bool top, required bool left}) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: Colors.cyanAccent, width: 4)
              : BorderSide.none,
          bottom: !top
              ? BorderSide(color: Colors.cyanAccent, width: 4)
              : BorderSide.none,
          left: left
              ? BorderSide(color: Colors.cyanAccent, width: 4)
              : BorderSide.none,
          right: !left
              ? BorderSide(color: Colors.cyanAccent, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }
}
