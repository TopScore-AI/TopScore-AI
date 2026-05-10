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
import '../../widgets/app_spinner.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

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
    'IGCSE Files',
    '844 Files',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Sync the provider's initial category to match the first tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResourcesProvider>().setCategory(_categories[0]);
      _fetchInitialOrWait();
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final category = _categories[_tabController.index];
      context.read<ResourcesProvider>().setCategory(category);
      _fetchInitial();
      setState(() {}); // Rebuild to update FAB visibility
    }
  }

  void _onScroll() {
    final authProvider = context.read<AuthProvider>();
    context.read<ResourcesProvider>().fetchFiles(user: authProvider.userModel);
  }

  /// Try to fetch files. If userModel isn't available yet (common on Android
  /// where native boot is slower), listen for auth changes and retry once.
  void _fetchInitialOrWait() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userModel != null) {
      _fetchInitial();
    } else {
      // userModel isn't loaded yet — wait for it
      void listener() {
        if (!mounted) {
          authProvider.removeListener(listener);
          return;
        }
        if (authProvider.userModel != null) {
          authProvider.removeListener(listener);
          _fetchInitial();
        }
      }

      authProvider.addListener(listener);
    }
  }

  void _fetchInitial({bool isRefresh = false}) {
    final authProvider = context.read<AuthProvider>();
    // Allow fetching even for guests (userModel can be null → defaults apply)
    context.read<ResourcesProvider>().fetchFiles(
          user: authProvider.userModel,
          isRefresh: isRefresh,
        );
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
    final isDark = theme.brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [AppColors.backgroundDark, AppColors.surfaceDark]
                        : [
                            AppColors.primary.withValues(alpha: 0.05),
                            Colors.white
                          ],
                  ),
                ),
              ),
            ),
            // Subtle decorative circles
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.03),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_stories_rounded,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Resource Center',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1)),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_rounded,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "${user.educationLevel ?? user.curriculum} • ${user.gradeLabel}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Access premium study materials',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: theme.hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
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
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: files.length + (provider.hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == files.length) {
                  return AppSpinner.paginate();
                }

                final file = files[index];
                return ResourceFileCard(
                  file: file,
                  onTap: () => _openFile(file),
                );
              },
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
