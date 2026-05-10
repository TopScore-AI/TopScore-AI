import '../../constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

/// A premium, brand-aligned error fallback widget for TopScore-AI.
/// Used for both GoRouter errorBuilder and global FlutterError.onError.
class AppErrorWidget extends StatelessWidget {
  final Object? details;
  final VoidCallback? onRetry;
  final String? title;
  final String? message;

  const AppErrorWidget({
    super.key,
    this.details,
    this.onRetry,
    this.title,
    this.message,
  });

  /// Shows the error as a centered popup dialog.
  static Future<void> show(
    BuildContext context, {
    Object? details,
    VoidCallback? onRetry,
    String? title,
    String? message,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => AppErrorWidget(
        details: details,
        onRetry: onRetry,
        title: title,
        message: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSocketError =
        details?.toString().contains('SocketException') ?? false;
    final bool isConnectionRefused =
        details?.toString().contains('Connection refused') ?? false;

    // A SocketException usually means no internet, BUT it could also be a wrong URL/Server down.
    // We treat it as "Offline" only if it's not a "Connection refused" (which implies the server was reached but rejected).
    final bool isOffline = isSocketError && !isConnectionRefused;

    final content = Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Container
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isOffline ? Colors.amber : Colors.redAccent)
                            .withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isOffline ? '📡' : '🚀',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    title ??
                        (isOffline
                            ? 'Connection Lost'
                            : (isSocketError
                                ? 'Server Unreachable'
                                : 'Houston, we have a problem')),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Message
                  Text(
                    message ??
                        (isOffline
                            ? 'It looks like you\'re offline. Check your connection to keep learning.'
                            : (isSocketError
                                ? 'We can\'t reach the TopScore AI servers right now. Please check your internet or try again later.'
                                : 'An unexpected hiccup occurred. Our team is investigating.')),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  if (details != null && !isOffline) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        details.toString().split('\n').first,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.firaCode(
                          fontSize: 10,
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Dismiss',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: onRetry ??
                              () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isOffline ? 'Retry' : 'Try Again',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // If used as a standalone screen (e.g. GoRouter errorBuilder), wrap in Scaffold
    if (ModalRoute.of(context)?.isCurrent == false ||
        Navigator.canPop(context) == false) {
      return Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        body: content,
      );
    }

    return content;
  }
}


