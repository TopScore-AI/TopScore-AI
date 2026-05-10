import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized service for managing app permissions
/// Handles camera, microphone, storage, notifications, and other permissions
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    if (kIsWeb) return true; // Web handles permissions differently
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission
  /// Returns true if granted, false otherwise
  Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;

    final status = await Permission.camera.status;

    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true;

    final status = await Permission.microphone.status;

    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Check if storage/photos permission is granted
  Future<bool> hasStoragePermission() async {
    if (kIsWeb) return true;

    // Android 13+ uses granular media permissions
    if (defaultTargetPlatform == TargetPlatform.android) {
      final photos = await Permission.photos.status;
      return photos.isGranted;
    }

    // iOS uses photos permission
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  /// Request storage/photos permission
  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;

    Permission permission = Permission.photos;

    final status = await permission.status;

    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final result = await permission.request();
    return result.isGranted;
  }

  /// Check if notification permission is granted
  Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;

    final status = await Permission.notification.status;

    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Request both camera and microphone permissions (for video calls)
  Future<Map<String, bool>> requestCameraAndMicrophone() async {
    if (kIsWeb) {
      return {'camera': true, 'microphone': true};
    }

    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    return {
      'camera': statuses[Permission.camera]?.isGranted ?? false,
      'microphone': statuses[Permission.microphone]?.isGranted ?? false,
    };
  }

  /// Check if any permission is permanently denied
  Future<bool> isCameraPermanentlyDenied() async {
    if (kIsWeb) return false;
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  Future<bool> isMicrophonePermanentlyDenied() async {
    if (kIsWeb) return false;
    final status = await Permission.microphone.status;
    return status.isPermanentlyDenied;
  }

  Future<bool> isStoragePermanentlyDenied() async {
    if (kIsWeb) return false;
    final status = await Permission.photos.status;
    return status.isPermanentlyDenied;
  }

  Future<bool> isNotificationPermanentlyDenied() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.status;
    return status.isPermanentlyDenied;
  }

  /// Open app settings (for when permissions are permanently denied)
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Request all essential permissions at once
  /// Returns a map of permission name to granted status
  Future<Map<String, bool>> requestAllEssentialPermissions() async {
    if (kIsWeb) {
      return {
        'camera': true,
        'microphone': true,
        'storage': true,
        'notifications': true,
      };
    }

    final results = <String, bool>{};

    // Request camera
    results['camera'] = await requestCameraPermission();

    // Request microphone
    results['microphone'] = await requestMicrophonePermission();

    // Request storage/photos
    results['storage'] = await requestStoragePermission();

    // Request notifications
    results['notifications'] = await requestNotificationPermission();

    if (kDebugMode) {
      debugPrint('[PermissionService] Permission results: $results');
    }

    return results;
  }

  /// Get status of all permissions
  Future<Map<String, PermissionStatus>> getAllPermissionStatuses() async {
    if (kIsWeb) {
      return {
        'camera': PermissionStatus.granted,
        'microphone': PermissionStatus.granted,
        'storage': PermissionStatus.granted,
        'notifications': PermissionStatus.granted,
      };
    }

    return {
      'camera': await Permission.camera.status,
      'microphone': await Permission.microphone.status,
      'storage': await Permission.photos.status,
      'notifications': await Permission.notification.status,
    };
  }

  /// Check if all essential permissions are granted
  Future<bool> hasAllEssentialPermissions() async {
    if (kIsWeb) return true;

    final camera = await hasCameraPermission();
    final microphone = await hasMicrophonePermission();
    final storage = await hasStoragePermission();
    final notifications = await hasNotificationPermission();

    return camera && microphone && storage && notifications;
  }

  /// Get a user-friendly message for permission rationale
  String getPermissionRationale(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'TopScore AI needs camera access to scan documents, take photos for homework help, and participate in video study sessions.';
      case Permission.microphone:
        return 'TopScore AI needs microphone access for voice chat with the AI tutor and video study sessions with classmates.';
      case Permission.photos:
        return 'TopScore AI needs access to your photos to help you upload images of homework, notes, and study materials.';
      case Permission.notification:
        return 'TopScore AI sends you study reminders, class notifications, and updates about your learning progress.';
      case Permission.storage:
        return 'TopScore AI needs storage access to save and access your study materials offline.';
      default:
        return 'TopScore AI needs this permission to provide you with the best learning experience.';
    }
  }
}
