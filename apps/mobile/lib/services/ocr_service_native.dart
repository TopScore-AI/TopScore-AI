import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<String?> extractTextFromPath(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String text = recognizedText.text;
      
      if (kDebugMode) {
        debugPrint('OCR Result: $text');
      }
      
      return text.isEmpty ? null : text;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OCR Error: $e');
      }
      return null;
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
