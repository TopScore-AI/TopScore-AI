import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/resources_provider.dart';
import '../../widgets/resources/resource_file_card.dart';
import '../../widgets/resources/resource_states.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All Files',
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
                "Explorer Library",
                style: GoogleFonts.plusJakartaSans(
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                        labelColor: theme.primaryColor,
                        unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                        indicator: UnderlineTabIndicator(
                          borderSide: BorderSide(width: 3.0, color: theme.primaryColor),
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
          children: _categories.map((_) => _buildLibraryContent()).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, ThemeData theme) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
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
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded, 
            color: theme.primaryColor.withValues(alpha: 0.6),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
  Widget _buildLibraryContent() {
    return Consumer<ResourcesProvider>(
      builder: (context, provider, child) {
        if (provider.state == ResourceState.loading && provider.files.isEmpty) {
          return const ResourceShimmer();
        }
        
        if (provider.state == ResourceState.empty || (provider.state != ResourceState.loading && provider.files.isEmpty)) {
          return ResourceEmptyState(onRefresh: () => _fetchMaterials(isRefresh: true));
        }

        if (provider.state == ResourceState.error) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                 const SizedBox(height: 16),
                 const Text("Failed to load resources"),
                 TextButton(onPressed: () => _fetchMaterials(isRefresh: true), child: const Text("Retry"))
               ],
             ),
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
                // Load more indicator
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fetchMaterials();
                });
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ));
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
