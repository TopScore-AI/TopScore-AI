import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'gpt_markdown_wrapper.dart';
import '../providers/auth_provider.dart';
import '../tutor_client/enhanced_websocket_service.dart';

class QuickExplainOverlay extends StatefulWidget {
  final String text;
  final Offset position;
  final VoidCallback onClose;
  final Function(String) onOpenInChat;
  final EnhancedWebSocketService? externalWsService;

  const QuickExplainOverlay({
    super.key,
    required this.text,
    required this.position,
    required this.onClose,
    required this.onOpenInChat,
    this.externalWsService,
  });

  @override
  State<QuickExplainOverlay> createState() => _QuickExplainOverlayState();
}

class _QuickExplainOverlayState extends State<QuickExplainOverlay> {
  late EnhancedWebSocketService _wsService;
  bool _isExternalWs = false;
  String _explanation = '';
  bool _isDone = false;
  bool _copied = false;
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

    if (widget.externalWsService != null) {
      _wsService = widget.externalWsService!;
      _isExternalWs = true;
    } else {
      _wsService = EnhancedWebSocketService(userId: user.uid);
      // Use a transient thread ID for statelessness
      _wsService
          .setThreadId('quick_explain_${DateTime.now().millisecondsSinceEpoch}');
      await _wsService.initialize();
      await _wsService.connect();
    }

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

    // Wait until the socket reports connected (or fall back after 5s and let
    // sendMessage queue it offline).
    if (!_wsService.isConnected) {
      try {
        await _wsService.isConnectedStream
            .firstWhere((c) => c)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Fall through — sendMessage will queue offline if still disconnected.
      }
    }
    _wsService.sendMessage(
      message: widget.text,
      userId: user.uid,
      extraData: {'persist': false}, // Backend logic implemented
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    if (!_isExternalWs) {
      _wsService.dispose();
    }
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
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'AI Explanation',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface, // Full visibility
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
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : SingleChildScrollView(
                            child: StyledGptMarkdown(
                              _explanation,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
              ),
              // Footer — Copy & Open in Chat
              if (_isDone || _explanation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _explanation));
                          HapticFeedback.mediumImpact();
                          setState(() => _copied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copied = false);
                          });
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            key: ValueKey(_copied),
                            size: 16,
                            color: _copied ? Colors.teal : null,
                          ),
                        ),
                        label: Text(
                          _copied ? 'Copied' : 'Copy',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: _copied
                              ? Colors.teal
                              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onOpenInChat(_explanation);
                        },
                        icon: const Icon(Icons.forum_outlined, size: 14),
                        label: Text(
                          'Open in Chat',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          foregroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
