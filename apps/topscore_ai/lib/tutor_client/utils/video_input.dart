import 'dart:async';
import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class VideoInput extends ChangeNotifier {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool controllerInitialized = false;
  Timer? _captureTimer;
  StreamController<Uint8List> _imageStreamController =
      StreamController<Uint8List>.broadcast();
  bool _isStreaming = false;

  List<CameraDescription> get cameras => _cameras;
  CameraController? get cameraController => _cameraController;

  Future<void> init() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      log('Error getting available cameras: $e');
    }
  }

  @override
  void dispose() {
    stopStreamingImages();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> initializeCameraController() async {
    if (_cameras.isEmpty) return;

    if (controllerInitialized && _cameraController != null) {
      await _cameraController!.dispose();
      controllerInitialized = false;
    }

    _cameraController = CameraController(
      _cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _cameraController!.initialize();
      controllerInitialized = true;
      notifyListeners();
    } catch (e) {
      log('Error initializing camera: $e');
    }
  }

  Stream<Uint8List> startStreamingImages() {
    if (_cameraController == null || !controllerInitialized) {
      return _imageStreamController.stream;
    }

    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final controller = _cameraController;
      if (controller == null ||
          !controller.value.isInitialized ||
          !_isStreaming) {
        await stopStreamingImages();
        return;
      }
      try {
        if (controller.value.isTakingPicture) return;
        final XFile imageFile = await controller.takePicture();

        // Compress image to avoid saturating the WebSocket and causing audio jitter
        final Uint8List imageBytes = await imageFile.readAsBytes();

        // Check if controller is still open before adding
        if (!_imageStreamController.isClosed && _isStreaming) {
          _imageStreamController.add(imageBytes);
        }
      } catch (e) {
        log('Error taking picture: $e');
      }
    });
    _isStreaming = true;
    return _imageStreamController.stream;
  }

  Future<void> stopStreamingImages() async {
    if (!_isStreaming) return;

    // Cancel timer first to prevent new captures
    _captureTimer?.cancel();
    _captureTimer = null;
    _isStreaming = false;

    // Then close stream controller safely
    if (!_imageStreamController.isClosed) {
      await _imageStreamController.close();
    }
    _imageStreamController = StreamController<Uint8List>.broadcast();

    // Finally dispose camera
    await _cameraController?.dispose();
    _cameraController = null;
    controllerInitialized = false;
    notifyListeners();
  }

  Future<void> flipCamera() async {
    if (_cameras.length < 2) return;
    final current = _cameraController?.description;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection != current?.lensDirection,
      orElse: () => _cameras.first,
    );
    await _cameraController?.dispose();
    _cameraController = CameraController(
      next,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await _cameraController!.initialize();
      controllerInitialized = true;
      notifyListeners();
    } catch (e) {
      log('Error flipping camera: $e');
    }
  }
}
