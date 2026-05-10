import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_theme.dart';
import '../services/offline_service.dart';

class SettingsProvider with ChangeNotifier {
  final OfflineService _offlineService = OfflineService();

  ThemeMode _themeMode = ThemeMode.light; // Default to Light Mode
  double _fontSize = 14.0;
  double _lineHeight = 1.5;

  // Lite Mode is always ON to save data
  bool get isLiteMode => true;
  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    // _isLiteMode = _offlineService.getLiteMode(); // No longer needed as we force true
    _themeMode = _offlineService.getThemeMode();
    notifyListeners();
  }

  Future<void> toggleLiteMode(bool value) async {
    // Force true regardless of input
    if (!kIsWeb) {
      await _offlineService.saveLiteMode(true);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _offlineService.saveThemeMode(mode);
    AppTheme.clearCache();
    notifyListeners();
  }

  // Language Settings
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void setFontSize(double size) {
    if (_fontSize == size) return;
    _fontSize = size;
    AppTheme.clearCache();
    notifyListeners();
  }

  void setLineHeight(double height) {
    if (_lineHeight == height) return;
    _lineHeight = height;
    AppTheme.clearCache();
    notifyListeners();
  }
}
