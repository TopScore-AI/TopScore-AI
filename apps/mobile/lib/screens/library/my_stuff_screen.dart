import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import '../../utils/cors_proxy_helper.dart';
import '../../main.dart'; // Access studyDb
import '../tools/flashcard_study_screen.dart';
import '../tools/quiz_study_screen.dart';
import '../../models/flashcard_model.dart';
import '../../models/quiz_model.dart';

class MyStuffScreen extends StatelessWidget {
  final String uid;
  const MyStuffScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "My Knowledge Bank",
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: "Cloud Saves"),
              Tab(text: "Offline/Saved"),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        backgroundColor: const Color(0xFFF5F7FA),
        body: TabBarView(
          children: [
            _buildCloudSaves(uid),
            _buildOfflineSaves(),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSaves(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('library')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            "No cloud saves yet!",
            "Generate artifacts in the Tutor to see them here.",
          );
        }

        final docs = snapshot.data!.docs;

        return MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _ArtifactCard(data: data);
          },
        );
      },
    );
  }

  Widget _buildOfflineSaves() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([
        studyDb.getMaterialsByType('flashcards'),
        studyDb.getMaterialsByType('quiz'),
        studyDb.getMaterialsByType('pdf_summary'),
      ]).then((lists) => lists.expand((x) => x).toList()
        ..sort((a, b) => b['createdAt'].toString().compareTo(a['createdAt'].toString()))),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            "No offline saves!",
            "Materials you generate are auto-saved here for offline study.",
          );
        }

        final items = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _OfflineMaterialCard(item: item);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: Colors.grey),
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
    final topic = item['topic'];
    final curriculum = item['curriculum'];
    final grade = item['grade'];

    IconData icon;
    Color color;
    switch (type) {
      case 'flashcards':
        icon = Icons.style;
        color = Colors.orange;
        break;
      case 'quiz':
        icon = Icons.quiz;
        color = Colors.green;
        break;
      default:
        icon = Icons.description;
        color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          topic,
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("$curriculum • $grade"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _handleStudy(context),
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
    } else {
      // PDF Summary
      final summary = jsonData['summary'] ?? '';
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Summary: ${item['topic']}",
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Markdown(
                  data: summary,
                  // Removed styleConfig for standard Markdown package usage
                ),
              ),
            ],
          ),
        ),
      );
    }
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
    final subject = data['subject'] ?? 'General';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- CONTENT SECTION ---
          if (type == 'image' || type == 'graph')
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: CorsProxyHelper.getCorsProxyUrl(content),
                httpHeaders: CorsProxyHelper.standardHeaders,
                placeholder: (c, u) => Container(
                  height: 150,
                  color: Colors.grey[100],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (c, u, e) => const Icon(Icons.error),
                fit: BoxFit.cover,
              ),
            )
          else if (type == 'formula')
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.blue.withValues(alpha: 0.05),
              child: Math.tex(
                content, // Renders LaTeX string e.g., "E=mc^2"
                textStyle: const TextStyle(fontSize: 16),
              ),
            )
          else // Mnemonic or Text
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFFFF4E5), // Light Orange background
              child: Text(
                content,
                style: GoogleFonts.caveat(fontSize: 20, height: 1.2),
              ),
            ),

          // --- FOOTER SECTION ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildTag(type),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subject,
                        style: GoogleFonts.nunito(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String type) {
    Color color;
    IconData icon;

    switch (type) {
      case 'image':
        color = Colors.blue;
        icon = Icons.image;
        break;
      case 'formula':
        color = Colors.purple;
        icon = Icons.functions;
        break;
      case 'graph':
        color = Colors.green;
        icon = Icons.bar_chart;
        break;
      default:
        color = Colors.orange;
        icon = Icons.lightbulb;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }
}
