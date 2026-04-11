import 'package:flutter/material.dart';
import '../utils/cors_proxy_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class InteractiveMermaidViewer extends StatelessWidget {
  final String imageUrl;
  final String diagramSource;

  const InteractiveMermaidViewer({
    super.key,
    required this.imageUrl,
    required this.diagramSource,
  });

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullScreenViewer(
          imageUrl: imageUrl,
          diagramSource: diagramSource,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : theme.dividerColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Zoom Prompt
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_mosaic_outlined, 
                    size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Interactive Diagram',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.zoom_in_rounded, 
                    size: 14, color: theme.primaryColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to zoom',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.primaryColor.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Preview Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: Hero(
                tag: imageUrl,
                child: CachedNetworkImage(
                  imageUrl: CorsProxyHelper.getCorsProxyUrl(imageUrl),
                  httpHeaders: CorsProxyHelper.standardHeaders,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => _ErrorPlaceholder(
                    source: diagramSource,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenViewer extends StatelessWidget {
  final String imageUrl;
  final String diagramSource;

  const _FullScreenViewer({
    required this.imageUrl,
    required this.diagramSource,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.textTheme.titleLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Diagram Viewer',
          style: GoogleFonts.plusJakartaSans(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.code, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
            onPressed: () => _showSource(context),
            tooltip: 'View Source',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: imageUrl,
                    child: CachedNetworkImage(
                      imageUrl: CorsProxyHelper.getCorsProxyUrl(imageUrl),
                      httpHeaders: CorsProxyHelper.standardHeaders,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Pinch to zoom • Drag to pan',
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white54 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSource(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.code_rounded, color: theme.textTheme.titleLarge?.color),
                const SizedBox(width: 12),
                Text(
                  'Mermaid Source',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                diagramSource,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  final String source;
  final bool isDark;
  const _ErrorPlaceholder({required this.source, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50,
      child: Column(
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.red),
          const SizedBox(height: 8),
          Text(
            'Failed to render diagram',
            style: GoogleFonts.dmSans(color: Colors.red, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: Text("View Source", style: GoogleFonts.dmSans(fontSize: 12)),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  source,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
