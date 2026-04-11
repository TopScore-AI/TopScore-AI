import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppResearchBrowser extends StatefulWidget {
  final String url;
  final String? title;

  const InAppResearchBrowser({
    super.key,
    required this.url,
    this.title,
  });

  static Future<void> show(BuildContext context, String url, {String? title}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => InAppResearchBrowser(url: url, title: title),
    );
  }

  @override
  State<InAppResearchBrowser> createState() => _InAppResearchBrowserState();
}

class _InAppResearchBrowserState extends State<InAppResearchBrowser> {
  double _progress = 0;
  InAppWebViewController? _webViewController;
  String? _currentTitle;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar
          _buildHeader(context, isDark, theme),
          
          // Progress Bar
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              color: theme.primaryColor,
              minHeight: 2,
            ),
            
          // WebView
          Expanded(
            child: ClipRRect(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  safeBrowsingEnabled: true,
                ),
                onWebViewCreated: (controller) => _webViewController = controller,
                onProgressChanged: (controller, progress) {
                  final newProgress = progress / 100.0;
                  if (newProgress.isFinite) {
                    setState(() => _progress = newProgress);
                  }
                },
                onTitleChanged: (controller, title) {
                  if (title != null && title.isNotEmpty) {
                    setState(() => _currentTitle = title);
                  }
                },
                onLoadStop: (controller, url) async {
                  final canGoBack = await controller.canGoBack();
                  setState(() => _canGoBack = canGoBack);
                },
              ),
            ),
          ),
          
          // Bottom Navigation for WebView
          if (_canGoBack) _buildBottomNavbar(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.xmark,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentTitle ?? 'Research',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.url,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Actions
          Row(
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.share, size: 20, color: theme.primaryColor),
                onPressed: () => SharePlus.instance.share(ShareParams(text: widget.url)),
              ),
              IconButton(
                icon: Icon(CupertinoIcons.compass, size: 20, color: theme.primaryColor),
                onPressed: () => launchUrl(Uri.parse(widget.url)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavbar(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_back),
            onPressed: () => _webViewController?.goBack(),
          ),
          Text(
            'Keep Reading',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: () => _webViewController?.reload(),
          ),
        ],
      ),
    );
  }
}
