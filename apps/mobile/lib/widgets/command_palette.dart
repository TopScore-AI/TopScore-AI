import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../constants/colors.dart';

class CommandPalette extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final Function(String) onLoadThread;
  final VoidCallback onStartNewChat;

  const CommandPalette({
    super.key,
    required this.onNavigate,
    required this.onLoadThread,
    required this.onStartNewChat,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  List<_CommandItem> _filteredItems = [];

  List<_CommandItem> get _staticItems => [
    _CommandItem(
      icon: FontAwesomeIcons.house,
      label: 'Go to Home',
      category: 'Navigation',
      onSelected: (context, state) => widget.onNavigate(0),
    ),
    _CommandItem(
      icon: FontAwesomeIcons.folderOpen,
      label: 'Go to Library',
      category: 'Navigation',
      onSelected: (context, state) => widget.onNavigate(1),
    ),
    _CommandItem(
      icon: FontAwesomeIcons.brain,
      label: 'Go to AI Tutor',
      category: 'Navigation',
      onSelected: (context, state) => widget.onNavigate(2),
    ),
    _CommandItem(
      icon: FontAwesomeIcons.briefcase,
      label: 'Go to Tools',
      category: 'Navigation',
      onSelected: (context, state) => widget.onNavigate(3),
    ),
    _CommandItem(
      icon: FontAwesomeIcons.user,
      label: 'Go to Profile',
      category: 'Navigation',
      onSelected: (context, state) => widget.onNavigate(4),
    ),
    _CommandItem(
      icon: FontAwesomeIcons.plus,
      label: 'Start New Chat',
      category: 'Actions',
      onSelected: (context, state) => widget.onStartNewChat(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(_staticItems);
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    
    // Get threads from provider
    final historyProvider = Provider.of<AiTutorHistoryProvider>(context, listen: false);
    final threads = historyProvider.threads;

    final List<_CommandItem> threadItems = threads.map<_CommandItem>((t) {
      return _CommandItem(
        icon: FontAwesomeIcons.message,
        label: (t['title'] as String?) ?? 'Untitled Chat',
        category: 'Recent Chats',
        onSelected: (context, state) => widget.onLoadThread(t['thread_id'] as String),
      );
    }).toList();

    final List<_CommandItem> allItems = [];
    allItems.addAll(_staticItems);
    allItems.addAll(threadItems);

    setState(() {
      if (query.isEmpty) {
        _filteredItems = allItems.take(10).toList();
      } else {
        _filteredItems = allItems
            .where((item) => item.label.toLowerCase().contains(query))
            .toList();
      }
      _selectedIndex = 0;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filteredItems.length;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _filteredItems.length) %
              _filteredItems.length;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_filteredItems.isNotEmpty) {
          _filteredItems[_selectedIndex].onSelected(context, this);
          Navigator.pop(context);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Container(
          width: 600,
          margin: const EdgeInsets.symmetric(vertical: 80),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.magnifyingGlass,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search commands or chats...',
                          hintStyle: GoogleFonts.inter(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ESC',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final isSelected = index == _selectedIndex;
                    
                    // Show category header if it changed
                    bool showHeader = index == 0 || 
                                     _filteredItems[index-1].category != item.category;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              item.category.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentTeal.withValues(alpha: 0.8),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        _ResultTile(
                          item: item,
                          isSelected: isSelected,
                          onTap: () {
                            item.onSelected(context, this);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShortcutHint(label: '↑↓', action: 'to navigate'),
                    const SizedBox(width: 16),
                    _ShortcutHint(label: 'Enter', action: 'to select'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandItem {
  final IconData icon;
  final String label;
  final String category;
  final Function(BuildContext, _CommandPaletteState) onSelected;

  _CommandItem({
    required this.icon,
    required this.label,
    required this.category,
    required this.onSelected,
  });
}

class _ResultTile extends StatelessWidget {
  final _CommandItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResultTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected 
          ? AppColors.accentTeal.withValues(alpha: 0.15) 
          : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FaIcon(
                  item.icon,
                  size: 16,
                  color: isSelected 
                    ? AppColors.accentTeal 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  const FaIcon(FontAwesomeIcons.chevronRight, 
                      size: 12, color: AppColors.accentTeal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  final String label;
  final String action;

  const _ShortcutHint({required this.label, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          action,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
