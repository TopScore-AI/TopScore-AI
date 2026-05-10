import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../widgets/app_spinner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/resources_provider.dart';
import '../../repositories/synced_study_repository.dart';
import '../../widgets/resources/resource_file_card.dart';
import '../../main.dart'; // studyDb
import '../tools/flashcard_study_screen.dart';
import '../tools/quiz_study_screen.dart';
import '../../models/flashcard_model.dart';
import '../../models/quiz_model.dart';
import '../../services/download_service.dart';
import '../../models/firebase_file.dart';

class YourLibraryScreen extends StatefulWidget {
  const YourLibraryScreen({super.key});

  @override
  State<YourLibraryScreen> createState() => _YourLibraryScreenState();
}

class _YourLibraryScreenState extends State<YourLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DownloadService _downloadService = DownloadService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.userModel != null) {
        final res = context.read<ResourcesProvider>();
        await res.loadRecentlyOpened();
        await res.loadCloudHistory(auth.userModel!.uid);
        _triggerAutoDownloads(res.recentlyOpened);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _triggerAutoDownloads(List<FirebaseFile> files) async {
    if (kIsWeb) return;
    for (final file in files) {
      if (file.downloadUrl == null || file.downloadUrl!.isEmpty) continue;
      final isDownloaded = await _downloadService.isDownloaded(file.path);
      if (!isDownloaded) {
        _downloadService
            .downloadFile(
              id: file.path,
              title: file.name,
              downloadUrl: file.downloadUrl!,
              onProgress: (_) {},
            )
            .catchError((_) => 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final uid = auth.userModel?.uid ?? 'anon';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Your Library',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor:
              theme.colorScheme.onSurface.withValues(alpha: 0.5),
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Files'),
            Tab(text: 'Flashcards'),
            Tab(text: 'Quizzes'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final res = context.read<ResourcesProvider>();
          await res.loadRecentlyOpened();
          await res.loadCloudHistory(uid);
          setState(() {}); // refresh FutureBuilders
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _FilesTab(isDark: isDark),
            _MaterialsTab(type: 'flashcard', isDark: isDark),
            _MaterialsTab(type: 'quiz', isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// ─── Files tab ────────────────────────────────────────────────────────────────

class _FilesTab extends StatelessWidget {
  final bool isDark;
  const _FilesTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Consumer<ResourcesProvider>(
      builder: (context, provider, _) {
        final recent = provider.recentlyOpened;
        if (recent.isEmpty) {
          return const _EmptyState(
            icon: CupertinoIcons.doc_text,
            message:
                'No saved files yet.\nOpen a PDF from the Library to save it here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: recent.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final file = recent[i];
            return ResourceFileCard(
              file: file,
              onTap: () => context.push('/pdf-viewer', extra: {
                'url': file.downloadUrl,
                'title': file.displayName,
                'storagePath': file.path,
              }),
            );
          },
        );
      },
    );
  }
}

// ─── Flashcards / Quizzes tab ─────────────────────────────────────────────────

class _MaterialsTab extends StatefulWidget {
  final String type;
  final bool isDark;
  const _MaterialsTab({required this.type, required this.isDark});

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
  late Stream<List<Map<String, dynamic>>> _stream;
  late Future<List<Map<String, dynamic>>> _fallbackFuture;

  void _bind() {
    final repo = studyDb;
    if (repo is SyncedStudyRepository) {
      _stream = repo.watchMaterialsByType(widget.type);
    } else {
      _stream = const Stream.empty();
    }
    _fallbackFuture = studyDb.getMaterialsByType(widget.type);
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _refresh() => setState(_bind);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      initialData: null,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fallbackFuture,
            builder: (context, futureSnap) {
              if (futureSnap.connectionState == ConnectionState.waiting) {
                return AppSpinner.center();
              }
              return _buildList(futureSnap.data ?? []);
            },
          );
        }
        return _buildList(snapshot.data ?? []);
      },
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return _EmptyState(
        icon: widget.type == 'flashcard'
            ? CupertinoIcons.rectangle_on_rectangle_angled
            : CupertinoIcons.checkmark_seal,
        message: widget.type == 'flashcard'
            ? 'No flashcard sets saved yet.\nGenerate some from the AI Tutor!'
            : 'No quizzes saved yet.\nGenerate some from the AI Tutor!',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _StudyMaterialCard(
        item: items[i],
        onDeleted: _refresh,
      ),
    );
  }
}

// ─── Study material card ──────────────────────────────────────────────────────

class _StudyMaterialCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDeleted;

  const _StudyMaterialCard({required this.item, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final type = item['type'] as String? ?? '';
    final topic = item['topic'] as String? ?? 'Untitled';
    final curriculum = item['curriculum'] as String? ?? '';
    final grade = item['grade']?.toString() ?? '';

    final isFlashcard = type == 'flashcard';
    final color = isFlashcard ? Colors.orange : Colors.green;
    final icon = isFlashcard
        ? CupertinoIcons.rectangle_on_rectangle_angled
        : CupertinoIcons.checkmark_seal_fill;

    // Count items for the subtitle
    final count = _countItems(item);
    final countLabel = isFlashcard
        ? '$count card${count == 1 ? '' : 's'}'
        : '$count question${count == 1 ? '' : 's'}';

    return Dismissible(
      key: Key('${item['id']}_$topic'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(CupertinoIcons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete?'),
            content: Text('Remove "$topic" from your library?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final id = item['id'];
        if (id != null) {
          await studyDb.deleteMaterial(id as int);
          onDeleted();
        }
      },
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openStudyScreen(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip(label: countLabel, color: color),
                          if (curriculum.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _Chip(
                                label: curriculum,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)),
                          ],
                          if (grade.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _Chip(
                                label: grade,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _countItems(Map<String, dynamic> item) {
    try {
      final raw = jsonDecode(item['jsonData'] as String);
      if (raw is Map) {
        final list = raw['cards'] ?? raw['questions'];
        if (list is List) return list.length;
      } else if (raw is List) {
        return raw.length;
      }
    } catch (_) {}
    return 0;
  }

  void _openStudyScreen(BuildContext context) {
    final type = item['type'] as String? ?? '';
    try {
      final raw = jsonDecode(item['jsonData'] as String);

      if (type == 'flashcard') {
        final FlashcardSet set;
        if (raw is Map<String, dynamic> && raw.containsKey('cards')) {
          // Full FlashcardSet JSON
          set = FlashcardSet.fromJson(raw);
        } else if (raw is List) {
          // Legacy: bare list of cards
          set = FlashcardSet(
            title: item['topic'] ?? 'Flashcards',
            topic: item['topic'] ?? 'Flashcards',
            curriculum: item['curriculum'],
            grade: int.tryParse(
                item['grade']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
                    ''),
            cards: raw
                .map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
                .toList(),
          );
        } else {
          _showError(context, 'Could not read flashcard data.');
          return;
        }

        if (set.cards.isEmpty) {
          _showError(context, 'This flashcard set has no cards.');
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => FlashcardStudyScreen(flashcardSet: set),
          ),
        );
      } else if (type == 'quiz') {
        final Quiz quiz;
        if (raw is Map<String, dynamic> && raw.containsKey('questions')) {
          // Full Quiz JSON
          quiz = Quiz.fromJson(raw);
        } else if (raw is List) {
          // Legacy: bare list of questions
          quiz = Quiz(
            title: item['topic'] ?? 'Quiz',
            topic: item['topic'] ?? 'General',
            difficulty: 'Saved',
            curriculum: item['curriculum'],
            grade: int.tryParse(
                item['grade']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
                    ''),
            questions: raw
                .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
                .toList(),
          );
        } else {
          _showError(context, 'Could not read quiz data.');
          return;
        }

        if (quiz.questions.isEmpty) {
          _showError(context, 'This quiz has no questions.');
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => QuizStudyScreen(
              offlineQuiz: quiz,
              topic: item['topic'] ?? 'General',
              curriculum: item['curriculum'] ?? 'General',
              grade: item['grade']?.toString() ?? '',
            ),
          ),
        );
      }
    } catch (e) {
      _showError(context, 'Failed to open: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Chip label ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
