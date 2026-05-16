import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../widgets/app_spinner.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/sharing_utils.dart';
import '../../utils/web_download_helper.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;
  final bool isBase64;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.isBase64 = false,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    if (_isDownloading) return;

    if (widget.isBase64) {
      final bytes = base64Decode(widget.imageUrl.split(',').last);
      final filename = 'topscore_${DateTime.now().millisecondsSinceEpoch}.png';
      if (kIsWeb) {
        WebDownloadHelper.downloadBytes(bytes, filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          text: 'Shared from TopScore AI',
        ));
      }
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final filename =
            'topscore_${DateTime.now().millisecondsSinceEpoch}.png';

        if (kIsWeb) {
          WebDownloadHelper.downloadBytes(bytes, filename);
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$filename');
          await file.writeAsBytes(bytes);

          await SharePlus.instance.share(ShareParams(
            files: [XFile(file.path)],
            text: 'Shared from TopScore AI',
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 800) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(CupertinoIcons.xmark,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          actions: [
            // Download Button
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              AppSpinner(strokeWidth: 2, color: Colors.white))
                      : const Icon(CupertinoIcons.cloud_download,
                          color: Colors.white, size: 20),
                  onPressed: _handleDownload,
                ),
              ),
            ),
            // Share Button
            if (!widget.isBase64)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.share,
                        color: Colors.white, size: 20),
                    onPressed: () {
                      final cleanLink =
                          SharingUtils.generateShareLink(widget.imageUrl);
                      SharePlus.instance.share(ShareParams(
                        text: 'Check this out on TopScore AI:\n$cleanLink',
                      ));
                    },
                  ),
                ),
              ),
          ],
        ),
        body: PhotoView(
          imageProvider: widget.isBase64
              ? MemoryImage(base64Decode(widget.imageUrl.split(',').last))
                  as ImageProvider
              : CachedNetworkImageProvider(widget.imageUrl),
          loadingBuilder: (context, event) => const Center(
            child: AppSpinner(color: Colors.white),
          ),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white38, size: 40),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4.1,
          heroAttributes: widget.heroTag != null
              ? PhotoViewHeroAttributes(tag: widget.heroTag!)
              : null,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const PdfViewerScreen({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SfPdfViewer.network(
        url,
        onDocumentLoadFailed: (details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to load PDF: ${details.description}')),
          );
        },
      ),
    );
  }
}
