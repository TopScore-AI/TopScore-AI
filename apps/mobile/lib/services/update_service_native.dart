import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

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
  String? _currentLocalVersion;

  final _updateController = StreamController<void>.broadcast();

  /// Fires once when a new build is detected. Listen to show a banner.
  Stream<void> get onUpdateAvailable => _updateController.stream;

  /// Returns true if a newer build is detected but not yet applied.
  bool get isUpdateAvailable => _isUpdateAvailable;

  void startAutoCheck() async {
    _timer?.cancel();
    
    // Check on startup
    await checkForUpdate();

    // Check frequently (configured in AppConfig)
    _timer = Timer.periodic(AppConfig.updateCheckInterval, (_) => checkForUpdate());
  }

  void dispose() {
    _timer?.cancel();
    _updateController.close();
  }

  /// No-op on native for auto-apply — we must ask the user to go to the store.
  void checkAndAutoApplyOnNavigation(String location) {}

  Future<void> checkForUpdate() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      if (_currentLocalVersion == null) {
        final packageInfo = await PackageInfo.fromPlatform();
        _currentLocalVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      }

      final data = await _fetchVersionJson();
      if (data == null) return;

      final serverVersion = data['version'] as String? ?? '';

      if (serverVersion.isNotEmpty && serverVersion != _currentLocalVersion) {
        if (kDebugMode) {
          debugPrint('[UpdateService] Update available: $_currentLocalVersion → $serverVersion');
        }
        _isUpdateAvailable = true;
        _updateController.add(null);
        _timer?.cancel(); // Stop polling once update is detected
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateService] Check failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Opens the App Store or Play Store.
  Future<void> applyUpdate() async {
    final String storeUrl;
    if (Platform.isAndroid) {
      storeUrl = AppConfig.playStoreUrl;
    } else if (Platform.isIOS) {
      storeUrl = AppConfig.appStoreUrl;
    } else {
      return;
    }

    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<Map<String, dynamic>?> _fetchVersionJson() async {
    // We use the same central version.json used by the web app
    final uri = Uri.parse('https://agent.topscoreapp.ai/version.json');
    final response = await http.get(uri, headers: const {
      'cache-control': 'no-cache, no-store',
      'pragma': 'no-cache',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
