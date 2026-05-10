import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class NavigationProvider extends ChangeNotifier {
  // Data to pass to Chat Screen (e.g. from PDF Snap & Solve)
  String? _pendingMessage;
  XFile? _pendingImage;

  String? get pendingMessage => _pendingMessage;
  XFile? get pendingImage => _pendingImage;

  /// Store message/image data to be consumed by the AI Tutor screen
  void setPendingData({String? message, XFile? image}) {
    _pendingMessage = message;
    _pendingImage = image;
    notifyListeners();
  }

  /// Clear data after Chat Screen consumes it
  void clearPendingData() {
    _pendingMessage = null;
    _pendingImage = null;
    // We don't notifyListeners here to avoid rebuild loops during build/initState
  }
}
