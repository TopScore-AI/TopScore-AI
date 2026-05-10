import 'package:flutter/material.dart';
import '../../widgets/app_spinner.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/sharing_utils.dart';
import '../tutor_client/widgets/chat_media_viewers.dart';
import 'package:go_router/go_router.dart';

class SharePreviewScreen extends StatefulWidget {
  final String fileId;

  const SharePreviewScreen({super.key, required this.fileId});

  @override
  State<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends State<SharePreviewScreen> {
  String? _downloadUrl;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl() async {
    final path = SharingUtils.decodeShareSlug(widget.fileId);
    if (path == null) {
      if (mounted) {
        setState(() {
          _error = 'Invalid link';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final ref = FirebaseStorage.instance.ref(path);
      final url = await ref.getDownloadURL();
      if (mounted) {
        setState(() {
          _downloadUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Storage Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Shared File',
            style:
                GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (_downloadUrl != null)
            IconButton(
              icon: const Icon(CupertinoIcons.fullscreen),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      FullScreenImageViewer(imageUrl: _downloadUrl!),
                ));
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return AppSpinner.center();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle,
                  color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go Home')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: _downloadUrl!,
                placeholder: (context, url) => const SizedBox(
                    height: 200, child: Center(child: AppSpinner())),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Shared from TopScore AI',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the image to view in full screen or use the button below to download.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      // We will implement the download logic later in the viewers
                      // but here we can at least show the viewer
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            FullScreenImageViewer(imageUrl: _downloadUrl!),
                      ));
                    },
                    icon: const Icon(CupertinoIcons.cloud_download),
                    label: const Text('Open & Download'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go to Community Hub'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
