import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class HeartsRow extends StatelessWidget {
  final int hearts;
  final int max;
  final double size;

  const HeartsRow({
    super.key,
    required this.hearts,
    this.max = 5,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < hearts;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutBack,
                ),
                child: child,
              ),
              child: Container(
                key: ValueKey<bool>(filled),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  filled ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: filled ? const Color(0xFFEF4444) : Colors.grey.shade400,
                  size: size,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
