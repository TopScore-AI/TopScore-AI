
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/gestures.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../constants/colors.dart';

/// A premium, memory-defensive widget to render interactive physics simulations or mock exams.
/// It implements a strict "Tap to Wake" and aggressive disposal lifecycle to satisfy KICD low-RAM requirements.
class InteractiveSimWidget extends StatefulWidget {
  final String title;
  final String url;
  final String description;
  final bool isMockExam;

  const InteractiveSimWidget({
    super.key,
    required this.title,
    required this.url,
    required this.description,
    this.isMockExam = false,
  });

  @override
  State<InteractiveSimWidget> createState() => _InteractiveSimWidgetState();
}

class _InteractiveSimWidgetState extends State<InteractiveSimWidget> {
  bool _isActivated = false;
  bool _isLoadingHtml = false;
  String? _htmlContent;
  String? _errorMessage;
  InAppWebViewController? _webViewController;

  @override
  void dispose() {
    _unloadWebView();
    super.dispose();
  }

  void _unloadWebView() {
    if (_webViewController != null) {
      // Direct headless memory release
      _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
      _webViewController = null;
    }
  }

  Future<void> _activateAndLoad() async {
    if (widget.url.isEmpty) {
      setState(() {
        _errorMessage = 'No simulation source URL provided.';
      });
      return;
    }

    setState(() {
      _isActivated = true;
      _isLoadingHtml = true;
      _errorMessage = null;
    });

    try {
      // Cache-first loading of raw HTML string from Firebase Storage
      if (_htmlContent == null) {
        final response = await http.get(Uri.parse(widget.url));
        if (response.statusCode == 200) {
          _htmlContent = response.body;
        } else {
          throw Exception('Failed to load sandbox (HTTP ${response.statusCode})');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load simulation. Please check your internet connection.';
        _isActivated = false;
      });
    } finally {
      setState(() {
        _isLoadingHtml = false;
      });
    }
  }

  void _deactivate() {
    _unloadWebView();
    setState(() {
      _isActivated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget child;
    if (!_isActivated) {
      child = _buildLazyCard(isDark, theme);
    } else if (_isLoadingHtml) {
      child = _buildShimmerLoader(isDark);
    } else if (_errorMessage != null) {
      child = _buildErrorCard(theme);
    } else {
      child = _buildActiveSandbox(isDark, theme);
    }

    return VisibilityDetector(
      key: Key('sim_${widget.url}_${widget.title}'),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction == 0.0 && _isActivated) {
          // Scrolled off-screen. Reclaim heavy webview memory immediately!
          _deactivate();
        }
      },
      child: child,
    );
  }

  Widget _buildLazyCard(bool isDark, ThemeData theme) {
    final cardColor = isDark ? const Color(0xFF131A2A) : Colors.grey[50];
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Accent Bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                      colors: widget.isMockExam
                          ? [AppColors.cardOrange, Colors.orangeAccent]
                          : [AppColors.accentTeal, Colors.cyanAccent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Section with subtle modern background circles
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (widget.isMockExam ? Colors.orange : Colors.teal)
                          .withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Icon(
                        widget.isMockExam
                            ? CupertinoIcons.doc_text_fill
                            : CupertinoIcons.lab_flask_solid,
                        color: widget.isMockExam
                            ? AppColors.cardOrange
                            : AppColors.accentTeal,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.description,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Memory safety notice
                        Row(
                          children: [
                            Icon(
                              Icons.memory,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to wake Sandbox • Offline Ready',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Call to Action
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: ElevatedButton(
                onPressed: _activateAndLoad,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: widget.isMockExam
                      ? AppColors.cardOrange
                      : AppColors.accentTeal,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: (widget.isMockExam
                          ? AppColors.cardOrange
                          : AppColors.accentTeal)
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isMockExam ? CupertinoIcons.play_circle : CupertinoIcons.bolt_fill,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isMockExam ? 'Start Mock Exam' : 'Launch Sandbox',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader(bool isDark) {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A2A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300]!,
        highlightColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 20, width: 140, color: Colors.white),
              const SizedBox(height: 12),
              Container(height: 14, width: double.infinity, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 14, width: 220, color: Colors.white),
              const Spacer(),
              Container(height: 48, width: double.infinity, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill,
              color: Colors.redAccent, size: 28),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'An error occurred.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _activateAndLoad,
            child: const Text('Try Again',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSandbox(bool isDark, ThemeData theme) {
    final barBg = isDark ? const Color(0xFF131A2A) : Colors.grey[100]!;
    final barBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!;

    return Container(
      height: 480,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: barBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Inline Close / Disposal Control Bar
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(bottom: BorderSide(color: barBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.isMockExam
                            ? CupertinoIcons.doc_text_fill
                            : CupertinoIcons.lab_flask,
                        size: 16,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _deactivate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.power,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Unload Sim',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The Sandbox Canvas Frame
            Expanded(
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: _htmlContent!,
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  supportZoom: false,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                  disableVerticalScroll: widget.isMockExam ? false : true,
                  disableHorizontalScroll: true,
                ),
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(),
                  ),
                  Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer(),
                  ),
                },
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
