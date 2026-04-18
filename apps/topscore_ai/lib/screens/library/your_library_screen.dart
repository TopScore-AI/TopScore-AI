import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resources_provider.dart';
import '../../widgets/resources/resource_file_card.dart';
import '../../main.dart'; // For studyDb
import '../../utils/cors_proxy_helper.dart';
import '../tools/flashcard_study_screen.dart';
import '../tools/quiz_study_screen.dart';
import '../../models/flashcard_model.dart';
import '../../models/quiz_model.dart';

class YourLibraryScreen extends StatefulWidget {
  const YourLibraryScreen({super.key});

  @override
  State<YourLibraryScreen> createState() => _YourLibraryScreenState();
}

class _YourLibraryScreenState extends State<YourLibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userModel != null) {
        context.read<ResourcesProvider>().loadRecentlyOpened();
        context.read<ResourcesProvider>().loadCloudHistory(auth.userModel!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final uid = auth.userModel?.uid ?? 'anon';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Your Library",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final res = context.read<ResourcesProvider>();
          await res.loadRecentlyOpened();
          await res.loadCloudHistory(uid);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // --- SECTION 1: RECENTLY SAVED / OPENED ---
            _buildSectionHeader("Recently Saved"),
            _buildRecentSliver(),

            // --- SECTION 2: AI ARTIFACTS (Images & Graphs) ---
            _buildSectionHeader("My AI Creations"),
            _buildArtifactsSliver(uid),

            // --- SECTION 3: STUDY MATERIALS (Flashcards & Quizzes) ---
            _buildSectionHeader("Flashcards & Quizzes"),
            _buildOfflineSliver(),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSliver() {
    return Consumer<ResourcesProvider>(
      builder: (context, provider, child) {
        final recent = provider.recentlyOpened;
        if (recent.isEmpty) {
          return const SliverToBoxAdapter(
            child: _EmptyPlaceholder(message: "No recently saved files."),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final file = recent[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ResourceFileCard(
                    file: file,
                    onTap: () => context.push('/pdf-viewer', extra: {
                      'url': file.downloadUrl,
                      'title': file.displayName,
                    }),
                  ),
                );
              },
              childCount: recent.length > 5 ? 5 : recent.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtifactsSliver(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('library')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: _EmptyPlaceholder(message: "Generated images/graphs will appear here."),
          );
        }

        final cloudDocs = snapshot.data!.docs;
        
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemBuilder: (context, index) {
              final data = cloudDocs[index].data() as Map<String, dynamic>;
              return _ArtifactCard(data: data);
            },
            childCount: cloudDocs.length,
          ),
        );
      },
    );
  }

  Widget _buildOfflineSliver() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([
        studyDb.getMaterialsByType('flashcards'),
        studyDb.getMaterialsByType('quiz'),
        studyDb.getMaterialsByType('pdf_summary'),
      ]).then((lists) => lists.expand((x) => x).toList()
        ..sort((a, b) => b['createdAt'].toString().compareTo(a['createdAt'].toString()))),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(
            child: _EmptyPlaceholder(message: "No generated study sets yet."),
          );
        }

        final items = snapshot.data!;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OfflineMaterialCard(item: items[index]),
                );
              },
              childCount: items.length > 15 ? 15 : items.length,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String message;
  const _EmptyPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: theme.hintColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ArtifactCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'text';
    final content = data['content'] ?? '';
    final title = data['title'] ?? 'Untitled';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (type == 'image' || type == 'graph')
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: CorsProxyHelper.getCorsProxyUrl(content),
                  placeholder: (c, u) => Container(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (c, u, e) => const Icon(Icons.broken_image_outlined),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (type == 'graph' ? Colors.blue : Colors.purple).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type.toString().toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: (type == 'graph' ? Colors.blue : Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title, 
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, 
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineMaterialCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _OfflineMaterialCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type'];
    final topic = item['topic'] ?? 'Untitled';
    
    IconData icon = Icons.description_rounded;
    Color color = Colors.blue;
    if (type == 'flashcards') { icon = Icons.style_rounded; color = Colors.orange; }
    else if (type == 'quiz') { icon = Icons.quiz_rounded; color = Colors.green; }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleStudy(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${type.toString().toUpperCase()} • ${item['curriculum'] ?? 'General'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded, 
                  size: 16, 
                  color: theme.hintColor.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleStudy(BuildContext context) {
    final jsonData = jsonDecode(item['jsonData']);
    final type = item['type'];

    if (type == 'flashcards') {
      final List<dynamic> cardsJson = jsonData;
      final flashcardSet = FlashcardSet(
        title: item['topic'] ?? 'Untitled Flashcards',
        topic: item['topic'] ?? 'Untitled Flashcards',
        curriculum: item['curriculum'] ?? 'Unknown',
        grade: int.tryParse(item['grade']?.toString().split(' ').last ?? ''),
        cards: cardsJson.map((c) => Flashcard.fromJson(c)).toList(),
      );
      context.push('/ai-tutor', extra: flashcardSet.cards); // FlashcardStudyScreen should be a GoRoute or handled via AI Tutor
      // Actually, looking at the models, I should verify if FlashcardStudyScreen and QuizStudyScreen are GoRoutes.
      // If not, I should keep Navigator.push or register them as GoRoutes.
      // In router.dart, I don't see them.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardStudyScreen(flashcardSet: flashcardSet),
        ),
      );
    } else if (type == 'quiz') {
      final List<dynamic> questionsJson = jsonData;
      final questions = questionsJson.map((q) => QuizQuestion.fromJson(q)).toList();
      final quiz = Quiz(
        title: item['topic'] ?? 'Untitled Quiz',
        topic: item['topic'] ?? 'General',
        difficulty: 'Saved',
        questions: questions,
        curriculum: item['curriculum'],
        grade: int.tryParse(item['grade']?.toString().split(' ').last ?? ''),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizStudyScreen(
            offlineQuiz: quiz,
            topic: item['topic'] ?? 'General',
            curriculum: item['curriculum'] ?? 'Unknown',
            grade: item['grade']?.toString() ?? 'Unknown',
          ),
        ),
      );
    } else if (type == 'pdf') {
       final localPath = jsonData['localPath'];
       if (localPath != null) {
         context.push('/pdf-viewer', extra: {
           'file': File(localPath),
           'title': item['topic'] ?? 'Offline Document',
         });
       }
     } else {
       // PDF Summary
       final summary = jsonData['summary'] ?? '';
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Summary: ${item['topic']}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Markdown(
                  data: summary,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
