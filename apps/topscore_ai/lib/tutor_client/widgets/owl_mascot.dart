import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../widgets/pulse_animation.dart';

enum OwlState { idle, happy, sad, cheer }

class OwlMascot extends StatelessWidget {
  final OwlState state;
  final double size;

  const OwlMascot({
    super.key,
    this.state = OwlState.idle,
    this.size = 44,
  });

  String get _emoji {
    switch (state) {
      case OwlState.happy: return '🦉';
      case OwlState.sad: return '😿';
      case OwlState.cheer: return '🎉';
      case OwlState.idle: return '🦉';
    }
  }

  Color get _bg {
    switch (state) {
      case OwlState.happy:
      case OwlState.cheer:
        return const Color(0xFFDCFCE7);
      case OwlState.sad:
        return const Color(0xFFFEE2E2);
      case OwlState.idle:
        return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey<OwlState>(state),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _bg.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (state == OwlState.cheer)
              const Positioned.fill(
                child: PulseAnimation(
                  repeat: true,
                  maxScale: 1.2,
                  child: Icon(
                    CupertinoIcons.sparkles,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
              ),
            Text(
              _emoji,
              style: TextStyle(
                fontSize: size * 0.55,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
