import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import '../message_model.dart';
import '../../config/app_theme.dart';

class ChatInputArea extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode messageFocusNode;
  final String? pendingFileName;
  final String? pendingPreviewData;
  final String? pendingFileUrl;
  final bool isUploading;
  final bool isTyping;
  final bool isGenerating;
  final List<Map<String, String>> suggestions;
  final List<String> placeholderMessages;
  final VoidCallback onSendMessage;
  final Function({String? text}) onSendMessageWithText;
  final VoidCallback onShowAttachmentMenu;
  final VoidCallback onPaste;
  final VoidCallback onStopGeneration;
  final VoidCallback onClearPendingAttachment;
  final VoidCallback onShuffleQuestions;
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onLiveVoice;
  final ChatMessage? replyingToMessage;
  final VoidCallback? onCancelReply;

  const ChatInputArea({
    super.key,
    required this.textController,
    required this.messageFocusNode,
    this.pendingFileName,
    this.pendingPreviewData,
    this.pendingFileUrl,
    required this.isUploading,
    required this.isTyping,
    required this.isGenerating,
    required this.suggestions,
    required this.placeholderMessages,
    required this.onSendMessage,
    required this.onSendMessageWithText,
    required this.onShowAttachmentMenu,
    required this.onPaste,
    required this.onStopGeneration,
    required this.onClearPendingAttachment,
    required this.onShuffleQuestions,
    required this.isRecording,
    required this.onToggleRecording,
    required this.onLiveVoice,
    this.replyingToMessage,
    this.onCancelReply,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController.removeListener(_onTextChanged);
      widget.textController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  String get _effectiveHint {
    if (widget.isUploading) return 'Uploading...';

    final base = widget.placeholderMessages.isNotEmpty
        ? widget.placeholderMessages[0]
        : 'Ask anything...';

    final isDesktop =
        kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return isDesktop ? '$base (Enter to send)' : base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: kIsWeb
          ? <ShortcutActivator, VoidCallback>{}
          : {
              const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                  widget.onPaste,
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                  widget.onPaste,
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.replyingToMessage != null)
                  _buildReplyPreview(theme, isDark),

                // Main input pill
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.8 : 0.9),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: (isDark ? Colors.white : theme.primaryColor).withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor
                            .withValues(alpha: isDark ? 0.15 : 0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.pendingFileName != null) ...[
                        _buildAttachmentPreview(theme, isDark),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Attachment button (left inside pill)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.15),
                              ),
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color:
                                            Colors.white.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.attach_file_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurface,
                                shadows: isDark
                                    ? const [
                                        Shadow(
                                          color: Colors.black38,
                                          offset: Offset(0, 1),
                                          blurRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              tooltip: 'Attach file',
                              onPressed: widget.onShowAttachmentMenu,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),

                      // Text field
                      Expanded(
                        child: TextField(
                          controller: widget.textController,
                          focusNode: widget.messageFocusNode,
                          style: GoogleFonts.quicksand(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          minLines: 1,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: _effectiveHint,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.45),
                              fontSize: 16,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => widget.onSendMessageWithText(
                            text: widget.textController.text,
                          ),
                        ),
                      ),

                      // Right-side buttons inside pill
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Mic button
                            if (!widget.isGenerating &&
                                widget.textController.text.trim().isEmpty &&
                                widget.pendingFileUrl == null)
                              _buildMicButton(theme, isDark),

                            // Send button
                            _buildPillActionButton(theme, isDark),
                          ],
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
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(ThemeData theme, bool isDark) {
    final isImage = widget.pendingFileName != null &&
        (widget.pendingFileName!.toLowerCase().endsWith('.png') ||
            widget.pendingFileName!.toLowerCase().endsWith('.jpg') ||
            widget.pendingFileName!.toLowerCase().endsWith('.jpeg') ||
            widget.pendingFileName!.toLowerCase().endsWith('.gif') ||
            widget.pendingFileName!.toLowerCase().endsWith('.webp'));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          // Minimized preview (squircle-like rounded corners)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: isImage && widget.pendingPreviewData != null
                    ? Image.memory(
                        base64Decode(
                          widget.pendingPreviewData!.contains(',')
                              ? widget.pendingPreviewData!.split(',').last
                              : widget.pendingPreviewData!,
                        ),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.description_rounded,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pendingFileName ?? 'Attachment',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.isUploading ? 'Uploading…' : 'Attached',
                  style: GoogleFonts.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // Close button as small circle
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isUploading ? null : widget.onClearPendingAttachment,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: isDark ? Colors.white : Colors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isRecording
            ? Colors.red.withValues(alpha: 0.15)
            : (isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.transparent),
        border: Border.all(
          color: widget.isRecording
              ? Colors.red.withValues(alpha: 0.5)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
        ),
      ),
      child: IconButton(
        icon: Icon(
          widget.isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
          size: 22,
          color: widget.isRecording
              ? Colors.red
              : (isDark ? Colors.white : Colors.black87),
          shadows: isDark
              ? const [
                  Shadow(
                    color: Colors.black45,
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  )
                ]
              : null,
        ),
        onPressed: widget.onToggleRecording,
        tooltip: widget.isRecording ? 'Stop recording' : 'Voice input',
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildPillActionButton(ThemeData theme, bool isDark) {
    final hasContent = widget.textController.text.trim().isNotEmpty ||
        widget.pendingFileUrl != null;

    final iconColor = isDark ? Colors.white : theme.iconTheme.color;

    String? tooltip;
    IconData? icon;
    VoidCallback? onPressed;

    if (widget.isGenerating) {
      icon = Icons.stop_rounded;
      tooltip = 'Stop generation';
      onPressed = widget.onStopGeneration;
    } else if (hasContent) {
      icon = Icons.arrow_upward_rounded;
      tooltip = 'Send message';
      onPressed = widget.onSendMessage;
    } else {
      // Default state: Live Voice
      icon = Icons.graphic_eq_rounded; // Waveform-like icon
      tooltip = 'Live Voice';
      onPressed = widget.onLiveVoice;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isDark ? Colors.black.withValues(alpha: 0.2) : Colors.transparent,
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: iconColor,
          shadows: isDark
              ? const [
                  Shadow(
                    color: Colors.black45,
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  )
                ]
              : null,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildReplyPreview(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: theme.primaryColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyingToMessage!.isUser
                      ? 'Replying to you'
                      : 'Replying to TopScore AI',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyingToMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white : null),
            onPressed: widget.onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
