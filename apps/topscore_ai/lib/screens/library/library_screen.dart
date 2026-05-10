import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resources_provider.dart';
import '../../widgets/resources/resource_file_card.dart';
import '../../widgets/resources/resource_states.dart';
import '../../shared/services/media_picker_service.dart';
import '../../widgets/app_spinner.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All Files',
    'Local Files',
    'CBC Files',
    'IGCSE Files',
    '8-4-4 Files',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final provider = context.read<ResourcesProvider>();
        provider.setCategory(_categories[_tabController.index]);
        _fetchMaterials(isRefresh: true);
      }
    });

    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ResourcesProvider>();
      provider.setCategory(_categories[_tabController.index]);
      _fetchMaterials();
    });
  }

  void _fetchMaterials({bool isRefresh = false}) {
    final authProvider = context.read<AuthProvider>();
    context.read<ResourcesProvider>().fetchFiles(
          user: authProvider.userModel,
          isRefresh: isRefresh,
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                "Resources Library",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              centerTitle: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              floating: true,
              pinned: true,
              snap: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(130),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: _buildSearchBar(isDark, theme),
                    ),
                    const SizedBox(height: 8),
                    // Categories TabBar
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: AppColors.topscoreBlue,
                        unselectedLabelColor: isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                        indicator: UnderlineTabIndicator(
                          borderSide: const BorderSide(
                              width: 3.0, color: AppColors.topscoreBlue),
                          insets: const EdgeInsets.symmetric(horizontal: 16.0),
                        ),
                        dividerColor: Colors.transparent,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        tabs: _categories.map((cat) => Tab(text: cat)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((cat) {
            if (cat == 'Local Files') {
              return _buildLocalFilesContent();
            }
            return _buildLibraryContent();
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, ThemeData theme) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          context.read<ResourcesProvider>().setSearchQuery(val);
          _fetchMaterials(isRefresh: true);
        },
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: "Search curricula, topics, grades...",
          hintStyle: GoogleFonts.plusJakartaSans(
            color: isDark ? theme.textTheme.bodySmall?.color : theme.hintColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.primaryColor.withValues(alpha: 0.6),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLocalFilesContent() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Local Files",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Open any PDF from your device to study it with TopScore AI Tutor.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickLocalPdf,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Open Local PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocalPdf() async {
    try {
      // Use MediaPickerService which handles platform-specific details and
      // doesn't block on redundant permission checks that fail on Android 13+.
      final results = await MediaPickerService.instance.pickFiles(
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (results.isNotEmpty) {
        final picked = results.first;
        if (picked.filePath != null) {
          if (mounted) {
            // On web, we need to use bytes instead of File
            // because File operations are not supported
            context.push('/pdf-viewer', extra: {
              if (picked.bytes != null) 'bytes': picked.bytes,
              if (picked.filePath != null && picked.bytes == null)
                'file': File(picked.filePath!),
              'title': picked.name,
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening file: $e")),
        );
      }
    }
  }

  Widget _buildLibraryContent() {
    return Consumer<ResourcesProvider>(
      builder: (context, provider, child) {
        if (provider.state == ResourceState.loading && provider.files.isEmpty) {
          return const ResourceShimmer();
        }

        if (provider.state == ResourceState.empty ||
            (provider.state != ResourceState.loading &&
                provider.files.isEmpty)) {
          return ResourceEmptyState(
              onRefresh: () => _fetchMaterials(isRefresh: true));
        }

        if (provider.state == ResourceState.error) {
          return ResourceErrorState(
            onRetry: () => _fetchMaterials(isRefresh: true),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _fetchMaterials(isRefresh: true),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: provider.files.length + (provider.hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == provider.files.length) {
                // Trigger load-more once, not on every rebuild
                Future.microtask(() {
                  if (mounted) _fetchMaterials();
                });
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: AppSpinner(),
                  ),
                );
              }

              final file = provider.files[index];
              return ResourceFileCard(
                file: file,
                onTap: () {
                  // Track open
                  final auth = context.read<AuthProvider>();
                  provider.trackFileOpen(file, userId: auth.userModel?.uid);

                  context.push('/pdf-viewer', extra: {
                    'url': file.downloadUrl,
                    'title': file.displayName,
                  });
                },
              );
            },
          ),
        );
      },
    );
  }
}
