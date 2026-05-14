import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class LanguageSuggestion {
  final String language;
  const LanguageSuggestion(this.language);
}

class LanguageSuggestionBanner extends StatelessWidget {
  final ValueNotifier<LanguageSuggestion?> notifier;
  const LanguageSuggestionBanner({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LanguageSuggestion?>(
      valueListenable: notifier,
      builder: (context, suggestion, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => SizeTransition(
            sizeFactor: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: suggestion == null
              ? const SizedBox.shrink()
              : _bannerCard(context, suggestion),
        );
      },
    );
  }

  Widget _bannerCard(BuildContext context, LanguageSuggestion s) {
    return Material(
      key: ValueKey<String>(s.language),
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF58CC02), Color(0xFF78D603)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF58CC02).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🦉', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Learning ${s.language}?',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  Text('Want to start a quick Buddy quest?',
                      style: GoogleFonts.nunito(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B7B0F),
                    minimumSize: const Size(80, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    notifier.value = null;
                    context.push('/language-tree', extra: {'language': s.language});
                  },
                  child: Text('Start',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => notifier.value = null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(80, 24),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text('Not now',
                      style: GoogleFonts.nunito(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
