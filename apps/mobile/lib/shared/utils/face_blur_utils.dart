import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceBlurUtils {
  static Future<String> processAndBlurFaces(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faceDetector = FaceDetector(options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
    ));

    final List<Face> faces = await faceDetector.processImage(inputImage);
    faceDetector.close();

    if (faces.isEmpty) {
      final bytes = await File(imagePath).readAsBytes();
      return base64Encode(bytes);
    }

    // Process image in isolate to prevent jank
    final base64Image = await compute(_blurFacesInIsolate, {
      'path': imagePath,
      'faces': faces.map((f) => {
        'left': f.boundingBox.left,
        'top': f.boundingBox.top,
        'width': f.boundingBox.width,
        'height': f.boundingBox.height,
      }).toList(),
    });

    return base64Image;
  }

  static String _blurFacesInIsolate(Map<String, dynamic> data) {
    final String path = data['path'];
    final List<Map<String, dynamic>> facesData = List<Map<String, dynamic>>.from(data['faces']);
    
    final bytes = File(path).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(bytes);
    
    if (originalImage != null) {
      for (var face in facesData) {
        int x = (face['left'] as double).toInt().clamp(0, originalImage.width - 1);
        int y = (face['top'] as double).toInt().clamp(0, originalImage.height - 1);
        int w = (face['width'] as double).toInt().clamp(1, originalImage.width - x);
        int h = (face['height'] as double).toInt().clamp(1, originalImage.height - y);
        
        // Ensure valid dimensions
        if (w > 0 && h > 0) {
          // Add padding to bounding box
          int padding = 15;
          int px = (x - padding).clamp(0, originalImage.width - 1);
          int py = (y - padding).clamp(0, originalImage.height - 1);
          int pw = (w + padding * 2).clamp(1, originalImage.width - px);
          int ph = (h + padding * 2).clamp(1, originalImage.height - py);

          img.Image faceRegion = img.copyCrop(originalImage, x: px, y: py, width: pw, height: ph);
          faceRegion = img.gaussianBlur(faceRegion, radius: 30);
          img.compositeImage(originalImage, faceRegion, dstX: px, dstY: py);
        }
      }
      final blurredBytes = img.encodeJpg(originalImage, quality: 70);
      return base64Encode(blurredBytes);
    }
    
    return base64Encode(bytes);
  }
}
