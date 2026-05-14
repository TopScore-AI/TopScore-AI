import 'dart:async';
import 'p5_web_helper_stub.dart'
    if (dart.library.js_interop) 'p5_web_helper_web.dart' as impl;

/// Cross-platform listener for window postMessage events on the web.
/// Returns null on mobile/desktop.
StreamSubscription? listenToWebMessages(void Function(Map<String, dynamic> payload) onMessageReceived) {
  return impl.listenToWebMessagesImpl(onMessageReceived);
}
