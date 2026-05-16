import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/app_spinner.dart';
import '../utils/cors_proxy_helper.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_config.dart';

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
  late Map<String, dynamic> _data;
  String? _extractedEquations;
  bool _copied = false;

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

  String _cleanText(String text) {
    if (text.isEmpty) return text;
    
    // Remove triple backticks
    var cleaned = text.replaceAll('```python', '').replaceAll('```', '');
    
    // Split into lines and filter out obvious code lines
    final lines = cleaned.split('\n');
    final filteredLines = lines.where((line) {
      final l = line.trim().toLowerCase();
      // Heuristics for Python code
      if (l.startsWith('import ') || l.startsWith('from ')) return false;
      if (l.contains('plt.') || l.contains('np.') || l.contains('sns.')) return false;
      if (l.contains('matplotlib') || l.contains('numpy')) return false;
      if (l.startsWith('def ') || l.startsWith('class ')) return false;
      if (l.contains('= np.') || l.contains('= pd.')) return false;
      if (l.contains('plt.show()') || l.contains('plt.title(')) return false;
      return true;
    });

    return filteredLines.join('\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    var title = _data['title'] ?? _data['topic'] ?? 'Generated Graph';
    var description = _data['description'] ?? _data['explanation'] ?? '';
    
    title = _cleanText(title);
    description = _cleanText(description);

    String? imageUrl = _data['url'] ?? _data['image_url'] ?? _data['graph_url'];
    var base64Image = _data['image_base64'] ?? _data['base64_image'] ?? _data['image_data'];
    
    // Check if imageUrl is actually a data URI
    if (imageUrl != null && imageUrl.startsWith('data:')) {
      base64Image = imageUrl;
      imageUrl = null;
    }

    // Resolve relative URLs from backend
    if (imageUrl != null && !imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
      final base = AppConfig.backendBaseUrl;
      imageUrl = base + (imageUrl.startsWith('/') ? '' : '/') + imageUrl;
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
            if (base64Image != null && base64Image.toString().isNotEmpty)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, base64Image.toString(), isBase64: true),
                child: Hero(
                  tag: 'graph_${_data['id']}_b64',
                  child: Image.memory(
                    base64Decode(base64Image.toString().contains(',') 
                      ? base64Image.toString().split(',').last 
                      : base64Image.toString()),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
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
                      child: AppSpinner.center(),
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

          const SizedBox(width: 4),
          IconButton(
            onPressed: _copyDescription,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _copied
                  ? const Icon(CupertinoIcons.checkmark_alt, key: ValueKey('check'), color: Colors.green, size: 16)
                  : const Icon(CupertinoIcons.doc_on_clipboard, key: ValueKey('copy'), size: 16),
            ),
            tooltip: 'Copy Description',
          ),
        ],
      ),
    );
  }


  void _copyDescription() {
    if (_copied) return;
    final text = _data['description'] ?? _data['title'] ?? '';
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
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
