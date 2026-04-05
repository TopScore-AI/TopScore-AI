import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../main.dart'; // to access studyDb
import '../../models/quiz_model.dart';
import '../../models/flashcard_model.dart';
import 'quiz_study_screen.dart';
import 'flashcard_study_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

class StudyLibraryScreen extends StatefulWidget {
  const StudyLibraryScreen({super.key});

  @override
  State<StudyLibraryScreen> createState() => _StudyLibraryScreenState();
}

class _StudyLibraryScreenState extends State<StudyLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _savedQuizzes = [];
  List<Map<String, dynamic>> _savedFlashcards = [];
  List<Map<String, dynamic>> _savedSummaries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);

    // Fetch all materials from your Isar/SharedPreferences repository
    final quizzes = await studyDb.getMaterialsByType('quiz');
    final flashcards = await studyDb.getMaterialsByType('flashcard');
    final summaries = await studyDb.getMaterialsByType('summary');

    if (!mounted) return;

    setState(() {
      _savedQuizzes = quizzes;
      _savedFlashcards = flashcards;
      _savedSummaries = summaries;
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(int id) async {
    await studyDb.deleteMaterial(id);
    _loadLibrary(); // Refresh the lists
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item deleted"), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "TopScore Hub",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(CupertinoIcons.checkmark_seal_fill, size: 20), text: "Quizzes"),
            Tab(icon: Icon(CupertinoIcons.rectangle_on_rectangle_angled, size: 20), text: "Flashcards"),
            Tab(icon: Icon(CupertinoIcons.doc_text_fill, size: 20), text: "Summaries"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(theme, isDark, _savedQuizzes, 'quiz', CupertinoIcons.checkmark_seal_fill, const Color(0xFFF59E0B)),
                _buildList(theme, isDark, _savedFlashcards, 'flashcard', CupertinoIcons.rectangle_on_rectangle_angled, const Color(0xFF8B5CF6)),
                _buildList(theme, isDark, _savedSummaries, 'summary', CupertinoIcons.doc_text_fill, const Color(0xFF10B981)),
              ],
            ),
    );
  }

  Widget _buildList(ThemeData theme, bool isDark, List<Map<String, dynamic>> items, String type, IconData icon, Color color) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            const SizedBox(height: 16),
            Text(
              "No saved ${type}s yet.",
              style: GoogleFonts.inter(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary, 
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final date = DateTime.parse(item['createdAt']);
        final formattedDate = DateFormat('MMM d, yyyy').format(date);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(
              item['topic'],
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, 
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), 
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['grade'], 
                      style: GoogleFonts.inter(
                        fontSize: 11, 
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
              onPressed: () => _deleteItem(item['id']),
            ),
            onTap: () => _openOfflineMaterial(item),
          ),
        );
      },
    );
  }

  void _openOfflineMaterial(Map<String, dynamic> item) {
    // Grab the raw JSON string from the database
    final rawJsonString = item['jsonData'];
    final parsedJson = jsonDecode(rawJsonString);

    if (item['type'] == 'quiz') {
      final offlineQuiz = Quiz.fromJson(parsedJson);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => QuizStudyScreen(
          topic: item['topic'],
          curriculum: item['curriculum'],
          grade: item['grade'],
          offlineQuiz: offlineQuiz,
        ),
      ));
    } else if (item['type'] == 'flashcard') {
      final offlineDeck = FlashcardSet.fromJson(parsedJson);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => FlashcardStudyScreen(
          flashcardSet: offlineDeck,
        ),
      ));
    } else if (item['type'] == 'summary') {
      // Future feature: A simple screen to show the summary Markdown text
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viewing summary ID: ${item['id']}')),
      );
    }
  }
}
