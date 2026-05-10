import 'package:flutter/foundation.dart';

/// Helper for web-specific page visibility detection
/// Uses a simpler approach without dart:html to avoid deprecation warnings
class WebVisibilityHelper {
  static void setupPageUnloadHandler(VoidCallback onPageUnload) {
    if (!kIsWeb) return;

    // For web, we rely on the AppLifecycleState.detached event
    // which is triggered when the page is being unloaded
    // This is handled in the WidgetsBindingObserver.didChangeAppLifecycleState

    // Note: Direct access to window.beforeunload requires dart:html which is deprecated
    // Flutter's AppLifecycleState.detached provides the same functionality
    if (kDebugMode) {
      debugPrint(
          'WebVisibilityHelper: Using AppLifecycleState for page unload detection');
    }
  }
}
