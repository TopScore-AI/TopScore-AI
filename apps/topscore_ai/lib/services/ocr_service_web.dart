import 'package:flutter/foundation.dart';

class OCRService {
  static Future<String?> extractTextFromPath(String path) async {
    if (kDebugMode) {
      debugPrint('OCR: Web OCR is not implemented. Fallback to AI vision if needed.');
    }
    // Web OCR usually requires Tesseract.js via dart:js or similar.
    // For now, return null to signify no text was extracted locally.
    return null;
  }

  static void dispose() {}
}
