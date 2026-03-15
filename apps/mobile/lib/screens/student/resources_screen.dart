import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_debounce/easy_debounce.dart';

import '../../providers/auth_provider.dart';
import '../../providers/resources_provider.dart';
import '../../models/firebase_file.dart';
import '../../config/app_theme.dart';
import '../../constants/colors.dart';
import '../../widgets/resources/resource_file_card.dart';
import '../../widgets/resources/resource_states.dart';
import '../../widgets/resources/recommended_files_section.dart';
import '../../utils/responsive_layout.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All Files',
    'CBC Files',
    'Notes',
    'Lesson Plans',
    'Schemes Of Work',
    '844 Files',
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialCategory != null
        ? _categories.indexWhere((c) =>
            c.toLowerCase() == widget.initialCategory!.toLowerCase())
        : -1;
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _tabController.addListener(_handleTabChange);

    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitial();
      _fetchRecommendations();
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final category = _categories[_tabController.index];
      context.read<ResourcesProvider>().setCategory(category);
      _fetchInitial();
    }
  }

  void _fetchRecommendations() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userModel != null) {
      context
          .read<ResourcesProvider>()
          .fetchRecommendations(user: authProvider.userModel!);
    }
  }

  void _onScroll() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userModel != null) {
      context
          .read<ResourcesProvider>()
          .fetchFiles(user: authProvider.userModel!);
    }
  }

  void _fetchInitial({bool isRefresh = false}) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userModel != null) {
      context.read<ResourcesProvider>().fetchFiles(
            user: authProvider.userModel!,
            isRefresh: isRefresh,
          );
    }
  }

  void _onSearchChanged(String query) {
    setState(() {}); // Refresh to show/hide clear icon
    EasyDebounce.debounce(
      'resource-search',
      const Duration(milliseconds: 500),
      () {
        final provider = context.read<ResourcesProvider>();
        provider.setSearchQuery(query);
        _fetchInitial(isRefresh: true);
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    EasyDebounce.cancel('resource-search');
    final provider = context.read<ResourcesProvider>();
    provider.setSearchQuery('');
    _fetchInitial(isRefresh: true);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(theme, user),
          _buildSearchAndFilters(theme),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((_) => _buildResourceList()).toList(),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, dynamic user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: CenterContent(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learning Resources',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user != null
                      ? [user.educationLevel ?? user.curriculum, user.gradeLabel]
                          .where(
                              (e) => e != null && e.toString().trim().isNotEmpty)
                          .join(' • ')
                      : 'Access your study materials',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: CenterContent(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: AppTheme.searchFieldDecoration(
                      hint: 'Search notes, papers...',
                    ).copyWith(
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: _categories.map((title) {
                    if (title == 'Curriculum') {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      return Tab(
                        text: (authProvider.userModel?.educationLevel ??
                                authProvider.userModel?.curriculum ??
                                'CBC')
                            .toUpperCase(),
                      );
                    }
                    return Tab(text: title);
                  }).toList(),
                ),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
        115.0, // Fixed height for the header
      ),
    );
  }

  Widget _buildResourceList() {
    return Consumer<ResourcesProvider>(
      builder: (context, provider, child) {
        if (provider.state == ResourceState.initial ||
            (provider.state == ResourceState.loading &&
                provider.files.isEmpty)) {
          return const ResourceShimmer();
        }

        if (provider.state == ResourceState.error) {
          return ResourceErrorState(
              onRetry: () => _fetchInitial(isRefresh: true));
        }

        if (provider.state == ResourceState.empty) {
          return ResourceEmptyState(
              onRefresh: () => _fetchInitial(isRefresh: true));
        }

        final files = provider.files;
        final showRecommendations = provider.searchQuery.isEmpty &&
            (provider.recommendations.isNotEmpty ||
                provider.recommendationsLoading);

        return RefreshIndicator(
          onRefresh: () async => _fetchInitial(isRefresh: true),
          color: AppColors.primary,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200) {
                _onScroll();
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                // Recommendations section (only when not searching)
                if (showRecommendations)
                  SliverToBoxAdapter(
                    child: RecommendedFilesSection(
                      recommendations: provider.recommendations,
                      isLoading: provider.recommendationsLoading,
                      onFileTap: _openFile,
                    ),
                  ),
                // Main file list
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: ResponsiveLayout.isMobile(context)
                      ? SliverList.separated(
                          itemCount: files.length + (provider.hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            if (index == files.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2),
                                ),
                              );
                            }

                            final file = files[index];
                            return ResourceFileCard(
                              file: file,
                              onTap: () => _openFile(file),
                            );
                          },
                        )
                      : SliverGrid(
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisExtent: 100,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index == files.length) {
                                return const Center(
                                  child: CircularProgressIndicator.adaptive(),
                                );
                              }
                              final file = files[index];
                              return ResourceFileCard(
                                file: file,
                                onTap: () => _openFile(file),
                              );
                            },
                            childCount: files.length + (provider.hasMore ? 1 : 0),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFile(FirebaseFile file) {
    if (file.downloadUrl != null) {
      // Track recently opened
      context.read<ResourcesProvider>().trackFileOpen(file);

      context.push('/pdf-viewer', extra: {
        'url': file.downloadUrl,
        'title': file.displayName,
        'storagePath': file.path,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File details not available')),
      );
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._child, this.height);

  final Widget _child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
