import 'package:shared_preferences/shared_preferences.dart';

class OnboardingTooltipService {
  static const String _prefix = 'onboarding_tooltip_';

  static final OnboardingTooltipService _instance =
      OnboardingTooltipService._internal();
  factory OnboardingTooltipService() => _instance;
  OnboardingTooltipService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  bool shouldShow(String featureId) {
    if (!_initialized) return false;
    return !(_prefs.getBool('$_prefix$featureId') ?? false);
  }

  Future<void> markAsSeen(String featureId) async {
    if (!_initialized) return;
    await _prefs.setBool('$_prefix$featureId', true);
  }

  Future<void> resetAll() async {
    if (!_initialized) return;
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
