import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_theme.dart';
import '../services/offline_service.dart';

class SettingsProvider with ChangeNotifier {
  final OfflineService? _offlineService = kIsWeb ? null : OfflineService();
  bool _isLiteMode = false;
  ThemeMode _themeMode = ThemeMode.light; // Default to Light Mode
  double _fontSize = 14.0;
  double _lineHeight = 1.5;

  bool get isLiteMode => _isLiteMode;
  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    if (!kIsWeb && _offlineService != null) {
      _isLiteMode = _offlineService.getLiteMode();
    }
    // In a real app, save/load theme mode from SharedPreferences here
    notifyListeners();
  }

  Future<void> toggleLiteMode(bool value) async {
    _isLiteMode = value;
    if (!kIsWeb && _offlineService != null) {
      await _offlineService.saveLiteMode(value);
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
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
