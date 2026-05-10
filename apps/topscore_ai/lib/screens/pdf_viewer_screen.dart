import 'dart:async';
import 'package:universal_io/io.dart';
import 'dart:ui' as ui;

import 'package:croppy/croppy.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/download_provider.dart';
import '../providers/tutor_connection_provider.dart';
import '../services/feature_gate_service.dart';
import '../widgets/premium_feature_dialog.dart';
import 'package:easy_debounce/easy_debounce.dart';
import '../services/ai_service.dart';
import '../services/isar_service.dart';
import '../services/tts_service.dart';
import '../tutor_client/widgets/embedded_chat_sheet.dart';
import '../widgets/quick_explain_overlay.dart';
import '../tutor_client/enhanced_websocket_service.dart';
import '../models/download_model.dart';
import 'package:flutter/cupertino.dart';

import '../widgets/app_spinner.dart';

// ---------------------------------------------------------------------------
// PdfViewerScreen — production-grade PDF reader
// ---------------------------------------------------------------------------
class PdfViewerScreen extends StatefulWidget {
  final String? storagePath;
  final String? url;
  final String? assetPath;
  final Uint8List? bytes;
  final File? file;
  final String title;

  const PdfViewerScreen({
    super.key,
    this.storagePath,
    this.url,
    this.assetPath,
    this.bytes,
    this.file,
    required this.title,
  }) : assert(
          storagePath != null ||
              url != null ||
              assetPath != null ||
              bytes != null ||
              file != null,
          'You must provide at least one PDF source',
        );

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with TickerProviderStateMixin {
  // Controllers
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey _pdfRepaintKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageJumpController = TextEditingController();
  final ScrollController _thumbnailScrollController = ScrollController();

  // PDF state
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubscriptionError = false;

  // Page state
  int _currentPage = 1;
  int _totalPages = 0;

  // UI state
  bool _showSearchBar = false;
  bool _showThumbnails = false;
  bool _isContinuousScroll = true;
  double _zoomLevel = 1.0;

  // Search state
  PdfTextSearchResult? _searchResult;
  int _searchMatchCount = 0;
  int _searchCurrentMatch = 0;

  // Bookmarks (page numbers)
  Set<int> _bookmarkedPages = {};
  static const String _bookmarkPrefKey = 'pdf_bookmarks_';

  // Context menu overlay
  OverlayEntry? _overlayEntry;
  OverlayEntry? _quickExplainEntry;

  // Caching
  Timer? _autoCacheTimer;
  bool _isAutoCaching = false;

  // TTS
  bool _isSpeaking = false;
  String? _lastSelectedText;
  PdfDocument? _pdfDocument;

  // Annotation mode
  bool _isAnnotating = false;
  PdfAnnotationMode _annotationMode = PdfAnnotationMode.none;
  PdfInteractionMode _interactionMode =
      kIsWeb ? PdfInteractionMode.selection : PdfInteractionMode.pan;

  // Text size (zoom preset)
  static const List<double> _textSizePresets = [0.75, 1.0, 1.25, 1.5, 2.0];
  int _textSizeIndex = 1; // default = 1.0x

  // Night mode for long reading sessions. Inverts the PDF raster colours so
  // bright white pages become soft dark — easier on the eyes.
  bool _isNightMode = false;

  // Cached resolved download URL — computed once when the PDF loads so every
  // AI action opens the sheet instantly without waiting for Firebase Storage.
  String? _cachedPdfUrl;

  // Single reading-session WebSocket service for instant explanation streaming
  EnhancedWebSocketService? _quickExplainWsService;

  // (Animations removed to keep toolbar persistent)

  @override
  void initState() {
    super.initState();
    _loadPdfData();
    _loadBookmarks();
    _initTts();
    _startAutoCacheTimer();
    // Configure default annotation settings
    _pdfViewerController.annotationSettings = PdfAnnotationSettings();
    _initQuickExplainWs();
  }

  void _initQuickExplainWs() {
    try {
      final user = context.read<AuthProvider>().userModel;
      if (user != null) {
        if (kDebugMode) {
          debugPrint('[PDF_VIEWER] Pre-initializing session WebSocket for Quick Explain...');
        }
        _quickExplainWsService = EnhancedWebSocketService(userId: user.uid);
        _quickExplainWsService!.setThreadId('quick_explain_${DateTime.now().millisecondsSinceEpoch}');
        _quickExplainWsService!.initialize().then((_) {
          if (mounted && _quickExplainWsService != null) {
            _quickExplainWsService!.connect();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PDF_VIEWER] Error initializing session WebSocket: $e');
      }
    }
  }

  void _disposeQuickExplainWs() {
    if (kDebugMode) {
      debugPrint('[PDF_VIEWER] Closing and disposing session WebSocket...');
    }
    _quickExplainWsService?.dispose();
    _quickExplainWsService = null;
  }

  @override
  void dispose() {
    _disposeQuickExplainWs();
    _autoCacheTimer?.cancel();
    _dismissContextMenu();
    _dismissQuickExplainOverlay();
    _searchController.dispose();
    _pageJumpController.dispose();
    _thumbnailScrollController.dispose();
    _pdfViewerController.dispose();
    TtsService().stop();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Toolbar auto-hide
  // ---------------------------------------------------------------------------
  // void _resetToolbarTimer() { ... } removed to keep toolbar persistent

  void _keepToolbarVisible() {
    // No-op: toolbar is now persistent
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------
  String get _bookmarkKey => '$_bookmarkPrefKey${widget.title}';

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_bookmarkKey) ?? [];
    setState(() {
      _bookmarkedPages = saved.map(int.parse).toSet();
    });
  }

  Future<void> _toggleBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarkedPages.contains(page)) {
        _bookmarkedPages.remove(page);
      } else {
        _bookmarkedPages.add(page);
      }
    });
    await prefs.setStringList(
      _bookmarkKey,
      _bookmarkedPages.map((p) => p.toString()).toList(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bookmarkedPages.contains(page)
            ? 'Page $page bookmarked'
            : 'Bookmark removed'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // TTS — Read Aloud
  // ---------------------------------------------------------------------------
  Future<void> _initTts() async {
    final tts = TtsService();
    await tts.init();
    tts.onComplete = () {
      if (mounted) setState(() => _isSpeaking = false);
    };
    tts.onCancel = () {
      if (mounted) setState(() => _isSpeaking = false);
    };
    tts.onStart = () {
      if (mounted) setState(() => _isSpeaking = true);
    };
  }

  Future<void> _speakText(String text) async {
    if (_isSpeaking) {
      await _stopTts();
      return;
    }
    // We rely on TtsService handlers to update _isSpeaking via initTts callbacks
    await TtsService().speak(text);
  }

  Future<void> _stopTts() async {
    await TtsService().stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _readCurrentPage() async {
    if (_pdfDocument == null) return;
    try {
      final pageIndex = _currentPage - 1;
      final text = PdfTextExtractor(_pdfDocument!)
          .extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
      if (text.trim().isNotEmpty) {
        await _speakText(text);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No readable text found on this page'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error extracting page text: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Text size
  // ---------------------------------------------------------------------------
  void _increaseTextSize() {
    if (_textSizeIndex < _textSizePresets.length - 1) {
      _textSizeIndex++;
      final z = _textSizePresets[_textSizeIndex];
      _pdfViewerController.zoomLevel = z;
      setState(() => _zoomLevel = z);
    }
  }

  void _decreaseTextSize() {
    if (_textSizeIndex > 0) {
      _textSizeIndex--;
      final z = _textSizePresets[_textSizeIndex];
      _pdfViewerController.zoomLevel = z;
      setState(() => _zoomLevel = z);
    }
  }

  void _showTextSizeDialog() {
    _keepToolbarVisible();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Text Size',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _textSizePresets.asMap().entries.map((e) {
                  final isSelected = e.key == _textSizeIndex;
                  final label = '${(e.value * 100).round()}%';
                  return GestureDetector(
                    onTap: () {
                      _textSizeIndex = e.key;
                      _pdfViewerController.zoomLevel = e.value;
                      setState(() => _zoomLevel = e.value);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _decreaseTextSize();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.text_decrease_rounded),
                      label: const Text('Smaller'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        _increaseTextSize();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.text_increase_rounded),
                      label: const Text('Larger'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Annotations
  // ---------------------------------------------------------------------------
  void _toggleAnnotationMode(PdfAnnotationMode mode) {
    setState(() {
      if (_annotationMode == mode) {
        _annotationMode = PdfAnnotationMode.none;
        _isAnnotating = false;
      } else {
        _annotationMode = mode;
        _isAnnotating = true;
      }
      // Update controller mode
      _pdfViewerController.annotationMode = _annotationMode;
    });
    _keepToolbarVisible();
  }

  void _showAnnotationToolbar() {
    _keepToolbarVisible();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Annotations',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _annotationChip(ctx, Icons.highlight_rounded, 'Highlight',
                      PdfAnnotationMode.highlight, Colors.yellow),
                  _annotationChip(ctx, Icons.format_underlined_rounded,
                      'Underline', PdfAnnotationMode.underline, Colors.blue),
                  _annotationChip(
                      ctx,
                      Icons.strikethrough_s_rounded,
                      'Strikethrough',
                      PdfAnnotationMode.strikethrough,
                      Colors.red),
                  _annotationChip(
                      ctx,
                      Icons.sticky_note_2_rounded,
                      'Sticky Note',
                      PdfAnnotationMode.stickyNote,
                      Colors.orange),
                ],
              ),
              if (_isAnnotating) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _annotationMode = PdfAnnotationMode.none;
                        _isAnnotating = false;
                      });
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Stop Annotating'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _annotationChip(BuildContext ctx, IconData icon, String label,
      PdfAnnotationMode mode, Color color) {
    final isActive = _annotationMode == mode;
    return GestureDetector(
      onTap: () {
        _toggleAnnotationMode(mode);
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.2)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  void _startAutoCacheTimer() {
    if (kIsWeb || widget.url == null) return;
    _autoCacheTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) _autoCachePdf();
    });
  }

  Future<void> _autoCachePdf() async {
    if (widget.url == null || _isAutoCaching) return;
    final downloadProvider = context.read<DownloadProvider>();
    if (downloadProvider.isDownloaded(widget.url!)) return;

    setState(() => _isAutoCaching = true);
    try {
      await downloadProvider.downloadGenericFile(
        id: widget.url!,
        title: widget.title,
        downloadUrl: widget.url!,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("[TOPSCORE] Auto-cache failed: $e");
    } finally {
      if (mounted) setState(() => _isAutoCaching = false);
    }
  }

  // ---------------------------------------------------------------------------
  // PDF Loading
  // ---------------------------------------------------------------------------
  Future<void> _loadPdfData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check local cache (DownloadProvider) on mobile
      if (!kIsWeb && widget.url != null) {
        final downloadProvider = context.read<DownloadProvider>();
        final downloads = downloadProvider.downloads;
        final cachedTask = downloads.firstWhere(
          (t) => t.resourceId == widget.url || t.id == widget.url,
          orElse: () => DownloadTaskModel(
              id: '',
              resourceId: '',
              localPath: '',
              downloadedAt: 0,
              filename: ''),
        );

        if (cachedTask.localPath.isNotEmpty) {
          final file = File(cachedTask.localPath);
          if (await file.exists()) {
            final loadedBytes = await file.readAsBytes();
            if (mounted) {
              setState(() {
                _pdfBytes = loadedBytes;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      final docId =
          widget.storagePath ?? widget.url ?? widget.assetPath ?? widget.title;
      if (!mounted) return;

      // Bypass access check for local files or bytes
      bool canAccess = true;
      if (widget.file == null && widget.bytes == null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        canAccess = await authProvider.tryAccessDocument(docId);
      }

      if (!canAccess) {
        if (mounted) {
          setState(() {
            _isSubscriptionError = true;
            _isLoading = false;
          });
        }
        return;
      }

      Uint8List? loadedBytes;

      if (widget.bytes != null) {
        loadedBytes = widget.bytes;
      } else if (widget.url != null) {
        final url = widget.url!;
        final isWordDoc = url.toLowerCase().contains('.doc') ||
            url.toLowerCase().contains('.docx');

        if (isWordDoc) {
          if (mounted) setState(() => _isLoading = true);
          loadedBytes = await AIService().convertToPdf(url);
        } else {
          final extractedPath = _extractPathFromFirebaseUrl(url);
          if (extractedPath != null) {
            try {
              if (kDebugMode) {
                debugPrint('Extracted path from GCS URL: $extractedPath');
              }
              loadedBytes = await FirebaseStorage.instance
                  .ref(extractedPath)
                  .getData(30 * 1024 * 1024);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('SDK fetch from extracted path failed: $e');
              }
              loadedBytes = await _downloadFromUrl(url);
            }
          } else if (_isFirebaseStorageUrl(url)) {
            try {
              loadedBytes = await FirebaseStorage.instance
                  .refFromURL(url)
                  .getData(30 * 1024 * 1024);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    'SDK refFromURL failed, falling back to download: $e');
              }
              loadedBytes = await _downloadFromUrl(url);
            }
          } else {
            loadedBytes = await _downloadFromUrl(url);
          }
        }
      } else if (widget.storagePath != null) {
        final path = widget.storagePath!;
        if (path.startsWith('http')) {
          final extractedPath = _extractPathFromFirebaseUrl(path);
          if (extractedPath != null) {
            try {
              if (kDebugMode) {
                debugPrint('Extracted path from GCS URL: $extractedPath');
              }
              loadedBytes = await FirebaseStorage.instance
                  .ref(extractedPath)
                  .getData(30 * 1024 * 1024);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('SDK fetch from extracted path failed: $e');
              }
              loadedBytes = await _downloadFromUrl(path);
            }
          } else if (_isFirebaseStorageUrl(path)) {
            try {
              loadedBytes = await FirebaseStorage.instance
                  .refFromURL(path)
                  .getData(30 * 1024 * 1024);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    'SDK refFromURL failed for storagePath, falling back to download: $e');
              }
              loadedBytes = await _downloadFromUrl(path);
            }
          } else {
            loadedBytes = await _downloadFromUrl(path);
          }
        } else {
          try {
            loadedBytes = await FirebaseStorage.instance
                .ref(path)
                .getData(30 * 1024 * 1024);
            if (loadedBytes == null) throw Exception('File is empty');
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
              if (mounted) {
                setState(() {
                  _isSubscriptionError = true;
                  _isLoading = false;
                });
              }
              return;
            }
            rethrow;
          }
        }
      } else if (widget.assetPath != null) {
        final byteData = await rootBundle.load(widget.assetPath!);
        loadedBytes = byteData.buffer.asUint8List();
      } else if (widget.file != null) {
        // On web, File operations are not supported
        if (kIsWeb) {
          throw UnsupportedError(
              'File operations are not supported on web. Please use bytes or URL instead.');
        }
        loadedBytes = await widget.file!.readAsBytes();
      }

      if (mounted) {
        setState(() {
          _pdfBytes = loadedBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading PDF: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _isFirebaseStorageUrl(String url) {
    if (url.contains('firebasestorage.googleapis.com')) return true;
    if (url.contains('storage.googleapis.com')) {
      // Check if it belongs to this project's default bucket or general firebase storage apps
      if (url.contains('firebasestorage.app')) return true;
      if (url.contains('elimisha-90787')) return true;
    }
    if (url.startsWith('gs://')) return true;
    return false;
  }

  String? _extractPathFromFirebaseUrl(String url) {
    try {
      final decodedUrl = Uri.decodeFull(url);

      // storage.googleapis.com format:
      // https://storage.googleapis.com/BUCKET/PATH?Expires=...
      if (decodedUrl.contains('storage.googleapis.com/')) {
        final uri = Uri.parse(decodedUrl);
        if (uri.pathSegments.length > 1) {
          // Skip bucket name, return rest of segments joined
          return uri.pathSegments.sublist(1).join('/');
        }
      }

      // firebasestorage.googleapis.com format:
      // https://firebasestorage.googleapis.com/v0/b/BUCKET/o/PATH?alt=media&token=...
      // or similar
      if (decodedUrl.contains('firebasestorage.googleapis.com/')) {
        final oMarker = '/o/';
        final oIndex = decodedUrl.indexOf(oMarker);
        if (oIndex != -1) {
          final pathAndQuery = decodedUrl.substring(oIndex + oMarker.length);
          return pathAndQuery.split('?').first;
        }
      }

      if (decodedUrl.startsWith('gs://')) {
        return Uri.parse(decodedUrl).path;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error extracting path from URL: $e');
    }
    return null;
  }

  Future<Uint8List> _downloadFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;

      if (kDebugMode) {
        debugPrint('Download error: ${response.statusCode}');
        debugPrint('URL: $url');
      }

      if (response.statusCode == 403) {
        throw Exception(
            'Access Forbidden (403). This is usually caused by CORS settings on the Storage bucket or an invalid signature.');
      }

      throw Exception('Failed to download: ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('HTTP Download Exception: $e');
      if (e.toString().contains('XMLHttpRequest error')) {
        throw Exception(
            'Network Error/CORS: The browser blocked the request. Ensure CORS is configured on the bucket.');
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------
  void _performSearch(String query) {
    if (query.isEmpty) return;
    _searchResult = _pdfViewerController.searchText(query);
    _searchResult?.addListener(() {
      if (mounted) {
        setState(() {
          _searchMatchCount = _searchResult?.totalInstanceCount ?? 0;
          _searchCurrentMatch = _searchResult?.currentInstanceIndex ?? 0;
        });
      }
    });
  }

  void _nextSearchResult() {
    _searchResult?.nextInstance();
  }

  void _prevSearchResult() {
    _searchResult?.previousInstance();
  }

  void _clearSearch() {
    _searchResult?.clear();
    _searchResult = null;
    _searchController.clear();
    setState(() {
      _showSearchBar = false;
      _searchMatchCount = 0;
      _searchCurrentMatch = 0;
    });
  }

  // ---------------------------------------------------------------------------
  // Page jump dialog
  // ---------------------------------------------------------------------------
  void _showPageJumpDialog() {
    _pageJumpController.text = _currentPage.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Go to page',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: _pageJumpController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 – $_totalPages',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _jumpToPage(ctx),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _jumpToPage(ctx), child: const Text('Go')),
        ],
      ),
    );
  }

  void _jumpToPage(BuildContext ctx) {
    final page = int.tryParse(_pageJumpController.text);
    if (page != null && page >= 1 && page <= _totalPages) {
      _pdfViewerController.jumpToPage(page);
      Navigator.pop(ctx);
    }
  }

  // ---------------------------------------------------------------------------
  // Context menu
  // ---------------------------------------------------------------------------
  void _dismissContextMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _dismissQuickExplainOverlay() {
    _quickExplainEntry?.remove();
    _quickExplainEntry = null;
  }

  void _showQuickExplainOverlay(String text, Offset position) {
    _dismissContextMenu();
    _dismissQuickExplainOverlay();
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _quickExplainEntry = OverlayEntry(
      builder: (context) => Directionality(
        textDirection: textDirection,
        child: QuickExplainOverlay(
          text: text,
          position: position,
          onClose: _dismissQuickExplainOverlay,
          externalWsService: _quickExplainWsService,
          onOpenInChat: (currentExplanation) {
            _dismissQuickExplainOverlay();
            _openAiTutorBottomSheet(
              initialMessage:
                  "I was just reading this explanation:\n\n$currentExplanation\n\nCan you tell me more about '$text'?",
            );
          },
        ),
      ),
    );
    Overlay.of(context).insert(_quickExplainEntry!);
  }

  // ---------------------------------------------------------------------------
  // PDF URL pre-warming — resolves once, cached for the session
  // ---------------------------------------------------------------------------
  Future<void> _prewarmPdfUrl() async {
    if (_cachedPdfUrl != null) return; // already resolved
    try {
      if (widget.storagePath != null) {
        _cachedPdfUrl = widget.storagePath!.startsWith('gs://')
            ? await FirebaseStorage.instance
                .refFromURL(widget.storagePath!)
                .getDownloadURL()
            : await FirebaseStorage.instance
                .ref(widget.storagePath!)
                .getDownloadURL();
      } else if (widget.url != null &&
          widget.url!.contains('firebasestorage.googleapis.com')) {
        _cachedPdfUrl = await FirebaseStorage.instance
            .refFromURL(widget.url!)
            .getDownloadURL();
      } else {
        _cachedPdfUrl = widget.url; // plain URL — use as-is
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PDF URL pre-warm failed: $e');
      _cachedPdfUrl = widget.url; // fall back to original
    }
  }

  Future<void> _openAiTutorBottomSheet(
      {String? initialMessage,
      XFile? initialImage,
      bool startVoice = false}) async {
    if (!mounted) return;

    // Check premium access for AI chat in PDF viewer
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (!FeatureGateService.canUsePdfAiChat(user)) {
      await PremiumFeatureDialog.show(
        context,
        featureName: 'AI Chat in PDF Viewer',
        icon: Icons.chat_bubble_outline,
      );
      return;
    }

    HapticFeedback.lightImpact();

    // Ensure the global AI Tutor WebSocket is active and connected immediately
    try {
      final tutorConn =
          Provider.of<TutorConnectionProvider>(context, listen: false);
      tutorConn.resume();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[PDF_VIEWER] Failed to resume global WebSocket connection: $e');
      }
    }

    // Use the cached URL if available — no async wait needed.
    // If not yet resolved (e.g. user tapped before document finished loading),
    // kick off resolution now but open the sheet immediately anyway.
    if (_cachedPdfUrl == null) {
      _prewarmPdfUrl(); // fire-and-forget; sheet opens with null url first
    }

    // Derive a human-readable title for the sheet header
    String sheetTitle = 'AI Tutor';
    if (initialMessage != null) {
      if (initialMessage.contains('summary') ||
          initialMessage.contains('summarize')) {
        sheetTitle = 'Document Summary';
      } else if (initialMessage.contains('quiz')) {
        sheetTitle = 'AI Quiz';
      } else if (initialMessage.contains('flashcard')) {
        sheetTitle = 'Flashcards';
      } else if (initialMessage.contains('diagram') || initialImage != null) {
        sheetTitle = 'Snap & Ask';
      }
    }

    // Open immediately — no await on URL resolution
    await EmbeddedChatSheet.show(
      context,
      title: sheetTitle,
      initialMessage: initialMessage,
      initialImage: initialImage,
      fileUrl: initialImage == null ? (_cachedPdfUrl ?? widget.url) : null,
      fileName: initialImage == null ? widget.title : null,
      fileType: initialImage == null ? 'application/pdf' : null,
      fileBytes: initialImage == null && (_cachedPdfUrl ?? widget.url) == null
          ? _pdfBytes
          : null,
      startVoice: startVoice,
      heightFactor: 0.88,
    );
  }

  void _showContextMenu(
      BuildContext context, PdfTextSelectionChangedDetails details) {
    _dismissContextMenu();
    if (details.globalSelectedRegion == null) return;

    final theme = Theme.of(context);
    final bg = theme.colorScheme.inverseSurface;
    final fg = theme.colorScheme.onInverseSurface;
    final region = details.globalSelectedRegion!;
    final top = (region.top - 56).clamp(8.0, double.infinity);
    final left = region.left.clamp(8.0, double.infinity);

    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: top,
        left: left,
        child: Directionality(
          textDirection: textDirection,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withValues(alpha: 0.25),
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _contextBtn(Icons.copy_rounded, 'Copy', fg, () {
                    Clipboard.setData(
                        ClipboardData(text: details.selectedText ?? ''));
                    HapticFeedback.lightImpact();
                    _dismissContextMenu();
                    _pdfViewerController.clearSelection();
                  }),
                  _divider(fg),
                  _contextBtn(FontAwesomeIcons.wandMagicSparkles, 'Explain', fg,
                      () {
                    final text = details.selectedText;
                    if (text != null) {
                      final position = Offset(region.left, region.bottom + 10);
                      _showQuickExplainOverlay(text, position);
                    }
                  }, isFa: true),
                  _divider(fg),
                  _contextBtn(Icons.summarize_rounded, 'Summarize', fg, () {
                    final text = details.selectedText;
                    if (text != null) {
                      _dismissContextMenu();
                      _pdfViewerController.clearSelection();
                      _openAiTutorBottomSheet(
                        initialMessage:
                            'Please summarize this excerpt from the PDF:\n\n"$text"',
                      );
                    }
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _contextBtn(dynamic icon, String label, Color fg, VoidCallback onTap,
      {bool isFa = false}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: isFa
          ? FaIcon(icon as IconData, color: fg, size: 13)
          : Icon(icon as IconData, color: fg, size: 16),
      label: Text(label, style: TextStyle(color: fg, fontSize: 13)),
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
    );
  }

  Widget _divider(Color fg) =>
      Container(width: 1, height: 20, color: fg.withValues(alpha: 0.25));

  // ---------------------------------------------------------------------------
  // Capture & AI
  // ---------------------------------------------------------------------------
  Future<Uint8List?> _captureVisibleArea() async {
    try {
      final boundary = _pdfRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      // Cap at 1.5x — enough for AI analysis, avoids large memory allocation
      final ratio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 1.5);
      final image = await boundary.toImage(pixelRatio: ratio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose(); // free GPU memory immediately
      return byteData?.buffer.asUint8List();
    } catch (e) {
      if (kDebugMode) debugPrint('Capture failed: $e');
      return null;
    }
  }

  Future<void> _captureAndAction() async {
    final fullBytes = await _captureVisibleArea();
    if (!mounted) return;
    if (fullBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture view')));
      return;
    }

    // Small delay to ensure memory is clear and gestures are ready
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    dynamic cropResult;
    try {
      cropResult = await showCupertinoImageCropper(
        context,
        imageProvider: MemoryImage(fullBytes),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Croppy FFI library loading failed: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Using full screen capture (cropping unsupported on this device)',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              ),
            ),
          ]),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        _sendToAI(fullBytes);
      }
      return;
    }

    if (cropResult == null || !mounted) {
      return;
    }

    final byteData =
        await cropResult.uiImage.toByteData(format: ui.ImageByteFormat.png);
    final croppedBytes = byteData?.buffer.asUint8List();
    if (croppedBytes == null || !mounted) {
      return;
    }

    try {
      await Pasteboard.writeImage(croppedBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied & sending to AI...'),
          ]),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {}

    if (mounted) {
      _sendToAI(croppedBytes);
    }
  }

  Future<void> _sendToAI(Uint8List imageBytes) async {
    try {
      XFile xFile;
      if (kIsWeb) {
        xFile = XFile.fromData(imageBytes,
            mimeType: 'image/png', name: 'screenshot.png');
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(imageBytes);
        xFile = XFile(file.path);
      }
      if (!mounted) {
        return;
      }
      _openAiTutorBottomSheet(
          initialImage: xFile,
          initialMessage:
              'Analyze and solve this specific section from the PDF.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Annotation Persistence
  Future<void> _loadAnnotations() async {
    final docId =
        widget.storagePath ?? widget.url ?? widget.assetPath ?? widget.title;
    final json = await IsarService().getPdfAnnotations(docId);
    if (json != null && mounted) {
      try {
        // Use dynamic to safely call if available in the runtime version
        await (_pdfViewerController as dynamic)
            .importAnnotations(json, PdfAnnotationDataFormat.json);
      } catch (e) {
        if (kDebugMode) debugPrint('Error importing annotations: $e');
      }
    }
  }

  void _saveAnnotations() {
    EasyDebounce.debounce(
      'save_pdf_annotations',
      const Duration(seconds: 1),
      () async {
        if (!mounted) return;
        final docId = widget.storagePath ??
            widget.url ??
            widget.assetPath ??
            widget.title;
        try {
          final json = (_pdfViewerController as dynamic)
              .exportAnnotations(PdfAnnotationDataFormat.json);
          await IsarService().savePdfAnnotations(docId, json);
        } catch (e) {
          if (kDebugMode) debugPrint('Error exporting annotations: $e');
        }
      },
    );
  }

  Future<void> _downloadFile() async {
    // Check premium access for PDF download/share
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (!FeatureGateService.canDownloadPdf(user) ||
        !FeatureGateService.canSharePdf(user)) {
      await PremiumFeatureDialog.show(
        context,
        featureName: 'PDF Download & Share',
        icon: Icons.download,
      );
      return;
    }

    if (_pdfBytes == null) {
      return;
    }
    try {
      if (kIsWeb) {
        final urlToLaunch = widget.url ?? widget.storagePath;
        if (urlToLaunch != null) {
          await launchUrl(Uri.parse(urlToLaunch),
              mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Source URL not available for download')));
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s\.]'), '_');
      final fileName =
          safeTitle.endsWith('.pdf') ? safeTitle : '$safeTitle.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(_pdfBytes!);
      await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'Sharing $fileName'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return _buildLoadingState(theme);
    }
    if (_isSubscriptionError) {
      return _buildSubscriptionError(theme);
    }
    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }
    if (_pdfBytes == null) {
      return const Center(child: Text('No PDF data'));
    }

    return Stack(
      children: [
        // PDF viewer
        Positioned.fill(
          child: RepaintBoundary(
            key: _pdfRepaintKey,
            child: ColorFiltered(
              colorFilter: _isNightMode
                  ? const ColorFilter.matrix(<double>[
                      // Invert + slight desaturation so blacks stay comfortable
                      -1, 0, 0, 0, 255,
                      0, -1, 0, 0, 255,
                      0, 0, -1, 0, 255,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: SfPdfViewer.memory(
                _pdfBytes!,
                controller: _pdfViewerController,
                canShowPaginationDialog: false,
                canShowScrollStatus: false,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                canShowTextSelectionMenu: false,
                interactionMode: _interactionMode,
                scrollDirection: _isContinuousScroll
                    ? PdfScrollDirection.vertical
                    : PdfScrollDirection.horizontal,
                pageLayoutMode: _isContinuousScroll
                    ? PdfPageLayoutMode.continuous
                    : PdfPageLayoutMode.single,
                onZoomLevelChanged: (details) {
                  setState(() => _zoomLevel = details.newZoomLevel);
                },
                onTextSelectionChanged: (details) {
                  if (details.selectedText == null) {
                    _dismissContextMenu();
                  } else {
                    _lastSelectedText = details.selectedText;
                    _showContextMenu(context, details);
                  }
                },
                onAnnotationAdded: (details) => _saveAnnotations(),
                onAnnotationSelected: (details) => _saveAnnotations(),
                onAnnotationDeselected: (details) => _saveAnnotations(),
                onDocumentLoaded: (details) {
                  setState(() {
                    _totalPages = details.document.pages.count;
                    _pdfDocument = details.document;
                  });
                  _loadAnnotations();
                  // Pre-resolve the download URL in the background so the
                  // first AI action opens instantly without waiting.
                  _prewarmPdfUrl();
                },
                onPageChanged: (details) {
                  setState(() {
                    _currentPage = details.newPageNumber;
                    _zoomLevel = _pdfViewerController.zoomLevel;
                  });
                  // _resetToolbarTimer();
                  // Sync thumbnail scroll
                  if (_showThumbnails && _totalPages > 0) {
                    final offset = (_currentPage - 1) * 88.0;
                    _thumbnailScrollController.animateTo(
                      offset.clamp(0.0,
                          _thumbnailScrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          ),
        ),

        // Reading progress bar (top)
        if (_totalPages > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _currentPage / _totalPages,
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),

        // Top app bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(theme, isDark),
        ),

        // Thumbnail sidebar
        if (_showThumbnails)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: _buildThumbnailSidebar(theme, isDark),
          ),

        // Search bar overlay
        if (_showSearchBar)
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _buildSearchBar(theme, isDark),
          ),

        // Bottom toolbar (now includes AI Hub)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(theme, isDark),
        ),
      ],
    );
  }

  /// Opens the chat in an embedded overlay and auto-starts Live Voice,
  /// passing the current PDF as context so the tutor is grounded in the file.
  Future<void> _openLiveVoiceWithPdf() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    _openAiTutorBottomSheet(
      initialMessage: 'Let\'s go through "${widget.title}" together via voice.',
      startVoice: true,
    );
  }

  Widget _aiHubButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = color ?? (isDark ? Colors.white : AppColors.text);

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.amber),
              )
            else
              Icon(icon, color: fg, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _summarizePdf() async {
    HapticFeedback.mediumImpact();

    // Check premium access for PDF summarizer
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (!FeatureGateService.canUsePdfSummarizer(user)) {
      await PremiumFeatureDialog.show(
        context,
        featureName: 'PDF Summarizer',
        icon: Icons.summarize,
      );
      return;
    }

    // Route summarize action through the AI Tutor overlay to avoid Vision API crashes
    await _openAiTutorBottomSheet(
      initialMessage:
          'Please provide a detailed summary of this document: "${widget.title}". Highlight the main concepts, key takeaways, and any important formulas or definitions.',
    );
  }

  Future<void> _generateFlashcards() async {
    HapticFeedback.mediumImpact();
    // Forward directly to AI Tutor to handle generation and display in chat
    await _openAiTutorBottomSheet(
      initialMessage:
          'Please generate 5 flashcards for this document: "${widget.title}".',
    );
  }

  Future<void> _generateQuiz() async {
    HapticFeedback.mediumImpact();
    // Forward directly to AI Tutor to handle generation and display in chat
    await _openAiTutorBottomSheet(
      initialMessage:
          'Please generate a 5-question quiz based on this document: "${widget.title}".',
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(ThemeData theme, bool isDark) {
    final bg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final fg = isDark ? Colors.white : AppColors.text;

    return Container(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: fg, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Thumbnail toggle
              IconButton(
                icon: Icon(
                  Icons.view_sidebar_outlined,
                  color: _showThumbnails ? theme.colorScheme.primary : fg,
                  size: 22,
                ),
                tooltip: 'Page thumbnails',
                onPressed: () =>
                    setState(() => _showThumbnails = !_showThumbnails),
              ),
              // Search
              IconButton(
                icon: Icon(
                  Icons.search_rounded,
                  color: _showSearchBar ? theme.colorScheme.primary : fg,
                  size: 22,
                ),
                tooltip: 'Search',
                onPressed: () {
                  setState(() => _showSearchBar = !_showSearchBar);
                  _keepToolbarVisible();
                },
              ),
              // Bookmark current page
              IconButton(
                icon: Icon(
                  _bookmarkedPages.contains(_currentPage)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _bookmarkedPages.contains(_currentPage)
                      ? theme.colorScheme.primary
                      : fg,
                  size: 22,
                ),
                tooltip: 'Bookmark page',
                onPressed: () => _toggleBookmark(_currentPage),
              ),
              // Night mode toggle — inverts PDF colors for comfortable reading
              IconButton(
                icon: Icon(
                  _isNightMode ? CupertinoIcons.moon_fill : CupertinoIcons.moon,
                  color: _isNightMode ? theme.colorScheme.primary : fg,
                  size: 20,
                ),
                tooltip: _isNightMode ? 'Disable night mode' : 'Night mode',
                onPressed: () => setState(() => _isNightMode = !_isNightMode),
              ),
              // More menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: fg, size: 22),
                color: bg,
                onSelected: (v) {
                  switch (v) {
                    case 'download':
                      _downloadFile();
                      break;
                    case 'save':
                      _saveToLibrary();
                      break;
                    case 'read_aloud':
                      if (_isSpeaking) {
                        _stopTts();
                      } else if (_lastSelectedText != null &&
                          _lastSelectedText!.isNotEmpty) {
                        _speakText(_lastSelectedText!);
                      } else {
                        _readCurrentPage();
                      }
                      break;
                    case 'annotate':
                      _showAnnotationToolbar();
                      break;
                    case 'bookmark':
                      _toggleBookmark(_currentPage);
                      break;
                    case 'interaction_mode':
                      setState(() {
                        _interactionMode =
                            _interactionMode == PdfInteractionMode.pan
                                ? PdfInteractionMode.selection
                                : PdfInteractionMode.pan;
                      });
                      break;
                    case 'text_size':
                      _showTextSizeDialog();
                      break;
                    case 'fit_width':
                      _pdfViewerController.zoomLevel = 1.0;
                      setState(() => _zoomLevel = 1.0);
                      break;
                    case 'scroll_mode':
                      setState(
                          () => _isContinuousScroll = !_isContinuousScroll);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'read_aloud',
                      child: _menuItem(
                          _isSpeaking
                              ? Icons.stop_circle_rounded
                              : Icons.volume_up_rounded,
                          _isSpeaking ? 'Stop Reading' : 'Read Aloud',
                          theme)),
                  PopupMenuItem(
                      value: 'annotate',
                      child: _menuItem(
                          Icons.edit_rounded,
                          _isAnnotating ? 'Annotations (on)' : 'Annotate',
                          theme)),
                  PopupMenuItem(
                      value: 'bookmark',
                      child: _menuItem(
                          _bookmarkedPages.contains(_currentPage)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          'Bookmark Page',
                          theme)),
                  PopupMenuItem(
                      value: 'interaction_mode',
                      child: _menuItem(
                        _interactionMode == PdfInteractionMode.pan
                            ? Icons.text_fields_rounded
                            : Icons.pan_tool_rounded,
                        _interactionMode == PdfInteractionMode.pan
                            ? 'Switch to Selection Mode'
                            : 'Switch to Pan mode',
                        theme,
                      )),
                  PopupMenuItem(
                      value: 'text_size',
                      child: _menuItem(
                          Icons.text_fields_rounded, 'Text Size', theme)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'scroll_mode',
                      child: _menuItem(
                        _isContinuousScroll
                            ? Icons.view_day_outlined
                            : Icons.view_carousel_outlined,
                        _isContinuousScroll
                            ? 'Switch to Page mode'
                            : 'Switch to Scroll mode',
                        theme,
                      )),
                  PopupMenuItem(
                      value: 'fit_width',
                      child: _menuItem(
                          Icons.fit_screen_rounded, 'Reset zoom', theme)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'save',
                      child: _menuItem(Icons.cloud_download_rounded,
                          'Save for Offline', theme)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'download',
                      child: _menuItem(
                          Icons.share_rounded, 'Share Document', theme)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, ThemeData theme) {
    return Row(children: [
      Icon(icon,
          size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      const SizedBox(width: 12),
      Text(label, style: GoogleFonts.inter(fontSize: 14)),
    ]);
  }

  // ---------------------------------------------------------------------------
  Widget _buildBottomBar(ThemeData theme, bool isDark) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fg = isDark ? Colors.white : AppColors.text;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: AI Actions
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _aiHubButton(
                    icon: CupertinoIcons.sparkles,
                    label: 'Ask AI',
                    onTap: () => _openAiTutorBottomSheet(),
                    color: theme.colorScheme.primary,
                  ),
                  _aiHubButton(
                    icon: CupertinoIcons.waveform,
                    label: 'Live',
                    onTap: _openLiveVoiceWithPdf,
                    color: Colors.redAccent,
                  ),
                  _aiHubButton(
                    icon: CupertinoIcons.doc_text_viewfinder,
                    label: 'Sum',
                    onTap: _summarizePdf,
                  ),
                  _aiHubButton(
                    icon: CupertinoIcons.square_stack_3d_up_fill,
                    label: 'Cards',
                    onTap: _generateFlashcards,
                  ),
                  _aiHubButton(
                    icon: CupertinoIcons.question_circle_fill,
                    label: 'Quiz',
                    onTap: _generateQuiz,
                  ),
                  _aiHubButton(
                    icon: CupertinoIcons.camera_viewfinder,
                    label: 'Snap',
                    onTap: () => _captureAndAction(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            // Row 2: Zoom and Page Nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  // Zoom out
                  IconButton(
                    icon: Icon(Icons.remove_rounded, color: fg, size: 20),
                    tooltip: 'Zoom out',
                    onPressed: () {
                      final z = (_pdfViewerController.zoomLevel - 0.25)
                          .clamp(0.5, 5.0);
                      _pdfViewerController.zoomLevel = z;
                      setState(() => _zoomLevel = z);
                    },
                  ),
                  // Zoom level chip
                  GestureDetector(
                    onTap: () {
                      _pdfViewerController.zoomLevel = 1.0;
                      setState(() => _zoomLevel = 1.0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(_zoomLevel * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // Zoom in
                  IconButton(
                    icon: Icon(Icons.add_rounded, color: fg, size: 20),
                    tooltip: 'Zoom in',
                    onPressed: () {
                      final z = (_pdfViewerController.zoomLevel + 0.25)
                          .clamp(0.5, 5.0);
                      _pdfViewerController.zoomLevel = z;
                      setState(() => _zoomLevel = z);
                    },
                  ),
                  const Spacer(),
                  // Prev page
                  Container(
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.chevron_left_rounded,
                          color:
                              _currentPage > 1 ? fg : fg.withValues(alpha: 0.3),
                          size: 24),
                      tooltip: 'Previous page',
                      onPressed: _currentPage > 1
                          ? () => _pdfViewerController.previousPage()
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Page indicator — tap to jump
                  GestureDetector(
                    onTap: _showPageJumpDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: fg.withValues(alpha: 0.1), width: 1),
                      ),
                      child: Text(
                        '$_currentPage / $_totalPages',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Next page
                  Container(
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.chevron_right_rounded,
                          color: _currentPage < _totalPages
                              ? fg
                              : fg.withValues(alpha: 0.3),
                          size: 24),
                      tooltip: 'Next page',
                      onPressed: _currentPage < _totalPages
                          ? () => _pdfViewerController.nextPage()
                          : null,
                    ),
                  ),

                  // Read aloud indicator / stop button
                  if (_isSpeaking)
                    IconButton(
                      icon: const Icon(Icons.stop_circle_rounded),
                      color: Colors.red,
                      tooltip: 'Stop reading',
                      onPressed: _stopTts,
                    ),
                  // Annotation mode indicator
                  if (_isAnnotating)
                    IconButton(
                      icon: const Icon(Icons.edit_off_rounded),
                      color: Colors.orange,
                      tooltip: 'Stop annotating',
                      onPressed: () => setState(() {
                        _annotationMode = PdfAnnotationMode.none;
                        _isAnnotating = false;
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final bg = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search in document...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
                onSubmitted: _performSearch,
              ),
            ),
            // Match count
            if (_searchMatchCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_searchCurrentMatch / $_searchMatchCount',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            // Prev / Next
            if (_searchMatchCount > 0) ...[
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                tooltip: 'Previous match',
                onPressed: _prevSearchResult,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                tooltip: 'Next match',
                onPressed: _nextSearchResult,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Close search',
              onPressed: _clearSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Thumbnail sidebar
  // ---------------------------------------------------------------------------
  Widget _buildThumbnailSidebar(ThemeData theme, bool isDark) {
    final bg = isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0);

    return Container(
      width: 80,
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Pages',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            Expanded(
              child: ListView.builder(
                controller: _thumbnailScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: _totalPages,
                itemExtent: 88,
                itemBuilder: (ctx, i) {
                  final page = i + 1;
                  final isActive = page == _currentPage;
                  final isBookmarked = _bookmarkedPages.contains(page);
                  return GestureDetector(
                    onTap: () => _pdfViewerController.jumpToPage(page),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    blurRadius: 4)
                              ]
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$page',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          if (isBookmarked)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(Icons.bookmark_rounded,
                                  size: 12, color: theme.colorScheme.primary),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / Error states
  // ---------------------------------------------------------------------------
  Widget _buildLoadingState(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(widget.title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppSpinner(),
            const SizedBox(height: 16),
            Text('Loading document...',
                style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionError(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 56, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Premium Content',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Subscribe to access this document.',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Could not load PDF',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadPdfData();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToLibrary() async {
    final downloadProvider =
        Provider.of<DownloadProvider>(context, listen: false);
    final id =
        widget.url ?? widget.storagePath ?? widget.assetPath ?? widget.title;

    if (downloadProvider.isDownloaded(id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Already saved to Knowledge Bank'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Saving to Knowledge Bank...'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));

    try {
      await downloadProvider.downloadGenericFile(
        id: id,
        title: widget.title,
        downloadUrl: widget.url ?? widget.storagePath ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved Successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
