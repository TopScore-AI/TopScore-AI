import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/colors.dart';
import '../services/permission_service.dart';

/// Shows a dialog explaining why a permission is needed
/// and provides options to grant or deny
class PermissionDialog extends StatelessWidget {
  final Permission permission;
  final String title;
  final String? customMessage;
  final VoidCallback? onGranted;
  final VoidCallback? onDenied;

  const PermissionDialog({
    super.key,
    required this.permission,
    required this.title,
    this.customMessage,
    this.onGranted,
    this.onDenied,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final permissionService = PermissionService();

    final message =
        customMessage ?? permissionService.getPermissionRationale(permission);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
      title: Row(
        children: [
          Icon(
            _getPermissionIcon(),
            color: AppColors.topscoreBlue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
            onDenied?.call();
          },
          child: Text(
            'Not Now',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.hintColor,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop(true);
            final granted = await _requestPermission();
            if (granted) {
              onGranted?.call();
            } else {
              onDenied?.call();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.topscoreBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Allow',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getPermissionIcon() {
    switch (permission) {
      case Permission.camera:
        return Icons.camera_alt_rounded;
      case Permission.microphone:
        return Icons.mic_rounded;
      case Permission.photos:
      case Permission.storage:
        return Icons.photo_library_rounded;
      case Permission.notification:
        return Icons.notifications_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  Future<bool> _requestPermission() async {
    final permissionService = PermissionService();

    switch (permission) {
      case Permission.camera:
        return await permissionService.requestCameraPermission();
      case Permission.microphone:
        return await permissionService.requestMicrophonePermission();
      case Permission.photos:
      case Permission.storage:
        return await permissionService.requestStoragePermission();
      case Permission.notification:
        return await permissionService.requestNotificationPermission();
      default:
        final status = await permission.request();
        return status.isGranted;
    }
  }

  /// Show the permission dialog
  static Future<bool?> show(
    BuildContext context, {
    required Permission permission,
    required String title,
    String? customMessage,
    VoidCallback? onGranted,
    VoidCallback? onDenied,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDialog(
        permission: permission,
        title: title,
        customMessage: customMessage,
        onGranted: onGranted,
        onDenied: onDenied,
      ),
    );
  }
}

/// Shows a dialog when permission is permanently denied
/// Offers to open app settings
class PermissionDeniedDialog extends StatelessWidget {
  final String title;
  final String message;

  const PermissionDeniedDialog({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
      title: Row(
        children: [
          Icon(
            Icons.block_rounded,
            color: AppColors.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.topscoreBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.topscoreBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.topscoreBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can enable this permission in your device settings.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.topscoreBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.hintColor,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop(true);
            await openAppSettings();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.topscoreBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Open Settings',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Show the permission denied dialog
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDeniedDialog(
        title: title,
        message: message,
      ),
    );
  }
}
