import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'calculator_screen.dart';
import 'smart_scanner_screen.dart';
import 'timetable_screen.dart';
import 'study_library_screen.dart';

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------
class _Tool {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String category;
  final bool isPrimary;

  const _Tool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    this.isPrimary = false,
  });
}

const _allTools = [
  _Tool(id: 'science_lab', title: 'Science Lab', description: 'Virtual experiments with AI guidance', icon: Icons.science_rounded, color: Color(0xFF6C63FF), category: 'Science'),
  _Tool(id: 'periodic_table', title: 'Periodic Table', description: 'All 118 elements with properties', icon: Icons.grid_4x4_rounded, color: Color(0xFFE91E63), category: 'Science'),
  _Tool(id: 'calculator', title: 'Scientific Calc', description: 'Trig, logs, history & more', icon: Icons.calculate_rounded, color: Color(0xFF4A90E2), category: 'Math'),
  _Tool(id: 'flashcards', title: 'AI Flashcards', description: 'Generate study cards from any topic', icon: Icons.flash_on_rounded, color: Color(0xFFA389F4), category: 'Study'),
  _Tool(id: 'quiz', title: 'AI Quiz', description: 'Test your knowledge with AI', icon: Icons.quiz_rounded, color: Color(0xFF00BCD4), category: 'Study', isPrimary: true),
  _Tool(id: 'scanner', title: 'Doc Scanner', description: 'Digitize notes & solve problems', icon: Icons.document_scanner_rounded, color: Color(0xFF4ECDC4), category: 'Utility'),
  _Tool(id: 'timetable', title: 'Smart Timetable', description: 'Plan your week with reminders', icon: Icons.calendar_month_rounded, color: Color(0xFFFFD93D), category: 'Utility'),
  _Tool(id: 'database', title: 'TopScore Hub', description: 'Discover past papers from schools across the country', icon: Icons.school_rounded, color: Color(0xFF10B981), category: 'Library'),
  _Tool(id: 'summarizer', title: 'PDF Summarizer', description: 'AI extracts notes from your PDFs', icon: Icons.summarize_rounded, color: Color(0xFFF59E0B), category: 'Study', isPrimary: true),
  _Tool(id: 'composition_studio', title: 'Composition Studio', description: 'Practice writing with AI-powered grading (Grade out of 40)', icon: Icons.edit_note_rounded, color: Color(0xFF1092B9), category: 'Study'),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _search = '';
  String _categoryFilter = 'All';
  List<String> _recentIds = [];

  static const _categories = ['All', 'Science', 'Math', 'Study', 'Utility'];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recentIds = prefs.getStringList('recent_tools') ?? []);
  }

  Future<void> _recordRecent(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = [id, ..._recentIds.where((r) => r != id)].take(4).toList();
    await prefs.setStringList('recent_tools', list);
    setState(() => _recentIds = list);
  }

  List<_Tool> get _filtered {
    return _allTools.where((t) {
      final matchSearch = _search.isEmpty ||
          t.title.toLowerCase().contains(_search.toLowerCase()) ||
          t.description.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _categoryFilter == 'All' || t.category == _categoryFilter;
      return matchSearch && matchCat;
    }).toList();
  }

  List<_Tool> get _recents => _recentIds
      .map((id) => _allTools.firstWhere((t) => t.id == id, orElse: () => _allTools.first))
      .where((t) => _allTools.any((a) => a.id == t.id))
      .toList();

  void _openTool(_Tool tool) {
    _recordRecent(tool.id);

    // Use GoRouter for tool sub-routes
    switch (tool.id) {
      case 'composition_studio':
        context.push('/tools/composition-studio');
        return;
      case 'summarizer':
        context.push('/tools/summarizer');
        return;
      case 'flashcards':
        context.push('/tools/flashcards');
        return;
      case 'quiz':
        context.push('/tools/quiz');
        return;
      case 'science_lab':
        context.push('/tools/science-lab');
        return;
      case 'periodic_table':
        context.push('/tools/periodic-table');
        return;
    }

    Widget? screen;
    switch (tool.id) {
      case 'calculator': screen = const CalculatorScreen(); break;
      case 'scanner': screen = const SmartScannerScreen(); break;
      case 'timetable': screen = const TimetableScreen(); break;
      case 'database': screen = const StudyLibraryScreen(); break;
    }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App bar with search
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: _buildSearchBar(theme, isDark),
              collapseMode: CollapseMode.pin,
            ),
            title: Text('Smart Toolkit', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 20)),
            centerTitle: false,
          ),

          // Category filter
          SliverToBoxAdapter(child: _buildCategoryFilter(theme)),

          // Recent tools
          if (_recentIds.isNotEmpty && _search.isEmpty && _categoryFilter == 'All') ...[
            SliverToBoxAdapter(child: _sectionHeader('Recently Used', theme)),
            SliverToBoxAdapter(child: _buildRecentRow(theme, isDark)),
          ],

          // All tools grid
          SliverToBoxAdapter(child: _sectionHeader(
            _search.isNotEmpty ? 'Results (${_filtered.length})' : _categoryFilter == 'All' ? 'All Tools' : _categoryFilter,
            theme,
          )),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.82,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildToolCard(_filtered[i], theme, isDark),
                childCount: _filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search tools...',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }

  Widget _buildCategoryFilter(ThemeData theme) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _categories.map((cat) {
          final selected = _categoryFilter == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
              selected: selected,
              onSelected: (_) => setState(() => _categoryFilter = cat),
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              checkmarkColor: theme.colorScheme.primary,
              side: BorderSide(color: selected ? theme.colorScheme.primary : theme.dividerColor),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
    );
  }

  Widget _buildRecentRow(ThemeData theme, bool isDark) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _recents.map((tool) => GestureDetector(
          onTap: () => _openTool(tool),
          child: Container(
            width: 72,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tool.color.withValues(alpha: 0.2)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: tool.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(tool.icon, color: tool.color, size: 20),
              ),
              const SizedBox(height: 4),
              Text(tool.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            ]),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildToolCard(_Tool tool, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () => _openTool(tool),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tool.isPrimary
              ? (isDark ? tool.color.withValues(alpha: 0.08) : tool.color.withValues(alpha: 0.05))
              : (isDark ? const Color(0xFF1E1F22) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: tool.isPrimary
                ? tool.color.withValues(alpha: isDark ? 0.2 : 0.25)
                : (isDark ? Colors.white.withValues(alpha: 0.06) : tool.color.withValues(alpha: 0.12)),
          ),
          boxShadow: [BoxShadow(color: tool.color.withValues(alpha: isDark ? 0.08 : 0.1), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [tool.color.withValues(alpha: 0.15), tool.color.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(tool.icon, color: tool.color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(tool.title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(tool.description, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
          const SizedBox(height: 8),
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: tool.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(tool.category, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: tool.color)),
          ),
        ]),
      ),
    );
  }
}
