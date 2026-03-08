import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/offline_service.dart';
import '../../models/flashcard_model.dart';
import '../../models/quiz_model.dart';

class OfflineLibraryScreen extends StatefulWidget {
  const OfflineLibraryScreen({super.key});

  @override
  State<OfflineLibraryScreen> createState() => _OfflineLibraryScreenState();
}

class _OfflineLibraryScreenState extends State<OfflineLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OfflineService _offlineService = OfflineService();

  List<FlashcardSet> _flashcardSets = [];
  List<Quiz> _quizzes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _offlineService.init();
    setState(() {
      _flashcardSets = _offlineService.getSavedFlashcardSets();
      _quizzes = _offlineService.getSavedQuizzes();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Offline Library",
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Flashcards", icon: Icon(Icons.style)),
            Tab(text: "Quizzes", icon: Icon(Icons.quiz)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFlashcardList(theme),
                _buildQuizList(theme),
              ],
            ),
    );
  }

  Widget _buildFlashcardList(ThemeData theme) {
    if (_flashcardSets.isEmpty) {
      return _buildEmptyState(
          "No offline flashcards yet.", Icons.style_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _flashcardSets.length,
      itemBuilder: (context, index) {
        final set = _flashcardSets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(set.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${set.topic} • ${set.cards.length} cards"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Opening flashcards offline...")),
              );
            },
            onLongPress: () => _confirmDeleteFlashcard(set),
          ),
        );
      },
    );
  }

  Widget _buildQuizList(ThemeData theme) {
    if (_quizzes.isEmpty) {
      return _buildEmptyState("No offline quizzes yet.", Icons.quiz_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quizzes.length,
      itemBuilder: (context, index) {
        final quiz = _quizzes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(quiz.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                Text("${quiz.topic} • ${quiz.questions.length} questions"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Opening quiz offline...")),
              );
            },
            onLongPress: () => _confirmDeleteQuiz(quiz),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.nunito(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFlashcard(FlashcardSet set) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Offline Set?"),
        content:
            Text("Do you want to remove '${set.title}' from offline storage?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (delete == true) {
      await _offlineService.deleteFlashcardSet(set.title, set.topic);
      _loadData();
    }
  }

  Future<void> _confirmDeleteQuiz(Quiz quiz) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Offline Quiz?"),
        content:
            Text("Do you want to remove '${quiz.title}' from offline storage?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (delete == true) {
      await _offlineService.deleteQuiz(quiz.title, quiz.topic);
      _loadData();
    }
  }
}
