import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../tutor_client/enhanced_websocket_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class QuickExplainOverlay extends StatefulWidget {
  final String text;
  final Offset position;
  final VoidCallback onClose;
  final Function(String) onOpenInChat;

  const QuickExplainOverlay({
    super.key,
    required this.text,
    required this.position,
    required this.onClose,
    required this.onOpenInChat,
  });

  @override
  State<QuickExplainOverlay> createState() => _QuickExplainOverlayState();
}

class _QuickExplainOverlayState extends State<QuickExplainOverlay> {
  late EnhancedWebSocketService _wsService;
  String _explanation = '';
  bool _isDone = false;
  bool _hasError = false;
  String? _errorMsg;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    if (user == null) {
      setState(() {
        _hasError = true;
        _errorMsg = "Login required";
      });
      return;
    }

    _wsService = EnhancedWebSocketService(userId: user.uid);
    // Use a transient thread ID for statelessness
    _wsService.setThreadId('quick_explain_${DateTime.now().millisecondsSinceEpoch}');

    _msgSub = _wsService.messageStream.listen((data) {
      if (!mounted) return;
      
      final type = data['type'];
      if (type == 'chunk') {
        setState(() {
          _explanation += data['content'] ?? '';
        });
      } else if (type == 'done') {
        setState(() {
          _isDone = true;
        });
      } else if (type == 'error') {
        setState(() {
          _hasError = true;
          _errorMsg = data['content'] ?? 'Something went wrong';
        });
      }
    });

    // Wait for connection (roughly) then send
    await Future.delayed(const Duration(milliseconds: 500));
    _wsService.sendMessage(
      message: widget.text,
      userId: user.uid,
      extraData: {'persist': false}, // Backend logic implemented
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const width = 340.0;
    const height = 280.0;

    // Center the overlay on screen
    final top = (size.height - height) / 2;
    final left = (size.width - width) / 2;

    return Positioned(
      top: top,
      left: left,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, 
                      size: 16, 
                      color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'AI Explanation',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _hasError 
                  ? Center(child: Text(_errorMsg ?? 'Error'))
                  : _explanation.isEmpty && !_isDone
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : Markdown(
                        data: _explanation,
                        shrinkWrap: true,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
              ),
              // Footer — Copy only
              if (_isDone || _explanation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _explanation));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
