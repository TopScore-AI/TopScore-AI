import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../../providers/auth_provider.dart';
import '../../providers/ai_tutor_history_provider.dart';
import '../../providers/tutor_connection_provider.dart';
import '../chat_controller.dart';
import '../chat_screen.dart';

/// A self-contained bottom-sheet that hosts a fully functional AI Tutor chat
/// with its own isolated [ChatController] — so it never touches or corrupts
/// the global controller used by the main AI Tutor tab.
///
/// Usage:
/// ```dart
/// EmbeddedChatSheet.show(
///   context,
///   title: 'Ask AI',
///   initialMessage: 'Summarise this document...',
///   fileUrl: resolvedUrl,
///   fileName: widget.title,
///   fileType: 'pdf',
/// );
/// ```
class EmbeddedChatSheet extends StatefulWidget {
  final String title;
  final String? initialMessage;
  final String? initialInputText;
  final XFile? initialImage;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final Uint8List? fileBytes;
  final bool startVoice;

  const EmbeddedChatSheet({
    super.key,
    required this.title,
    this.initialMessage,
    this.initialInputText,
    this.initialImage,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileBytes,
    this.startVoice = false,
  });

  // ---------------------------------------------------------------------------
  // Convenience launcher
  // ---------------------------------------------------------------------------

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? initialMessage,
    String? initialInputText,
    XFile? initialImage,
    String? fileUrl,
    String? fileName,
    String? fileType,
    Uint8List? fileBytes,
    bool startVoice = false,
    double heightFactor = 0.88,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * heightFactor,
        child: EmbeddedChatSheet(
          title: title,
          initialMessage: initialMessage,
          initialInputText: initialInputText,
          initialImage: initialImage,
          fileUrl: fileUrl,
          fileName: fileName,
          fileType: fileType,
          fileBytes: fileBytes,
          startVoice: startVoice,
        ),
      ),
    );
  }

  @override
  State<EmbeddedChatSheet> createState() => _EmbeddedChatSheetState();
}

class _EmbeddedChatSheetState extends State<EmbeddedChatSheet> {
  late final ChatController _controller;
  String? _originalThreadId;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(
      initialMessage: widget.initialMessage,
      initialInputText: widget.initialInputText,
      initialImage: widget.initialImage,
      initialFileUrl: widget.fileUrl,
      initialFileName: widget.fileName,
      initialFileType: widget.fileType,
      initialFileBytes: widget.fileBytes,
      isEmbedded: true,
    );

    // Bootstrap immediately after the first frame so the Provider tree is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final tutorConn =
        Provider.of<TutorConnectionProvider>(context, listen: false);
    tutorConn.resume(); // Ensure global connection is active/resumed immediately

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final historyProvider =
        Provider.of<AiTutorHistoryProvider>(context, listen: false);

    final wsService = tutorConn.wsService;
    if (wsService == null) return;

    // Save the main tab's thread ID so we can restore it when this sheet closes
    _originalThreadId = wsService.threadId;

    // Give this overlay its own thread ID — init() will apply it to the socket
    _controller
        .setOwnThreadId('embedded_${DateTime.now().millisecondsSinceEpoch}');

    wsService.userName = authProvider.userModel?.preferredName ??
        authProvider.userModel?.displayName;

    _controller.setHistoryProvider(historyProvider);
    _controller.init(wsService);

    // Attach any file/image resources
    if (widget.initialImage != null ||
        widget.fileUrl != null ||
        widget.fileBytes != null ||
        widget.initialInputText != null) {
      _controller.handleInitialResources(
        image: widget.initialImage,
        text: widget.initialInputText,
        fileUrl: widget.fileUrl,
        fileName: widget.fileName,
        fileType: widget.fileType,
        fileBytes: widget.fileBytes,
      );
    }

    // Auto-send the initial message so the sheet opens with the AI already
    // responding — not a blank input box.
    if (widget.initialMessage != null && !widget.startVoice) {
      if (mounted) {
        _controller.sendUserMessage(context, text: widget.initialMessage);
      }
    }

    if (widget.startVoice && !_controller.isVoiceMode) {
      await _controller.preWarmAudio();
      if (mounted) _controller.startLiveVoiceMode(context);
    }
  }

  @override
  void dispose() {
    // Restore the main AI Tutor tab's thread ID on the shared WebSocket
    if (_originalThreadId != null) {
      try {
        final tutorConn =
            Provider.of<TutorConnectionProvider>(context, listen: false);
        tutorConn.wsService?.setThreadId(_originalThreadId!);
      } catch (_) {}
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider<ChatController>.value(
      value: _controller,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              _SheetHandle(title: widget.title, theme: theme),
              const Expanded(
                child: _EmbeddedChatBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header with drag handle + title + close button
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SheetHandle({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(CupertinoIcons.sparkles,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — reuses _ChatScreenView from chat_screen.dart via ChatScreen embedded
// ---------------------------------------------------------------------------

class _EmbeddedChatBody extends StatelessWidget {
  const _EmbeddedChatBody();

  @override
  Widget build(BuildContext context) {
    // ChatScreen with isEmbedded=true will read the ChatController from the
    // Provider we injected above — which is our isolated instance.
    return const ChatScreen(isEmbedded: true);
  }
}
