import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../widgets/app_spinner.dart';

class MnemonicCard extends StatefulWidget {
  final String mnemonicDataJson;

  const MnemonicCard({super.key, required this.mnemonicDataJson});

  @override
  State<MnemonicCard> createState() => _MnemonicCardState();
}

class _MnemonicCardState extends State<MnemonicCard>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  late AnimationController _pulseController;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = jsonDecode(widget.mnemonicDataJson);
    _audioPlayer = AudioPlayer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final audioUrl = _data['audio_url'];
    if (audioUrl == null || audioUrl.isEmpty) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() => _isLoadingAudio = true);
      try {
        await _audioPlayer.play(UrlSource(audioUrl));
      } catch (e) {
        if (kDebugMode) debugPrint('Error loading mnemonic audio: $e');
      } finally {
        if (mounted) setState(() => _isLoadingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = AppColors.topscoreBlue;
    final accentColor = AppColors.accentTeal;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)]
              : [Colors.white, const Color(0xFFF5F5F5)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 102 : 25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: primaryColor.withAlpha(75),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative Background Pattern
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.05,
                child: Icon(Icons.psychology, size: 150, color: primaryColor),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Topic \u0026 Style Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _data['topic']?.toString().toUpperCase() ??
                              'MEMORIZATION AID',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: accentColor.withAlpha(51)),
                        ),
                        child: Text(
                          _data['style'] ?? 'Local Context',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // The Mnemonic Phrase (Big and Bold) - Solid color for visibility
                  Text(
                    _data['mnemonic_phrase'] ?? '',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      color: primaryColor, // Solid color instead of gradient
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Animated Audio Player Row
                  if (_data['audio_url'] != null)
                    _buildAudioRow(primaryColor, accentColor, isDark),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Explanation / Breakdown
                  Text(
                    'Memory Breakdown',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _data['explanation'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: theme.colorScheme.onSurface, // Full visibility
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Interactive Action
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      // Logic to save as Flashcard would go here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Saved to your Memory Deck!'),
                          backgroundColor: accentColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(
                      'Save to Flashcards',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioRow(Color primary, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _toggleAudio();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              child: _isLoadingAudio
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: AppSpinner(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPlaying ? 'Playing Mnemonics Beat...' : 'Hear the Rhythm',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Pseudo-Waveform
                Row(
                  children: List.generate(15, (index) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final h = _isPlaying
                            ? (10 + (index % 5) * 4 * _pulseController.value)
                            : 4.0;
                        return Container(
                          width: 3,
                          height: h,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _isPlaying
                                ? primary
                                : primary.withAlpha(75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
