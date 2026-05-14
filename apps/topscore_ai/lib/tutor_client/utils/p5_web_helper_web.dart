import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart' as web_pkg;

/// Web-specific implementation of the web message listener.
StreamSubscription? listenToWebMessagesImpl(void Function(Map<String, dynamic> payload) onMessageReceived) {
  return web_pkg.window.onMessage.listen((web_pkg.MessageEvent event) {
    final data = event.data;
    if (data != null) {
      try {
        final dynamic payload = data;
        if (payload is Map) {
          onMessageReceived(Map<String, dynamic>.from(payload));
        } else {
          final String rawStr = payload.toString();
          if (rawStr.contains('"type"')) {
            final decoded = jsonDecode(rawStr);
            if (decoded is Map) {
              onMessageReceived(Map<String, dynamic>.from(decoded));
            }
          }
        }
      } catch (e) {
        // Quietly ignore unrelated postMessages
      }
    }
  });
}
