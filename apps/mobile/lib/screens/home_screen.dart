import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:go_router/go_router.dart';

import '../constants/colors.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/resources_provider.dart';
import '../models/user_model.dart';
import '../providers/notification_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/ai_tutor_history_provider.dart';

import '../widgets/interest_update_sheet.dart';
import '../widgets/animated_search_bar.dart';
import '../widgets/enhanced_card.dart';
import '../widgets/bounce_wrapper.dart';
import '../widgets/skeleton_loader.dart';
import 'pdf_viewer_screen.dart';
import 'notifications/notification_inbox_screen.dart';
import '../models/firebase_file.dart';
import '../services/storage_service.dart';
import '../widgets/session_history_carousel.dart';
import '../widgets/glass_card.dart';

// Feature Items removed as they are now redundant with the Nav Bar.

/// HomeScreen is kept as a simple wrapper around HomeTab for backward compatibility.
/// Navigation is handled by go_router's StatefulShellRoute in router.dart.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resourcesProvider = Provider.of<ResourcesProvider>(
        context,
        listen: false,
      );
      resourcesProvider.loadRecentlyOpened();
      _checkMissingInterests();
      _setupConnectivityListener();
    });
  }

  void _setupConnectivityListener() {
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    bool? wasOnline;

    connectivity.addListener(() {
      if (!mounted) return;
      final isOnline = connectivity.isOnline;
      if (wasOnline != null && wasOnline != isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  isOnline
                      ? 'You are back online'
                      : 'You are currently offline',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: isOnline ? Colors.green : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      wasOnline = isOnline;
    });
  }

  void _checkMissingInterests() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    if (user != null &&
        user.role == 'student' &&
        (user.interests == null || user.interests!.isEmpty)) {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (context) => InterestUpdateSheet(userId: user.uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeTab();
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static List<FirebaseFile>? _cachedAllFiles;
  List<FirebaseFile> _allFiles = [];
  List<FirebaseFile> _filteredFiles = [];
  List<Map<String, dynamic>> _filteredThreads = [];
  bool _isLoadingFiles = true;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    if (_cachedAllFiles != null) {
      if (mounted) {
        setState(() {
          _allFiles = _cachedAllFiles!;
          _filteredFiles = List.from(_allFiles);
          _isLoadingFiles = false;
        });
      }
      return;
    }

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      final files = await StorageService.getAllFilesFromFirestore(
        grade: user?.grade,
        curriculum: user?.curriculum,
      );
      _cachedAllFiles = files;
      if (mounted) {
        setState(() {
          _allFiles = files;
          _filteredFiles = files;
          _isLoadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFiles = false);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _filteredFiles = List.from(_allFiles);
        _filteredThreads = [];
        _isSearching = false;
        _isLoadingFiles = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoadingFiles = true;
    });

    final lowerQuery = trimmedQuery.toLowerCase();

    // 1. Immediate Local Search (Fast)
    final localFiles = _allFiles.where((file) {
      return file.name.toLowerCase().contains(lowerQuery) ||
          file.path.toLowerCase().contains(lowerQuery) ||
          (file.subject?.toLowerCase().contains(lowerQuery) ?? false) ||
          (file.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ?? false);
    }).toList();

    final historyProvider = Provider.of<AiTutorHistoryProvider>(context, listen: false);
    final localThreads = historyProvider.threads.where((thread) {
      final title = (thread['title'] as String?)?.toLowerCase() ?? '';
      return title.contains(lowerQuery);
    }).toList();

    // Show local results immediately while waiting for remote
    if (mounted) {
      setState(() {
        _filteredFiles = localFiles;
        _filteredThreads = localThreads;
        _isLoadingFiles = true; // Still loading remote
      });
    }

    try {
      // 2. Remote Search (Comprehensive)
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      final remoteFiles = await StorageService.searchFiles(
        trimmedQuery,
        grade: user?.grade,
        curriculum: user?.curriculum,
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      // Merge results, avoiding duplicates by path
      final Map<String, FirebaseFile> mergedMap = {};
      for (var f in localFiles) {
        mergedMap[f.path] = f;
      }
      for (var f in remoteFiles) {
        mergedMap[f.path] = f;
      }

      setState(() {
        _filteredFiles = mergedMap.values.toList();
        _filteredThreads = localThreads; // Threads are already local
        _isLoadingFiles = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          // Keep local results on error
          _isLoadingFiles = false;
        });
      }
    }
  }

  Future<void> _openFile(BuildContext context, FirebaseFile file) async {
    showAdaptiveDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    try {
      String url = file.downloadUrl ?? '';
      if (url.isEmpty && file.ref != null) {
        url = await file.ref!.getDownloadURL();
      }

      if (!context.mounted) return;

      // Track file opening
      final resourcesProvider = Provider.of<ResourcesProvider>(
        context,
        listen: false,
      );
      await resourcesProvider.trackFileOpen(file);

      if (!context.mounted) return;

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            url: url,
            title: file.name,
            storagePath: file.path,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening file: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, UserModel?>((auth) => auth.userModel);
    final displayName = user?.displayName.split(' ')[0] ?? 'Student';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadFiles();
            if (context.mounted) {
              final resourcesProvider = Provider.of<ResourcesProvider>(
                context,
                listen: false,
              );
              await resourcesProvider.loadRecentlyOpened();
            }
          },
          color: AppColors.accentTeal,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedSearchBar(
                  onSearchChanged: _performSearch,
                  hintText: 'Search files, topics, chats...',
                  margin: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                    AppTheme.spacingSm,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, displayName, 12),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildAiTutorHero(context),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildQuickLinks(context),
                      const SizedBox(height: AppTheme.spacingLg),
                      const RepaintBoundary(child: SessionHistoryCarousel()),
                      const SizedBox(height: AppTheme.spacingLg),
                      RepaintBoundary(child: _buildHeroCard(context)),
                      const SizedBox(height: AppTheme.spacingLg),
                      if (_isSearching)
                        _buildSliverSearchResultsHeader(context)
                      else
                        const SizedBox(height: AppTheme.spacingLg),
                    ],
                  ),
                ),
              ),
              if (_isSearching)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                  sliver: _buildSliverSearchResults(context),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing2xl)),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // Adjust for bottom nav
        child: FloatingActionButton.extended(
          onPressed: () {
            context.push('/ai-tutor');
          },
          label: Text(
            "Ask AI Tutor",
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          icon: const Icon(Icons.auto_awesome_rounded),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 8,
        ),
      ),
    );
  }

  Widget _buildSliverSearchResultsHeader(BuildContext context) {
    final theme = Theme.of(context);
    final totalResults = _filteredFiles.length + _filteredThreads.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Row(
        children: [
          Text(
            "Search Results",
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: AppColors.kidBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '$totalResults',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.kidBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverSearchResults(BuildContext context) {
    if (_isLoadingFiles) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
          child: SkeletonList(itemCount: 5),
        ),
      );
    }

    if (_filteredFiles.isEmpty && _filteredThreads.isEmpty) {
      return SliverToBoxAdapter(child: _buildNoResults(context));
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        if (_filteredFiles.isNotEmpty) ...[
          _buildSearchSectionHeader(context, "Library Files", Icons.folder_outlined),
          const SizedBox(height: AppTheme.spacingMd),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 90,
              mainAxisSpacing: AppTheme.spacingMd,
              crossAxisSpacing: AppTheme.spacingMd,
            ),
            itemCount: _filteredFiles.length,
            itemBuilder: (context, index) => _buildFileCard(context, _filteredFiles[index]),
          ),
          const SizedBox(height: AppTheme.spacingLg),
        ],
        if (_filteredThreads.isNotEmpty) ...[
          _buildSearchSectionHeader(context, "AI Tutor Chats", Icons.chat_bubble_outline),
          const SizedBox(height: AppTheme.spacingMd),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredThreads.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingMd),
            itemBuilder: (context, index) => _buildChatCard(context, _filteredThreads[index]),
          ),
        ],
      ]),
    );
  }

  Widget _buildSearchSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppTheme.spacingSm),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildChatCard(BuildContext context, Map<String, dynamic> thread) {
    final theme = Theme.of(context);
    final title = thread['title'] ?? 'New Chat';
    final model = thread['model'] ?? 'AI Tutor';

    return BounceWrapper(
      onTap: () => _openChat(context, thread),
      child: EnhancedCard(
        isGlass: true,
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.kidPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.kidPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.quicksand(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model,
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.iconTheme.color?.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, Map<String, dynamic> thread) {
    context.push('/ai-tutor', extra: {'thread_id': thread['thread_id']});
  }

  Widget _buildNoResults(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2xl),
      child: Center(
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: AppTheme.durationSlow,
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXl),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_off,
                      size: 60,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              "No files found",
              style: GoogleFonts.nunito(
                fontSize: 20,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              "Try a different search term",
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ...existing code...

  Widget _buildQuickLinks(BuildContext context) {
    final theme = Theme.of(context);
    final quickLinks = [
      {
        'label': 'Timetable',
        'icon': Icons.calendar_today,
        'route': '/timetable',
        'color': AppColors.accentTeal,
      },
      {
        'label': 'Resources',
        'icon': Icons.folder_open,
        'route': '/resources',
        'color': AppColors.secondaryViolet,
      },
      {
        'label': 'Notes',
        'icon': Icons.note,
        'route': '/notes',
        'color': AppColors.warning,
      },
      {
        'label': 'Profile',
        'icon': Icons.person,
        'route': '/profile',
        'color': AppColors.secondaryBlue,
      },
      {
        'label': 'Notifications',
        'icon': Icons.notifications,
        'route': '/notifications',
        'color': AppColors.error,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
      child: SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: quickLinks.length,
          separatorBuilder: (context, i) => const SizedBox(width: 18),
          itemBuilder: (context, i) {
            final link = quickLinks[i];
            return BounceWrapper(
              onTap: () => context.push(link['route'] as String),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: (link['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      link['icon'] as IconData,
                      color: link['color'] as Color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    link['label'] as String,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Unused method replaced by _buildSliverSearchResults

  Widget _buildFileCard(BuildContext context, FirebaseFile file) {
    final theme = Theme.of(context);
    final pathParts = file.path.split('/');
    final folderContext =
        pathParts.length > 1 ? pathParts[pathParts.length - 2] : "General";

    return BounceWrapper(
      onTap: () => _openFile(context, file),
      child: EnhancedCard(
        isGlass: true,
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            _getFileIcon(file.name),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 14,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: AppTheme.spacingXs),
                      Expanded(
                        child: Text(
                          folderContext,
                          style: GoogleFonts.nunito(
                            color: theme.hintColor,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.iconTheme.color?.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    late Color color;
    late IconData icon;

    switch (ext) {
      case 'pdf':
        color = const Color(0xFFFF6B6B);
        icon = Icons.picture_as_pdf;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        color = const Color(0xFF4ECDC4);
        icon = Icons.image;
        break;
      case 'doc':
      case 'docx':
        color = const Color(0xFF4A90E2);
        icon = Icons.description;
        break;
      default:
        color = AppColors.textSecondary;
        icon = Icons.insert_drive_file;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildHeader(BuildContext context, String name, int streak) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    final photoURL = user?.photoURL;
    final hasPhoto = photoURL != null && photoURL.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile avatar
          Semantics(
            label: 'Profile',
            button: true,
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      AppColors.accentTeal,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage:
                      hasPhoto ? CachedNetworkImageProvider(photoURL) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: AppTheme.durationSlow,
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    "Jambo, $name!",
                    style: GoogleFonts.quicksand(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getGreetingSubtitle(),
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          Stack(
            children: [
              Semantics(
                label: 'Notifications',
                button: true,
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationInboxScreen()),
                    );
                  },
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    size: 26,
                  ),
                ),
              ),
              Consumer<NotificationProvider>(
                builder: (context, provider, child) {
                  if (provider.unreadCount == 0) return const SizedBox.shrink();
                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreetingSubtitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning! Ready to learn?";
    if (hour < 17) return "Good afternoon! Keep it up!";
    return "Good evening! Let's review today.";
  }

  Widget _buildAiTutorHero(BuildContext context) {
    return BounceWrapper(
      onTap: () => context.push('/ai-tutor'),
      child: GlassCard(
        borderRadius: AppTheme.radiusXl,
        padding: const EdgeInsets.all(24),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.accentTeal.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      "MOST POPULAR",
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Chat with\nyour AI Tutor",
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Snap a photo or ask anything\nto get instant help!",
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: BounceWrapper(
        onTap: () {
          context.push('/career-compass');
        },
        child: GlassCard(
          borderRadius: AppTheme.radiusXl,
          padding: const EdgeInsets.all(24),
          gradient: LinearGradient(
            colors: [
              AppColors.kidPurple.withValues(alpha: 0.7),
              AppColors.kidPink.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        "ADVENTURE AWAITS",
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Explore Your\nFuture!",
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Start Journey",
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w800,
                              color: AppColors.kidPurple,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.rocket_launch_rounded,
                            size: 18,
                            color: AppColors.kidPurple,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Hero(
                tag: 'hero_rocket',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReusableSearchBar extends StatefulWidget {
  final Function(String) onSearchChanged;

  const _ReusableSearchBar({
    required this.onSearchChanged,
  });

  @override
  State<_ReusableSearchBar> createState() => _ReusableSearchBarState();
}

class _ReusableSearchBarState extends State<_ReusableSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onSearchChanged(value);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search files, notes, topics...',
          hintStyle: GoogleFonts.nunito(color: theme.hintColor),
          prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _controller.clear();
                    _debounce?.cancel();
                    widget.onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }
}
