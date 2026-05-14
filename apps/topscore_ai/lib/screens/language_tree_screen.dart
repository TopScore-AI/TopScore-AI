import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../constants/colors.dart';
import '../widgets/bounce_wrapper.dart';
import '../tutor_client/services/buddy_progress_service.dart';
import '../tutor_client/widgets/hearts_row.dart';

class LanguageTreeScreen extends StatefulWidget {
  final String language;
  const LanguageTreeScreen({super.key, required this.language});

  @override
  State<LanguageTreeScreen> createState() => _LanguageTreeScreenState();
}

class _LanguageTreeScreenState extends State<LanguageTreeScreen> {
  final _progress = BuddyProgressService.instance;
  List<bool> _completed = const [];
  int _currentIndex = 0;

  static const Map<String, List<String>> _topicsByLanguage = {
    'French': [
      'Greetings & Introductions',
      'Numbers 1–20',
      'Food & Drinks',
      'Family Members',
      'Colors & Clothing',
      'Directions in the City',
      'At the Market',
      'Travel Phrases',
    ],
    'Spanish': [
      'Saludos y Presentaciones',
      'Números 1–20',
      'Comida y Bebidas',
      'La Familia',
      'Colores y Ropa',
      'Direcciones',
      'En el Mercado',
      'Viajar',
    ],
    'German': [
      'Begrüßung & Vorstellung',
      'Zahlen 1–20',
      'Essen & Trinken',
      'Familie',
      'Farben & Kleidung',
      'Wegbeschreibungen',
      'Auf dem Markt',
      'Reisen',
    ],
    'Italian': [
      'Saluti e Presentazioni',
      'Numeri 1–20',
      'Cibo e Bevande',
      'La Famiglia',
      'Colori e Vestiti',
      'Direzioni',
      'Al Mercato',
      'Viaggio',
    ],
    'Portuguese': [
      'Saudações e Apresentações',
      'Números 1–20',
      'Comida e Bebidas',
      'A Família',
      'Cores e Roupa',
      'Direções',
      'No Mercado',
      'Viagem',
    ],
    'Swahili': [
      'Salamu na Utangulizi',
      'Hesabu 1–20',
      'Chakula na Vinywaji',
      'Familia',
      'Rangi na Mavazi',
      'Maelekezo',
      'Sokoni',
      'Safari',
    ],
  };

  List<String> get _topics =>
      _topicsByLanguage[widget.language] ?? _topicsByLanguage['French']!;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    await _progress.load();
    final results = <bool>[];
    for (var i = 0; i < _topics.length; i++) {
      results.add(await _progress.isNodeCompleted(widget.language, i));
    }
    final current = await _progress.currentNodeIndex(widget.language, _topics.length);
    if (mounted) {
      setState(() {
        _completed = results;
        _currentIndex = current;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: AnimatedBuilder(
          animation: _progress,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥 ', style: TextStyle(fontSize: 16)),
              Text('${_progress.streak}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
              const SizedBox(width: 14),
              HeartsRow(hearts: _progress.hearts, max: BuddyProgressService.maxHearts, size: 16),
              const SizedBox(width: 14),
              const Icon(CupertinoIcons.star_fill, color: Color(0xFFFBBF24), size: 16),
              const SizedBox(width: 3),
              Text('${_progress.dailyXp}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Text(_languageFlag(widget.language),
                      style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.language,
                            style: GoogleFonts.poppins(
                                fontSize: 22, fontWeight: FontWeight.w900)),
                        Text('Tap an unlocked star to start a quest',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _topics.length,
                itemBuilder: (_, i) {
                  final isCompleted = i < _completed.length && _completed[i];
                  final isCurrent = i == _currentIndex && !isCompleted;
                  final isLocked = !isCompleted && !isCurrent;
                  return Align(
                    alignment: Alignment(i.isEven ? -0.45 : 0.45, 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _LessonNode(
                        index: i,
                        topic: _topics[i],
                        completed: isCompleted,
                        current: isCurrent,
                        locked: isLocked,
                        onTap: () => _onNodeTap(i, isLocked, isCompleted),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onNodeTap(int index, bool locked, bool completed) async {
    if (locked) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clear node $index first to unlock this quest',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    final result = await context.push<bool>('/lesson-mode', extra: {
      'language': widget.language,
      'topic': _topics[index],
    });
    // Optimistically mark complete when user returns — full result-passing TBD.
    if (mounted && (result == true || result == null) && !completed) {
      await _progress.markNodeCompleted(widget.language, index);
      _loadProgress();
    }
  }

  String _languageFlag(String lang) {
    switch (lang.toLowerCase()) {
      case 'french': return '🇫🇷';
      case 'spanish': return '🇪🇸';
      case 'german': return '🇩🇪';
      case 'italian': return '🇮🇹';
      case 'portuguese': return '🇵🇹';
      case 'swahili': return '🇰🇪';
      default: return '🌍';
    }
  }
}

class _LessonNode extends StatelessWidget {
  final int index;
  final String topic;
  final bool completed;
  final bool current;
  final bool locked;
  final VoidCallback onTap;

  const _LessonNode({
    required this.index,
    required this.topic,
    required this.completed,
    required this.current,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    IconData icon;
    Color iconColor;
    if (completed) {
      bg = const Color(0xFF58CC02);
      icon = Icons.check_rounded;
      iconColor = Colors.white;
    } else if (current) {
      bg = const Color(0xFFFBBF24);
      icon = CupertinoIcons.star_fill;
      iconColor = Colors.white;
    } else {
      bg = Colors.grey.shade300;
      icon = Icons.lock_rounded;
      iconColor = Colors.grey.shade600;
    }
    return BounceWrapper(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: locked
                  ? null
                  : [
                      BoxShadow(
                        color: bg.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Icon(icon, color: iconColor, size: 34),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              topic,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: locked ? Colors.grey : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
