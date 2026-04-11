import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:waveform_flutter/waveform_flutter.dart' as wf;
import '../message_model.dart';
import '../chat_controller.dart';

class ChatInputArea extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode messageFocusNode;
  final GlobalKey attachButtonKey;
  final bool isUploading;
  final bool isTyping;
  final bool isGenerating;
  final bool isRecording;
  final List<Map<String, String>> suggestions;
  final List<String> placeholderMessages;
  final VoidCallback onSendMessage;
  final Function({String? text}) onSendMessageWithText;
  final VoidCallback onShowAttachmentMenu;
  final VoidCallback onPaste;
  final VoidCallback onStopGeneration;
  final VoidCallback onStopListeningAndSend;
  final VoidCallback onClearPendingAttachment;
  final VoidCallback onShuffleQuestions;
  final VoidCallback onDictation;
  final VoidCallback onStartLiveVoiceMode;
  final VoidCallback onStartFeynmanMode;
  final ChatMessage? replyingToMessage;
  final VoidCallback? onCancelReply;
  final Stream<wf.Amplitude>? amplitudeStream;

  const ChatInputArea({
    super.key,
    required this.textController,
    required this.messageFocusNode,
    required this.attachButtonKey,
    required this.pendingAttachments,
    required this.isUploading,
    required this.isTyping,
    required this.isGenerating,
    required this.isRecording,
    required this.suggestions,
    required this.placeholderMessages,
    required this.onSendMessage,
    required this.onSendMessageWithText,
    required this.onShowAttachmentMenu,
    required this.onPaste,
    required this.onStopGeneration,
    required this.onStopListeningAndSend,
    required this.onClearPendingAttachment,
    required this.onShuffleQuestions,
    required this.onDictation,
    required this.onStartLiveVoiceMode,
    required this.onStartFeynmanMode,
    this.replyingToMessage,
    this.onCancelReply,
    this.amplitudeStream,
    required this.onRemoveAttachment,
  });

  final List<PendingAttachment> pendingAttachments;
  final Function(String) onRemoveAttachment;

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  bool _hasTextContent = false;

  @override
  void initState() {
    super.initState();
    _hasTextContent = widget.textController.text.trim().isNotEmpty;
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasContent = widget.textController.text.trim().isNotEmpty;
    if (_hasTextContent != hasContent) {
      setState(() {
        _hasTextContent = hasContent;
      });
    }
  }

  String get _effectiveHint {
    if (widget.isUploading) return 'Uploading...';
    final base = widget.placeholderMessages.isNotEmpty
        ? widget.placeholderMessages[0]
        : "What's on your mind?";
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pillColor = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF4F4F5);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    // Consolidated upload state: checking both the general flag and granular attachment status
    final isAnyAttachmentUploading = widget.isUploading || 
        widget.pendingAttachments.any((a) => !a.isUploaded);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            widget.onPaste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            widget.onPaste,
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(24),
              border: widget.isRecording
                  ? Border.all(color: Colors.redAccent, width: 2)
                  : Border.all(color: borderColor, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.replyingToMessage != null)
                      _ReplyPreviewWidget(
                        replyingToMessage: widget.replyingToMessage!,
                        onCancelReply: widget.onCancelReply,
                        isDark: isDark,
                      ),
                    if (widget.pendingAttachments.isNotEmpty)
                      _MultiAttachmentPreviewWidget(
                        attachments: widget.pendingAttachments,
                        onRemoveAttachment: widget.onRemoveAttachment,
                        theme: theme,
                        isDark: isDark,
                      ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 4),
                          child: Semantics(
                            label: 'Attach media or file',
                            button: true,
                            child: IconButton(
                              key: widget.attachButtonKey,
                              icon: Transform.rotate(
                                angle: -0.785,
                                child: const Icon(CupertinoIcons.paperclip, size: 22),
                              ),
                              color: theme.colorScheme.primary,
                              tooltip: 'Attach file',
                              onPressed: () {
                                widget.onShowAttachmentMenu();
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),

                        Expanded(
                          child: widget.isRecording
                              ? _LiveVoiceWaveform(
                                  amplitudeStream: widget.amplitudeStream,
                                  isDark: isDark,
                                )
                              : TextField(
                                  controller: widget.textController,
                                  focusNode: widget.messageFocusNode,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: 16,
                                    fontFamily: GoogleFonts.nunito().fontFamily,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                  cursorColor: theme.colorScheme.primary,
                                  cursorWidth: 2.0,
                                  cursorRadius: const Radius.circular(1),
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: _hasTextContent
                                      ? TextInputAction.send
                                      : TextInputAction.newline,
                                  onSubmitted: (_) {
                                    if (_hasTextContent && !widget.isGenerating && !isAnyAttachmentUploading) {
                                      widget.onSendMessage();
                                    }
                                  },
                                  minLines: 1,
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    hintText: widget.isRecording
                                        ? "Listening…"
                                        : _effectiveHint,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    hintStyle: GoogleFonts.nunito(
                                      color: theme.hintColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 6),
                            child: _DynamicRightActions(
                              hasContent: _hasTextContent || widget.pendingAttachments.isNotEmpty,
                              isGenerating: widget.isGenerating,
                              isUploading: isAnyAttachmentUploading,
                              isRecording: widget.isRecording,
                              isDark: isDark,
                              theme: theme,
                              onStopGeneration: widget.onStopGeneration,
                              onSendMessage: widget.onSendMessage,
                              onStopListeningAndSend: widget.onStopListeningAndSend,
                              onDictation: widget.onDictation,
                              onStartLiveVoiceMode: widget.onStartLiveVoiceMode,
                              onStartFeynmanMode: widget.onStartFeynmanMode,
                            ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DynamicRightActions extends StatelessWidget {
  final bool hasContent;
  final bool isGenerating;
  final bool isUploading;
  final bool isRecording;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onStopGeneration;
  final VoidCallback onSendMessage;
  final VoidCallback onStopListeningAndSend;
  final VoidCallback onDictation;
  final VoidCallback onStartLiveVoiceMode;
  final VoidCallback onStartFeynmanMode;

  const _DynamicRightActions({
    required this.hasContent,
    required this.isGenerating,
    required this.isUploading,
    required this.isRecording,
    required this.isDark,
    required this.theme,
    required this.onStopGeneration,
    required this.onSendMessage,
    required this.onStopListeningAndSend,
    required this.onDictation,
    required this.onStartLiveVoiceMode,
    required this.onStartFeynmanMode,
  });

  @override
  Widget build(BuildContext context) {
    if (isGenerating) {
      return Semantics(
        label: 'Stop generating response',
        button: true,
        child: IconButton(
          icon: const Icon(CupertinoIcons.stop_circle_fill, size: 32),
          onPressed: onStopGeneration,
          color: isDark ? Colors.white : Colors.black,
          tooltip: 'Stop generation',
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (hasContent) {
      return Semantics(
        label: 'Send message',
        button: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2, right: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUploading 
                ? theme.disabledColor.withValues(alpha: 0.1) 
                : theme.colorScheme.primary,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_upward, size: 20),
            color: isUploading 
                ? theme.disabledColor 
                : theme.colorScheme.onPrimary,
            tooltip: isUploading ? 'Waiting for uploads…' : 'Send',
            onPressed: isUploading ? null : () {
              HapticFeedback.lightImpact();
              onSendMessage();
            },
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: isRecording ? 'Stop dictation' : 'Start dictation',
          button: true,
          child: IconButton(
            icon: Icon(
              isRecording ? CupertinoIcons.stop_circle : CupertinoIcons.mic,
              size: 22,
            ),
            color: isRecording ? Colors.redAccent : theme.colorScheme.primary,
            tooltip: isRecording ? 'Stop recording' : 'Dictate',
            onPressed: () {
              HapticFeedback.lightImpact();
              isRecording ? onStopListeningAndSend() : onDictation();
            },
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        Semantics(
          label: 'Start live voice conversation',
          button: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: 2, right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                onStartLiveVoiceMode();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.waveform, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'Test me on this topic (Feynman Mode)',
          button: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: 2, right: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.shade700,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(CupertinoIcons.checkmark_seal_fill, size: 20),
              color: Colors.white,
              tooltip: 'Test Me',
              onPressed: () {
                HapticFeedback.mediumImpact();
                onStartFeynmanMode();
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

class _MultiAttachmentPreviewWidget extends StatelessWidget {
  final List<PendingAttachment> attachments;
  final Function(String) onRemoveAttachment;
  final ThemeData theme;
  final bool isDark;

  const _MultiAttachmentPreviewWidget({
    required this.attachments,
    required this.onRemoveAttachment,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: attachments
            .map((att) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _AttachmentPreviewWidget(
                    attachment: att,
                    onRemove: () => onRemoveAttachment(att.id),
                    theme: theme,
                    isDark: isDark,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _AttachmentPreviewWidget extends StatelessWidget {
  final PendingAttachment attachment;
  final VoidCallback onRemove;
  final ThemeData theme;
  final bool isDark;

  const _AttachmentPreviewWidget({
    required this.attachment,
    required this.onRemove,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final name = attachment.name;
    final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp']
        .any((ext) => name.toLowerCase().endsWith(ext));

    return Semantics(
      label: 'Selected attachment: $name',
      child: Container(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(maxWidth: 200),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: isImage && attachment.previewData != null
                        ? _AttachmentThumbnail(dataUri: attachment.previewData!)
                        : Container(
                            color: isDark ? Colors.white12 : Colors.black12,
                            child: const Icon(Icons.description_rounded, size: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        semanticsLabel: 'File name: $name',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !attachment.isUploaded ? 'Uploading…' : 'Ready to send',
                        style: TextStyle(
                          fontSize: 11,
                          color: !attachment.isUploaded
                              ? theme.colorScheme.primary
                              : Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Semantics(
                label: 'Remove attachment',
                button: true,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.white70
                          : Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreviewWidget extends StatelessWidget {
  final ChatMessage replyingToMessage;
  final VoidCallback? onCancelReply;
  final bool isDark;

  const _ReplyPreviewWidget({
    required this.replyingToMessage,
    this.onCancelReply,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Replying to message: ${replyingToMessage.text}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              width: 3,
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
                  Semantics(
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.reply,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          replyingToMessage.isUser
                              ? 'Replying to you'
                              : 'Replying to TopScore AI',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyingToMessage.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Cancel reply',
              button: true,
              child: IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
                color: isDark ? Colors.white24 : Colors.black26,
                onPressed: onCancelReply,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveVoiceWaveform extends StatelessWidget {
  final Stream<wf.Amplitude>? amplitudeStream;
  final bool isDark;

  const _LiveVoiceWaveform({
    this.amplitudeStream,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Listening, audio level changing',
      child: RepaintBoundary(
        child: Container(
          height: 48,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: StreamBuilder<wf.Amplitude>(
            stream: amplitudeStream,
            builder: (context, snapshot) {
              final amp = snapshot.data?.current ?? -60.0;
              final normalized = ((amp + 60).clamp(0, 60) / 60);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    excludeSemantics: true,
                    child: Text(
                      "Listening…",
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ...List.generate(8, (index) {
                    final heightFactor =
                        (index % 3 == 0) ? 0.8 : (index % 2 == 0 ? 0.5 : 0.3);
                    final barHeight = 4 + (normalized * 24 * heightFactor);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 3,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AttachmentThumbnail extends StatefulWidget {
  final String dataUri;
  const _AttachmentThumbnail({required this.dataUri});

  @override
  State<_AttachmentThumbnail> createState() => _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends State<_AttachmentThumbnail> {
  Future<Uint8List>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = compute(_decodeBase64Safe, widget.dataUri);
  }

  static Uint8List _decodeBase64Safe(String uri) {
    try {
      final raw = uri.contains(',') ? uri.split(',').last : uri;
      return base64Decode(raw);
    } catch (e) {
      return Uint8List(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Icon(Icons.broken_image, size: 20));
        }
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      },
    );
  }
}
