import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/cors_proxy_helper.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import 'interactive_desmos_graph.dart';

class GraphArtifactWidget extends StatefulWidget {
  final String graphDataJson;

  const GraphArtifactWidget({
    super.key,
    required this.graphDataJson,
  });

  @override
  State<GraphArtifactWidget> createState() => _GraphArtifactWidgetState();
}

class _GraphArtifactWidgetState extends State<GraphArtifactWidget> {
  bool _showCode = false;
  bool _isInteractive = false;
  late Map<String, dynamic> _data;
  String? _extractedEquations;

  @override
  void initState() {
    super.initState();
    _data = json.decode(widget.graphDataJson);
    _extractEquations();
  }

  void _extractEquations() {
    // Attempt to extract equations from python code or title
    final pythonCode = _data['python_code'] ?? _data['title'] ?? '';
    // Look for patterns like y = ... or y1 = ...
    final matches = RegExp(r'(y\s*=\s*[^,\n]+|y\d+\s*=\s*[^,\n]+)').allMatches(pythonCode);
    if (matches.isNotEmpty) {
      _extractedEquations = matches.map((m) => m.group(1)).join(', ');
      // Clean up (remove python syntax if any)
      _extractedEquations = _extractedEquations!
          .replaceAll('**', '^')
          .replaceAll('np.', '')
          .replaceAll('math.', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = _data['title'] ?? _data['topic'] ?? 'Generated Graph';
    final description = _data['description'] ?? _data['explanation'] ?? '';
    String? imageUrl = _data['url'] ?? _data['image_url'] ?? _data['graph_url'];
    final base64Image = _data['image_base64'] ?? _data['base64_image'] ?? _data['image_data'];
    
    // Resolve relative URLs from backend
    if (imageUrl != null && !imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
      final base = ApiConfig.baseUrl;
      imageUrl = base + (imageUrl.startsWith('/') ? '' : '/') + imageUrl;
    }

    final pythonCode = _data['python_code'] ?? _data['code'] ?? _data['title'] ?? '';

    if (_isInteractive && _extractedEquations != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme, title, isDark, true),
          const SizedBox(height: 12),
          InteractiveDesmosGraph(
            config: {
              'expression': _extractedEquations,
              'settings': {'showGrid': true}
            },
          ),
          const SizedBox(height: 8),
          _buildFooter(theme, isDark),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme, title, isDark, false),
            // Display Image (Base64 or Network)
            if (base64Image != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, base64Image, isBase64: true),
                child: Hero(
                  tag: 'graph_${_data['id']}_b64',
                  child: Image.memory(
                    base64Decode(base64Image.toString().contains(',') 
                      ? base64Image.toString().split(',').last 
                      : base64Image.toString()),
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else if (imageUrl != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, imageUrl!),
                child: Hero(
                  tag: 'graph_${_data['id']}',
                  child: CachedNetworkImage(
                    imageUrl: CorsProxyHelper.getCorsProxyUrl(imageUrl),
                    httpHeaders: CorsProxyHelper.standardHeaders,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ),
            if (_showCode)
              Container(
                padding: const EdgeInsets.all(16),
                color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.code, size: 14, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'MATPLOTLIB SOURCE',
                          style: GoogleFonts.firaCode(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      pythonCode,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            _buildActionFooter(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String title, bool isDark, bool interactive) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              interactive ? CupertinoIcons.cursor_rays : Icons.stacked_line_chart,
              size: 18,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  interactive ? 'Interactive View' : 'Visual Artifact',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (interactive)
            IconButton(
              icon: const Icon(CupertinoIcons.xmark, size: 18),
              onPressed: () => setState(() => _isInteractive = false),
              tooltip: 'Close Interactive Mode',
            ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_extractedEquations != null)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() => _isInteractive = true);
              },
              icon: const Icon(CupertinoIcons.bolt_fill, size: 16),
              label: const Text('Interactive'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade700,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () => setState(() => _showCode = !_showCode),
            icon: Icon(_showCode ? CupertinoIcons.eye_slash : Icons.code, size: 16),
            label: Text(_showCode ? 'Hide Code' : 'View Code'),
            style: TextButton.styleFrom(
              iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _copyDescription,
            icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 16),
            tooltip: 'Copy Description',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => setState(() => _isInteractive = false),
        icon: const Icon(CupertinoIcons.photo, size: 14),
        label: const Text('Switch to Static Image'),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          textStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  void _copyDescription() {
    final text = _data['description'] ?? _data['title'] ?? '';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, {bool isBase64 = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: isBase64 ? 'graph_${_data['id']}_b64' : 'graph_${_data['id']}',
                child: isBase64 
                  ? Image.memory(
                      base64Decode(imageUrl.contains(',') 
                        ? imageUrl.split(',').last 
                        : imageUrl),
                      fit: BoxFit.contain,
                    )
                  : CachedNetworkImage(
                      imageUrl: CorsProxyHelper.getCorsProxyUrl(imageUrl),
                      httpHeaders: CorsProxyHelper.standardHeaders,
                      fit: BoxFit.contain,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
