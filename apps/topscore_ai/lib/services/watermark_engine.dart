import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Lightweight on-device steganographic watermarking engine.
///
/// Embeds a cryptographic payload into the Least Significant Bits (LSB) of the
/// blue channel of image pixels. The human eye cannot detect a 1-value
/// difference in a 0–255 RGB scale, making the watermark invisible.
///
/// **Important:** The invisible watermark only survives in lossless formats
/// (PNG). JPEG compression will destroy the LSB data. Always export as PNG.
class TopScoreWatermarkEngine {
  static const String _terminator = '[END]';
  static const String _prefix = 'TS_AI';

  /// Builds a standardized watermark payload.
  ///
  /// Format: `TS_AI|{userId}|{epochMs}`
  static String buildPayload(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$_prefix|$userId|$timestamp';
  }

  /// Embeds a hidden payload into image pixels using LSB steganography.
  ///
  /// Runs in an isolate via [compute] to avoid blocking the UI thread
  /// on budget devices. Returns PNG-encoded bytes with the watermark
  /// embedded, or `null` if the image could not be decoded.
  static Future<Uint8List?> embedInvisibleWatermark(
    Uint8List imageBytes,
    String payload,
  ) async {
    return compute(_embedIsolate, _EmbedParams(imageBytes, payload));
  }

  /// Extracts a hidden payload from a watermarked PNG image.
  ///
  /// Returns the decoded payload string, or a descriptive error message
  /// if no watermark is found or the image is corrupted.
  static Future<String> extractInvisibleWatermark(Uint8List imageBytes) async {
    return compute(_extractIsolate, imageBytes);
  }

  // ---------------------------------------------------------------------------
  // Isolate entry points (top-level-compatible static methods)
  // ---------------------------------------------------------------------------

  static Uint8List? _embedIsolate(_EmbedParams params) {
    final img.Image? image = img.decodeImage(params.imageBytes);
    if (image == null) return null;

    final String secret = '${params.payload}$_terminator';

    // Convert to binary string: each char → 8-bit binary
    final StringBuffer binaryBuf = StringBuffer();
    for (final int cu in secret.codeUnits) {
      binaryBuf.write(cu.toRadixString(2).padLeft(8, '0'));
    }
    final String binary = binaryBuf.toString();

    // Check capacity: we need one pixel per bit (blue channel LSB only)
    if (binary.length > image.width * image.height) {
      // Image too small for the payload — encode what fits
      return null;
    }

    int idx = 0;
    for (int y = 0; y < image.height && idx < binary.length; y++) {
      for (int x = 0; x < image.width && idx < binary.length; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();

        // Clear the LSB of blue and set our hidden bit
        final int bit = binary.codeUnitAt(idx) - 48; // '0'→0, '1'→1
        final int newBlue = (b & 0xFE) | bit;

        image.setPixelRgb(x, y, r, g, newBlue);
        idx++;
      }
    }

    return img.encodePng(image);
  }

  static String _extractIsolate(Uint8List imageBytes) {
    final img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return 'Error: could not decode image';

    final StringBuffer extractedBinary = StringBuffer();
    final StringBuffer message = StringBuffer();

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final int b = image.getPixel(x, y).b.toInt();
        extractedBinary.write(b & 1);

        if (extractedBinary.length == 8) {
          final int charCode = int.parse(extractedBinary.toString(), radix: 2);
          message.writeCharCode(charCode);
          extractedBinary.clear();

          final String soFar = message.toString();
          if (soFar.endsWith(_terminator)) {
            return soFar.substring(0, soFar.length - _terminator.length);
          }
        }
      }
    }

    return 'No watermark found or image corrupted.';
  }
}

/// Parameter wrapper for the embed isolate (must be a single argument).
class _EmbedParams {
  final Uint8List imageBytes;
  final String payload;
  const _EmbedParams(this.imageBytes, this.payload);
}
