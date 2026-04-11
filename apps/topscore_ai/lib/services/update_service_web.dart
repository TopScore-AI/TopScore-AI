import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Polls /version.json and notifies listeners when a newer build is detected.
///
/// Usage:
///   UpdateService().startAutoCheck();
///   UpdateService().onUpdateAvailable.listen((_) => showUpdateBanner());
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  bool _isChecking = false;
  bool _isUpdateAvailable = false;
  Timer? _timer;
  String? _initialBuildTimestamp;
  DateTime _lastInteraction = DateTime.now();

  final _updateController = StreamController<void>.broadcast();

  /// Fires once when a new build is detected. Listen to show a banner.
  Stream<void> get onUpdateAvailable => _updateController.stream;

  /// Returns true if a newer build is detected but not yet applied.
  bool get isUpdateAvailable => _isUpdateAvailable;

  void startAutoCheck() {
    _captureInitialVersion();
    _timer?.cancel();
    
    // Listen for Service Worker updates directly
    _setupServiceWorkerListeners();

    // Check every 10 minutes — frequent enough without hammering the server
    _timer =
        Timer.periodic(const Duration(minutes: 10), (_) => checkForUpdate());

    // Record interaction to track idleness
    web.window.addEventListener('mousedown', (web.Event _) { _recordInteraction(); }.toJS);
    web.window.addEventListener('keydown', (web.Event _) { _recordInteraction(); }.toJS);
    web.window.addEventListener('touchstart', (web.Event _) { _recordInteraction(); }.toJS);
  }

  void _recordInteraction() {
    _lastInteraction = DateTime.now();
  }

  void _setupServiceWorkerListeners() async {
    try {
      // Listen for the controller changing (new SW taking over)
      web.window.navigator.serviceWorker.addEventListener('controllerchange', (web.Event _) {
        if (kDebugMode) debugPrint('[UpdateService] Controller changed — reloading...');
        web.window.location.reload();
      }.toJS);

      // Check for an already waiting service worker on startup
      final reg = await web.window.navigator.serviceWorker.getRegistration().toDart;
      if (reg != null && reg.waiting != null) {
        if (kDebugMode) debugPrint('[UpdateService] SW is waiting — notifying UI');
        _isUpdateAvailable = true;
        _updateController.add(null);
        _startIdleCheck();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateService] SW listener setup failed: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _updateController.close();
  }

  /// Automatically applies the update if one is available and it's a "safe" time.
  /// Call this during app navigation or other transitions.
  void checkAndAutoApplyOnNavigation(String location) async {
    if (!_isUpdateAvailable) return;

    // Only auto-reload if moving back to the home screen or if it's been
    // more than 1 hour since we detected the update.
    
    // For now, let's just do it if they return to home or if they've been idle for 5+ mins
    final idleDuration = DateTime.now().difference(_lastInteraction);
    
    if (location == '/home' || idleDuration > const Duration(minutes: 5)) {
      if (kDebugMode) debugPrint('[UpdateService] Applying update on navigation to $location');
      await applyUpdate();
    }
  }

  Future<void> _captureInitialVersion() async {
    try {
      final data = await _fetchVersionJson();
      if (data != null) {
        _initialBuildTimestamp = data['buildTimestamp'] as String?;
        if (kDebugMode) {
          debugPrint(
              '[UpdateService] Baseline: v${data['version']} @ $_initialBuildTimestamp');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateService] Initial capture failed: $e');
    }
  }

  Future<void> checkForUpdate() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final data = await _fetchVersionJson();
      if (data == null) return;

      final serverTimestamp = data['buildTimestamp'] as String? ?? '';

      if (_initialBuildTimestamp == null) {
        _initialBuildTimestamp = serverTimestamp;
        return;
      }

      if (serverTimestamp.isNotEmpty &&
          serverTimestamp != _initialBuildTimestamp) {
        if (kDebugMode) {
          debugPrint(
              '[UpdateService] New build: $_initialBuildTimestamp → $serverTimestamp');
        }
        _isUpdateAvailable = true;
        // Notify UI to show banner — don't auto-reload immediately
        _updateController.add(null);
        _timer?.cancel(); // Stop polling once update is detected
        
        // Start idle check to auto-reload
        _startIdleCheck();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateService] Check failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  void _startIdleCheck() {
    // Check every minute if the user is idle and an update is available
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isUpdateAvailable) {
        timer.cancel();
        return;
      }

      final idleDuration = DateTime.now().difference(_lastInteraction);
      // If idle for more than 20 minutes, auto-apply the update
      if (idleDuration > const Duration(minutes: 20)) {
        if (kDebugMode) debugPrint('[UpdateService] User idle for 20m, auto-updating...');
        timer.cancel();
        applyUpdate();
      }
    });
  }

  /// Call this when the user taps "Update" in the banner.
  Future<void> applyUpdate() async {
    try {
      final registrations =
          (await web.window.navigator.serviceWorker.getRegistrations().toDart)
              .toDart;
      for (final reg in registrations) {
        await reg.unregister().toDart;
      }
      final cacheKeys = (await web.window.caches.keys().toDart).toDart;
      for (final key in cacheKeys) {
        await web.window.caches.delete(key.toDart).toDart;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateService] Cache clear failed: $e');
    }
    web.window.location.reload();
  }

  Future<Map<String, dynamic>?> _fetchVersionJson() async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;
    final base = Uri.base;
    final uri = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: '/version.json',
      queryParameters: {'_': cacheBust.toString()},
    );

    final response = await http.get(uri, headers: const {
      'cache-control': 'no-cache, no-store',
      'pragma': 'no-cache',
    });

    if (response.statusCode != 200) return null;
    final body = response.body.trim();
    if (!body.startsWith('{')) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
