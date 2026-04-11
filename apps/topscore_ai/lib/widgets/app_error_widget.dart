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

  @override
  Widget build(BuildContext context) {
    final bool isOffline = details?.toString().contains('SocketException') ?? false;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E1B4B), // Indigo 950
                ],
              ),
            ),
          ),
          
          // Animated decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: _buildDecorativeCircle(Colors.blueAccent.withValues(alpha: 0.15), 300),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildDecorativeCircle(Colors.purpleAccent.withValues(alpha: 0.1), 250),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon/Emoji with Glass background
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            isOffline ? '📡' : '🚀',
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Title
                    Text(
                      title ?? (isOffline ? 'Connection Lost' : 'Houston, we have a problem'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Message
                    Text(
                      message ?? (isOffline 
                        ? 'It looks like you\'re offline. Check your connection to keep learning with TopScore AI.'
                        : 'An unexpected hiccup occurred. Our team of space monkeys is currently investigating.'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.6,
                      ),
                    ),

                    if (details != null && !isOffline) ...[
                      const SizedBox(height: 32),
                      // Technical Details (Collapsed/Small)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Text(
                          details.toString().split('\n').first,
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),

                    // Action Buttons
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: onRetry ?? () {
                            // If no custom retry, just try to pop or go home
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              // We can't use context.go here without importing GoRouter
                              // But this widget is often used where GoRouter is available
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            isOffline ? 'Try Reconnecting' : 'Try Again',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            try {
                              // Try to use GoRouter to go home
                              if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                            } catch (e) {
                              Navigator.of(context).pushReplacementNamed('/home');
                            }
                          },
                          child: Text(
                            'Back to Safety',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildDecorativeCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

