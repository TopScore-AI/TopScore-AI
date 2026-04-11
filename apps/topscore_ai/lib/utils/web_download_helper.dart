import 'dart:typed_data';
import 'web_download_helper_stub.dart'
    if (dart.library.js_interop) 'web_download_helper_web.dart' as impl;

/// Cross-platform helper for triggering browser-native file downloads on the web.
/// On mobile/desktop, these methods are no-ops.
class WebDownloadHelper {
  /// Triggers a browser download for the given [bytes] with the specified [filename].
  static void downloadBytes(Uint8List bytes, String filename) {
    impl.downloadBytesWeb(bytes, filename);
  }
}
