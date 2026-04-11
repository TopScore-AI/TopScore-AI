import 'dart:typed_data';

/// No-op implementation for mobile/desktop.
void downloadBytesWeb(Uint8List bytes, String filename) {
  // Mobile doesn't use this, it uses SharePlus
}
