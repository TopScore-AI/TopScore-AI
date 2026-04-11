import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/resources_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../models/firebase_file.dart';
import '../utils/text_utils.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Activity History',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'AI Tutor'),
              Tab(text: 'Files'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActivityList(filter: _Filter.all),
            _ActivityList(filter: _Filter.tutor),
            _ActivityList(filter: _Filter.files),
          ],
        ),
      ),
    );
  }
}

enum _Filter { all, tutor, files }

class _ActivityList extends StatelessWidget {
  final _Filter filter;
  const _ActivityList({required this.filter});

  @override
  Widget build(BuildContext context) {
    final resourcesProvider = Provider.of<ResourcesProvider>(context);
    final aiTutorProvider = Provider.of<AiTutorHistoryProvider>(context);

    final recentFiles = resourcesProvider.recentlyOpened;
    final recentChats = aiTutorProvider.threads;

    final List<_ActivityItem> items = [];

    if (filter != _Filter.files) {
      for (final chat in recentChats) {
        items.add(_ActivityItem(
          type: _ActivityType.tutor,
          title: chat['title'] as String? ?? 'AI Tutor Chat',
          subtitle: 'AI Tutor Session',
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFF2563EB),
          time: _parseTime(chat['updated_at']),
          data: chat,
        ));
      }
    }

    if (filter != _Filter.tutor) {
      for (final file in recentFiles) {
        items.add(_ActivityItem(
          type: _ActivityType.file,
          title: file.displayName,
          subtitle: file.subject ?? file.type.toUpperCase(),
          icon: _iconForFileType(file.type),
          color: _colorForFileType(file.type),
          time: file.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          data: file,
        ));
      }
    }

    items.sort((a, b) => b.time.compareTo(a.time));

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history_rounded,
                    size: 40, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              Text(
                'No activity yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filter == _Filter.tutor
                    ? 'Start a chat with the AI Tutor to see your sessions here.'
                    : filter == _Filter.files
                        ? 'Open a study resource to track your reading history.'
                        : 'Chat with the AI Tutor or open a resource to get started.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ActivityTile(item: item);
      },
    );
  }

  DateTime _parseTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  IconData _iconForFileType(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'mp4':
      case 'video':
        return Icons.play_circle_fill;
      case 'mp3':
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.description;
    }
  }

  Color _colorForFileType(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'mp4':
      case 'video':
        return Colors.purple;
      case 'mp3':
      case 'audio':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

enum _ActivityType { tutor, file }

class _ActivityItem {
  final _ActivityType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final DateTime time;
  final dynamic data;

  const _ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.time,
    required this.data,
  });
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(item.icon, color: item.color, size: 22),
      ),
      title: Text(
        stripMarkdown(item.title),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Text(
        _formatTime(item.time),
        style: GoogleFonts.inter(
          fontSize: 11,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      onTap: () => _onTap(context),
    );
  }

  void _onTap(BuildContext context) {
    if (item.type == _ActivityType.tutor) {
      final chat = item.data as Map<String, dynamic>;
      context.push('/ai-tutor', extra: {
        'thread_id': chat['thread_id'],
        'title': chat['title'],
      });
    } else {
      final file = item.data as FirebaseFile;
      if (file.downloadUrl != null) {
        context.push('/pdf-viewer', extra: {
          'url': file.downloadUrl,
          'title': file.displayName,
        });
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}
