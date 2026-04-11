import 'package:flutter/services.dart';

class HapticsService {
  static final HapticsService instance = HapticsService._internal();
  HapticsService._internal();

  void lightImpact() {
    HapticFeedback.lightImpact();
  }

  void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  void selectionClick() {
    HapticFeedback.selectionClick();
  }

  void success() {
    // Standard success pattern: light, then medium
    lightImpact();
    Future.delayed(const Duration(milliseconds: 100), () => mediumImpact());
  }

  void error() {
    // Standard error pattern: heavy, heavy
    heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => heavyImpact());
  }
}
