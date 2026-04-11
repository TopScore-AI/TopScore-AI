import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/recovery_service.dart';
import 'dart:developer' as developer;

class LoadingScreen extends StatefulWidget {
  final String? status;
  const LoadingScreen({super.key, this.status});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final List<String> _tips = [
    "Exploring Kenyan CBC & KCSE past papers...",
    "TopScore AI matches official KICD guidelines.",
    "Learning is 10x faster with AI-powered feedback.",
    "Practice makes perfect. Try a daily quiz!",
    "Your personalized AI tutor is getting ready...",
  ];
  late String _currentTip;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _currentTip = _tips[0];
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentTip = _tips[timer.tick % _tips.length];
        });
      }
    });

    // Ensure the native splash is removed only after we are ready to animate
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Check for recovery state (Background Kill lifeline)
      final recovery = await RecoveryService.getRecoveryState();
      
      // 2. Small delay to ensure frame is painted
      await Future.delayed(const Duration(milliseconds: 100));
      FlutterNativeSplash.remove();
      
      // 3. Keep the animation visible for at least 2.5 seconds for premium feel
      await Future.delayed(const Duration(milliseconds: 2400));
      
      if (mounted && recovery != null) {
        final path = recovery['path'];
        final threadId = recovery['threadId'];
        
        if (path != null) {
          developer.log('🚀 Recovering session: $path', name: 'LoadingScreen');
          // Clear it so we don't loop
          await RecoveryService.clearRecoveryState();
          
          if (mounted) {
             // Go directly to the chat with the thread context
             context.go(path, extra: threadId != null ? {'thread_id': threadId} : null);
             return;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Pulsing Logo
                Image.asset(
                  'assets/images/topscore_logo.png',
                  width: 120,
                  height: 120,
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.08, 1.08),
                      duration: 1200.ms,
                      curve: Curves.easeInOutBack,
                    ),
                
                const SizedBox(height: 32),
                
                // 2. Sequential Letter Animation: "TopScore AI"
                _buildAnimatedBrand(theme, isDark),
                
                const SizedBox(height: 48),
                
                // 3. Shimmering Loading Status
                if (widget.status != null)
                  Text(
                    widget.status!,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 2.seconds, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ],
            ),
          ),
          
          // 4. Rotating Loading Tips (Bottom)
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: 500.ms,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _currentTip,
                    key: ValueKey(_currentTip),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBrand(ThemeData theme, bool isDark) {
    const String brand = "TopScore AI";
    final List<String> letters = brand.split('');
    
    return Wrap(
      alignment: WrapAlignment.center,
      children: letters.asMap().entries.map((entry) {
        final index = entry.key;
        final letter = entry.value;
        
        return Text(
          letter == " " ? "\u00A0" : letter,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: 0.5,
          ),
        )
            .animate()
            .fadeIn(delay: (index * 60).ms, duration: 400.ms)
            .slideY(begin: 0.3, end: 0, delay: (index * 60).ms, duration: 400.ms, curve: Curves.easeOutBack);
      }).toList(),
    );
  }
}
