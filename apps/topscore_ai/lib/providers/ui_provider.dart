import 'package:flutter/material.dart';

class UIProvider with ChangeNotifier {
  bool _isCalculatorOpen = false;

  bool get isCalculatorOpen => _isCalculatorOpen;

  void toggleCalculator() {
    _isCalculatorOpen = !_isCalculatorOpen;
    notifyListeners();
  }

  void openCalculator() {
    if (!_isCalculatorOpen) {
      _isCalculatorOpen = true;
      notifyListeners();
    }
  }

  void closeCalculator() {
    if (_isCalculatorOpen) {
      _isCalculatorOpen = false;
      notifyListeners();
    }
  }
}
