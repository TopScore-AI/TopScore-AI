import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web implementation for browser downloads.
void downloadBytesWeb(Uint8List bytes, String filename) {
  // Create a Blob from the bytes
  final blob = web.Blob([bytes.toJS].toJS);
  
  // Create an Object URL
  final url = web.URL.createObjectURL(blob);
  
  // Create a temporary hidden anchor element to trigger the download
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  
  // Append to body, click, and remove
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  
  // Cleanup the object URL
  web.URL.revokeObjectURL(url);
}
