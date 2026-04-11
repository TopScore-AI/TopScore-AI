import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// Use @JS interop instead of extension type (which requires Dart 3.3+
// and breaks isar_generator's bundled analyzer 3.1.0)
@JS('grecaptcha.enterprise.execute')
external JSPromise<JSString> _executeRecaptcha(
    JSString siteKey, JSObject options);

class RecaptchaService {
  // Replace with your actual Site Key
  static const String _siteKey = "6LcgGEIsAAAAAHXWC6Wq75smJnr8fhr2VjI3eLB7";
  static bool _scriptLoaded = false;
  static Completer<void>? _loadingCompleter;

  /// Dynamically load reCAPTCHA script only when needed (auth pages)
  static Future<void> loadRecaptchaScript() async {
    if (!kIsWeb) return;

    // If already loaded or loading, return/wait
    if (_scriptLoaded) return;
    if (_loadingCompleter != null) return _loadingCompleter!.future;

    _loadingCompleter = Completer<void>();

    try {
      final script =
          web.document.createElement('script') as web.HTMLScriptElement
            ..src =
                'https://www.google.com/recaptcha/enterprise.js?render=$_siteKey'
            ..async = true;

      script.onload = (web.Event event) {
        _scriptLoaded = true;
        _loadingCompleter?.complete();
        if (kDebugMode) debugPrint('RecaptchaService: Script loaded successfully');
      }.toJS;

      script.onerror = (web.Event event) {
        _loadingCompleter?.completeError('Failed to load reCAPTCHA script');
        _loadingCompleter = null;
      }.toJS;

      web.document.head?.appendChild(script);

      await _loadingCompleter!.future;
    } catch (e) {
      if (kDebugMode) debugPrint('RecaptchaService: Error loading script - $e');
      _loadingCompleter?.completeError(e);
      _loadingCompleter = null;
      rethrow;
    }
  }

  Future<String?> getToken(String action) async {
    // 1. Platform Check
    if (!kIsWeb) {
      if (kDebugMode) debugPrint("RecaptchaService: Not running on Web.");
      return null;
    }

    try {
      // 2. Ensure script is loaded
      if (!_scriptLoaded) {
        await loadRecaptchaScript();
      }

      // 3. Check if 'grecaptcha' exists on the global window object
      if (!globalContext.has('grecaptcha')) {
        if (kDebugMode) {
          debugPrint(
            "RecaptchaService: 'grecaptcha' script not loaded.",
          );
        }
        return null;
      }

      // 4. Check enterprise object exists
      final grecaptcha = globalContext['grecaptcha'] as JSObject?;
      if (grecaptcha == null || !grecaptcha.has('enterprise')) {
        if (kDebugMode) debugPrint("RecaptchaService: 'grecaptcha.enterprise' is missing.");
        return null;
      }

      // 5. Prepare options: { action: 'LOGIN' }
      final options = JSObject();
      options['action'] = action.toJS;

      // 6. Execute and convert Promise to Future
      final JSString result =
          await _executeRecaptcha(_siteKey.toJS, options).toDart;

      // 7. Return the raw token string
      return result.toDart;
    } catch (e) {
      if (kDebugMode) debugPrint("RecaptchaService Error: $e");
      return null;
    }
  }
}
