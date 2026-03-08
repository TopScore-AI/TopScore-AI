import 'package:camera/camera.dart';

class CameraResult {
  final XFile file;
  final bool isLens;

  CameraResult({required this.file, required this.isLens});
}
