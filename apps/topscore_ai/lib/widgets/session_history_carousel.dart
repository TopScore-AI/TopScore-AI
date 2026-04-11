import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/resources_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../models/firebase_file.dart';
import '../config/app_theme.dart';
import '../utils/text_utils.dart';
import 'bounce_wrapper.dart';

String _relativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

// Deterministic color palette from title
Color _colorFromTitle(String title) {
  const palette = [
    Color(0xFF2563EB), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFFEC4899), // Pink
  ];
  final hash = title.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return palette[hash % palette.length];
}

class SessionHistoryCarousel extends StatelessWidget {
  const SessionHistoryCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final resourcesProvider = Provider.of<ResourcesProvider>(context);
    final aiTutorProvider = Provider.of<AiTutorHistoryProvider>(context);

    final recentFiles = resourcesProvider.recentlyOpened;
    final recentChats = aiTutorProvider.threads;

    // Combine and sort by recency
    final List<dynamic> combinedItems = [];
    combinedItems.addAll(recentFiles);
    combinedItems.addAll(recentChats);

    combinedItems.sort((a, b) {
      DateTime timeA = _getTime(a);
      DateTime timeB = _getTime(b);
      return timeB.compareTo(timeA); // Descending
    });

    final displayItems = combinedItems.take(5).toList();
    final bool useMocks = displayItems.isEmpty;
    final int itemCount = useMocks ? 3 : displayItems.length;

    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (useMocks) {
                return _buildQuickStartCard(context, index);
              } else {
                final item = displayItems[index];
                final isNewest = index == 0;
                if (item is FirebaseFile) {
                  return _buildRealSessionCard(context, item, isNewest: isNewest);
                } else {
                  return _buildChatSessionCard(context, item, isNewest: isNewest);
                }
              }
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  DateTime _getTime(dynamic item) {
    if (item is FirebaseFile) {
      return item.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (item is Map<String, dynamic>) {
      final updatedAt = item['updated_at'];
      if (updatedAt is Timestamp) {
        return updatedAt.toDate();
      } else if (updatedAt is int) {
        return DateTime.fromMillisecondsSinceEpoch(updatedAt);
      } else if (updatedAt is String) {
        return DateTime.tryParse(updatedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildChatSessionCard(
      BuildContext context, Map<String, dynamic> chat, {bool isNewest = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final title = chat['title'] ?? 'AI Tutor Chat';
    final color = _colorFromTitle(title);
    const icon = Icons.chat_bubble_outline;
    final chatTime = _getTime(chat);
    final timeLabel = _relativeTime(chatTime);

    return BounceWrapper(
      onTap: () {
        context.push('/ai-tutor', extra: {
          'thread_id': chat['thread_id'],
          'title': chat['title'],
        });
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: AppTheme.buildGlassContainer(
          context,
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (isNewest)
                    _PulsingDot(color: color)
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stripMarkdown(title),
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealSessionCard(BuildContext context, dynamic file, {bool isNewest = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Determine icon based on type
    IconData icon = Icons.description;
    Color color = Colors.blue;
    if (file.type == 'pdf') {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (file.type == 'video' || file.type == 'mp4') {
      icon = Icons.play_circle_fill;
      color = Colors.purple;
    } else if (file.type == 'audio' || file.type == 'mp3') {
      icon = Icons.audiotrack;
      color = Colors.orange;
    }

    final fileTime = _getTime(file);
    final timeLabel = _relativeTime(fileTime);

    return BounceWrapper(
      onTap: () {
        if (file.downloadUrl != null) {
          context.push('/pdf-viewer', extra: {
            'url': file.downloadUrl,
            'title': file.displayName,
          });
        }
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: AppTheme.buildGlassContainer(
          context,
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (isNewest)
                    _PulsingDot(color: color)
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name ?? 'Unknown File',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStartCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final colors = [
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981)
    ];

    final guides = [
      {
        'title': 'Summarize a PDF',
        'subtitle': 'Extract key points instantly',
        'icon': Icons.auto_stories,
        'route': '/tools/summarizer'
      },
      {
        'title': 'Practice Flashcards',
        'subtitle': 'Master concepts faster',
        'icon': Icons.style,
        'route': '/tools/flashcards'
      },
      {
        'title': 'Test Your Knowledge',
        'subtitle': 'Custom AI-generated quizzes',
        'icon': Icons.quiz,
        'route': '/tools/quiz'
      },
    ];

    return BounceWrapper(
      onTap: () => context.push(guides[index]['route'] as String),
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: AppTheme.buildGlassContainer(
          context,
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors[index].withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(guides[index]['icon'] as IconData,
                        color: colors[index], size: 20),
                  ),
                  const Icon(
                    Icons.add_circle_outline,
                    size: 16,
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guides[index]['title'] as String,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guides[index]['subtitle'] as String,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PULSING DOT — Draws attention to the newest item
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.5 + (_controller.value * 0.5)),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _controller.value * 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
