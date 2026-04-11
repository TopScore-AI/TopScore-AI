import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageProcessor {
  /// Converts HEIC (and other formats) to a compressed JPEG
  /// This handles the "Edge Conversion" strategy to ensure cross-platform preview support
  /// and reduced bandwidth usage for students.
  static Future<File?> prepareImageForUpload(File originalFile) async {
    final originalPath = originalFile.path;
    
    // Get a temporary directory to store the converted image
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path, 
      'upload_${DateTime.now().millisecondsSinceEpoch}.jpg'
    );

    try {
      // Compress and Convert
      // flutter_image_compress automatically handles HEIC -> JPEG translation
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        quality: 80, // High enough for TopScore AI, small enough for 3G networks
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) return null;
      
      return File(compressedFile.path);
    } catch (e) {
      // If compression fails, fallback to original or handle error
      return originalFile;
    }
  }
}
