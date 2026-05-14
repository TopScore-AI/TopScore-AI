import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_config.dart';
import 'chat_media_viewers.dart';
import '../../widgets/gpt_markdown_wrapper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../services/clipboard_service.dart';
import '../../services/haptics_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/gemini_reasoning_view.dart';
import '../../widgets/math_markdown.dart';
import '../../widgets/youtube_embed_widget.dart';
import '../../widgets/quiz_widget.dart';
import '../../widgets/flashcard_artifact_widget.dart';
import '../../widgets/math_stepper_widget.dart';
import '../../widgets/shared/video_carousel.dart';
import '../message_model.dart';
import '../../models/user_model.dart';
import 'mnemonic_card.dart';
import 'punnett_square_widget.dart';
import '../../widgets/in_app_research_browser.dart';
import '../../utils/cors_proxy_helper.dart';
import 'ui_widget_factory.dart';


class ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isStreaming;
  final String? playingAudioMessageId;
  final bool isPlayingAudio;
  final Duration audioDuration;
  final Duration audioPosition;
  final String? speakingMessageId;
  final bool isTtsSpeaking;
  final bool isTtsPaused;
  final String? status;
  final UserModel? user;

  // Callbacks
  final VoidCallback onPlayVoice;
  final VoidCallback onPauseVoice;
  final VoidCallback onResumeVoice;
  final Function(String) onSpeak;
  final VoidCallback onStopTts;
  final VoidCallback onPauseTts;
  final VoidCallback onResumeTts;
  final VoidCallback onCopy;
  final VoidCallback onToggleBookmark;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;
  final Function(int) onFeedback;
  final VoidCallback onEdit;
  final Function(String) onDownloadImageUrl;
  final Function(ChatMessage) onReply;
  final VoidCallback onLongPress;
  final VoidCallback? onRetrySend;
  // Only the most recent user message in a thread should be editable.
  // Older user messages show a copy action only.
  final bool isEditable;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.playingAudioMessageId,
    this.isPlayingAudio = false,
    this.audioDuration = Duration.zero,
    this.audioPosition = Duration.zero,
    this.speakingMessageId,
    this.isTtsSpeaking = false,
    this.isTtsPaused = false,
    required this.onPlayVoice,
    required this.onPauseVoice,
    required this.onResumeVoice,
    required this.onSpeak,
    required this.onStopTts,
    required this.onPauseTts,
    required this.onResumeTts,
    required this.onCopy,
    required this.onToggleBookmark,
    required this.onShare,
    required this.onRegenerate,
    required this.onFeedback,
    required this.onEdit,
    required this.onDownloadImageUrl,
    required this.onReply,
    required this.onLongPress,
    this.status,
    this.user,
    this.onRetrySend,
    this.isEditable = true,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool isPlaybackError = false;
  final GlobalKey<SelectableRegionState> _selectableKey = GlobalKey();


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key('msg_${widget.message.id}'),
      // Disable horizontal swipe for AI messages to allow text selection
      direction: widget.message.isUser
          ? DismissDirection.horizontal
          : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left to reply
          widget.onReply(widget.message);
          return false; // Don't actually dismiss
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(CupertinoIcons.reply,
            color: theme.iconTheme.color?.withValues(alpha: 0.5)),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(CupertinoIcons.reply,
            color: theme.iconTheme.color?.withValues(alpha: 0.5)),
      ),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return widget.message.isUser
              ? _buildUserBubble(context, theme, isDark, settings)
              : _buildAiBubble(context, theme, isDark, settings);
        },
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    final hasLegacyAttachment = widget.message.fileId != null ||
        widget.message.imageUrl != null ||
        extractAttachedDocumentUrl(widget.message.text) != null;
    final hasNewAttachments = widget.message.attachments != null &&
        widget.message.attachments!.isNotEmpty;
    final hasAttachment = hasLegacyAttachment || hasNewAttachments;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.of(context).size.width * 0.78).clamp(0, 650),
        ),
        margin: const EdgeInsets.only(top: 6, bottom: 6, left: 12, right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (hasAttachment)
              _buildAttachmentsCollection(context, theme, isDark),
            const SizedBox(height: 4),
            if (_cleanContent(widget.message.text).trim().isNotEmpty ||
                (widget.message.audioUrl != null &&
                    widget.message.text == '🎤 Audio Message'))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            theme.colorScheme.primary.withValues(alpha: 0.35),
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                          ]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.7),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    final cleanedText =
                        _cleanContent(widget.message.text).trim();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.message.replyToText != null)
                          _buildReplyPreview(theme, true),
                        if (widget.message.audioUrl != null &&
                            widget.message.text == '🎤 Audio Message')
                          _buildVoicePlayer(context, theme),
                        if (!(widget.message.audioUrl != null &&
                                widget.message.text == '🎤 Audio Message') &&
                            cleanedText.isNotEmpty)
                          _buildMarkdown(context, theme, isDark, settings),
                        // Note: UI widgets are rendered inline by _buildMarkdown via
                        // the :::ui-widget|id::: placeholder, and unmatched widgets
                        // fall through to _buildWidgetFallbackArea. Rendering them
                        // here again would duplicate every widget.
                      ],
                    );
                  },
                ),
              ),
            if (widget.message.status == MessageStatus.error)
              _buildDeliveryErrorRow(theme),
            _buildUserActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryErrorRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle_fill,
              size: 14, color: Colors.redAccent.shade200),
          const SizedBox(width: 4),
          Text(
            'Not delivered',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.redAccent.shade200,
            ),
          ),
          const SizedBox(width: 6),
          if (widget.onRetrySend != null)
            GestureDetector(
              onTap: widget.onRetrySend,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.arrow_clockwise,
                      size: 13, color: theme.colorScheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    'Retry',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCollection(
      BuildContext context, ThemeData theme, bool isDark) {
    // If we have new structured attachments, use them
    if (widget.message.attachments != null &&
        widget.message.attachments!.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: widget.message.attachments!
            .map((att) => _buildAttachmentChip(
                  context,
                  theme,
                  isDark,
                  url: att.url ?? '',
                  type: att.type ?? 'image',
                  id: att.id ?? 'FILE',
                  name: att.name ?? 'Document',
                ))
            .toList(),
      );
    }

    // Fallback to legacy single attachment
    final fileUrl = widget.message.imageUrl ??
        extractAttachedDocumentUrl(widget.message.text) ??
        '';
    final fileType = widget.message.fileType ??
        (fileUrl.isNotEmpty
            ? (_isImageUrl(fileUrl) ? 'image' : 'pdf')
            : 'document');
    final fileId = widget.message.fileId ?? (fileUrl.isNotEmpty ? 'FILE' : '');
    final fileName = widget.message.fileName ?? 'Document';

    return _buildAttachmentChip(context, theme, isDark,
        url: fileUrl, type: fileType, id: fileId, name: fileName);
  }

  Widget _buildAttachmentChip(
      BuildContext context, ThemeData theme, bool isDark,
      {required String url,
      required String type,
      required String id,
      required String name}) {
    final isRawImage = widget.message.imageUrl != null &&
        (_isImageUrl(widget.message.imageUrl!) ||
            widget.message.imageUrl!.contains('FirebaseStorage'));
    final isImage = type.contains('image') || isRawImage;

    return GestureDetector(
      onTap: () => _handleAttachmentTap(context, url, type, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark 
            ? Colors.white.withValues(alpha: 0.05) 
            : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImage && url.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Hero(
                  tag: 'attachment_$url',
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Icon(CupertinoIcons.photo, size: 16)),
                    errorWidget: (context, url, error) =>
                        const Icon(CupertinoIcons.photo, size: 16),
                  ),
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  type == 'pdf' ? CupertinoIcons.doc_fill : CupertinoIcons.doc,
                  size: 18,
                  color: theme.primaryColor,
                ),
              ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isImage ? 'image:$id' : 'document:$id',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isImage)
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: isDark
                  ? Colors.white38
                  : AppColors.text.withValues(alpha: 0.26),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAttachmentTap(
      BuildContext context, String url, String type, String name) {
    if (url.isEmpty) return;

    if (type == 'image') {
      Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => FullScreenImageViewer(
                imageUrl: url,
                heroTag: 'attachment_$url',
              )));
    } else if (type == 'pdf') {
      Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => PdfViewerScreen(url: url, title: name)));
    } else if (type == 'docx' || type == 'doc') {
      _showConversionAndViewer(context, url, name);
    } else {
      InAppResearchBrowser.show(context, url, title: name);
    }
  }

  Future<void> _showConversionAndViewer(
      BuildContext context, String url, String name) async {
    showCupertinoDialog(
      context: context,
      builder: (context) => const CupertinoActivityIndicator(radius: 20),
    );

    try {
      final convertedUrl = await _convertToPdf(url, context);
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      if (convertedUrl != null) {
        Navigator.of(context).push(CupertinoPageRoute(
            builder: (_) => PdfViewerScreen(url: convertedUrl, title: name)));
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
    }
  }

  Future<String?> _convertToPdf(
      String originalUrl, BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (!context.mounted) return null;
    final userId = authProvider.userModel?.uid ?? 'guest';

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/documents/convert-from-url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'file_url': originalUrl,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['pdf_url'];
    }
    return null;
  }

  Widget _buildAiBubble(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 850),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: 8.0, bottom: 24.0, left: 12.0, right: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surface
                                      .withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.75),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.85),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: widget.message.status == MessageStatus.error
                                ? _buildAiErrorCard(theme, isDark)
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if ((widget.isStreaming ||
                                              widget.message.isThinking) &&
                                          widget.message.text.isEmpty &&
                                          (widget.message.reasoning == null ||
                                              widget.message.reasoning!.isEmpty))
                                        _ThinkingSkeleton(
                                            isDark: isDark,
                                            status: widget.status ??
                                                (widget.message.isThinking
                                                    ? "Thinking..."
                                                    : null)),
                                      if (widget.message.reasoning != null &&
                                          widget.message.reasoning!.isNotEmpty)
                                        TopScoreReasoningView(
                                          content: widget.message.reasoning!,
                                          isThinking: widget.message.text.isEmpty,
                                        ),
                                      if (widget.message.replyToText != null)
                                        _buildReplyPreview(theme, false),
                                      if (widget.message.text.isNotEmpty)
                                        _buildMarkdown(
                                            context, theme, isDark, settings),
                                      if (widget.isStreaming &&
                                          widget.message.text.isNotEmpty)
                                        const _StreamingCursor(),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.message.quizDataJson != null)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: QuizWidget(
                      quizData: _parseQuizData(widget.message.quizDataJson!),
                      onComplete: (score) {
                        final auth = context.read<AuthProvider>();
                        if (score > 0) {
                          auth.awardXp(score * 10, 'AI Quiz Result');
                        }
                      },
                    ),
                  ),
                  _buildArtifactActions(
                    context,
                    theme,
                    'quiz',
                    _parseQuizData(widget.message.quizDataJson!),
                  ),
                ],
              ),
            if (widget.message.flashcardDataJson != null)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FlashcardArtifactWidget(
                      flashcardData: _parseFlashcardData(
                          widget.message.flashcardDataJson!),
                    ),
                  ),
                  _buildArtifactActions(
                    context,
                    theme,
                    'flashcards',
                    _parseFlashcardData(widget.message.flashcardDataJson!),
                  ),
                ],
              ),
            if (widget.message.mnemonicDataJson != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: MnemonicCard(
                  mnemonicDataJson: widget.message.mnemonicDataJson!,
                ),
              ),
            if (widget.message.mathSteps != null &&
                widget.message.mathSteps!.isNotEmpty)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MathStepperWidget(
                      steps: widget.message.mathSteps!,
                      finalAnswer: widget.message.mathAnswer,
                    ),
                  ),
                  _buildArtifactActions(
                    context,
                    theme,
                    'math_steps',
                    {
                      'steps': widget.message.mathSteps,
                      'answer': widget.message.mathAnswer
                    },
                  ),
                ],
              ),
            if (widget.message.videos != null &&
                widget.message.videos!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: VideoCarousel(videos: widget.message.videos!),
              ),
            if (widget.message.punnettDataJson != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PunnettSquareWidget(
                  dataJson: widget.message.punnettDataJson!,
                ),
              ),
            // Note: UI widgets are rendered inline by _buildMarkdown via
            // the :::ui-widget|id::: placeholder, and unmatched widgets
            // fall through to _buildWidgetFallbackArea. Rendering them
            // here again would duplicate every widget.
            if (widget.message.sources != null &&
                widget.message.sources!.isNotEmpty)
              _buildSources(theme, isDark),

            if (!widget.message.isUser &&
                widget.message.isComplete &&
                !widget.isStreaming)
              _buildAiActions(theme),
          ],
        ),
      ),
    );
  }

  // _buildKicdBadge removed as it is no longer referenced in the borderless AI response design

  Widget _buildVoicePlayer(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              widget.playingAudioMessageId == widget.message.id &&
                      widget.isPlayingAudio
                  ? CupertinoIcons.pause_circle_fill
                  : CupertinoIcons.play_circle_fill,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () {
              if (widget.playingAudioMessageId == widget.message.id &&
                  widget.isPlayingAudio) {
                widget.onPauseVoice();
              } else if (widget.playingAudioMessageId == widget.message.id &&
                  !widget.isPlayingAudio) {
                widget.onResumeVoice();
              } else {
                widget.onPlayVoice();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor:
                        widget.playingAudioMessageId == widget.message.id
                            ? (widget.audioDuration.inMilliseconds > 0
                                ? widget.audioPosition.inMilliseconds /
                                    widget.audioDuration.inMilliseconds
                                : 0.0)
                            : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.playingAudioMessageId == widget.message.id
                      ? '${_formatDuration(widget.audioPosition)} / ${_formatDuration(widget.audioDuration)}'
                      : 'Voice message',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isEditable)
            _TactileActionIcon(
              icon: CupertinoIcons.pencil,
              onTap: widget.onEdit,
              theme: theme,
              tooltip: 'Edit',
              isSmall: true,
            ),
          _TactileActionIcon(
            icon: CupertinoIcons.doc_on_clipboard,
            onTap: widget.onCopy,
            theme: theme,
            tooltip: 'Copy',
            isCopy: true,
            isSmall: true,
          ),
        ],
      ),
    );
  }



  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: imageUrl,
          heroTag: 'msg_img_$imageUrl',
        ),
      ),
    );
  }

  Widget _buildYouTubeOrTextLink(
      BuildContext context, String text, String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (url.startsWith('speak:')) {
      final parts = url.split(':');
      final textToSpeak = parts.length > 1 ? parts[1] : text;
      final langCode = parts.length > 2 ? parts[2] : 'en';
      return _buildInlineSpeakButton(context, text, textToSpeak, langCode);
    }

    if (url.toLowerCase().contains('youtube.com') ||
        url.toLowerCase().contains('youtu.be')) {
      final videoId = YoutubePlayerController.convertUrlToId(url);
      if (videoId != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => InAppResearchBrowser.show(context, url, title: text),
              child: Text(
                text.isEmpty ? url : text,
                style: GoogleFonts.nunito(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SingleYouTubeCard(
              videoId: videoId,
              url: url,
              title: text.isNotEmpty ? text : null,
              isDark: isDark,
            ),
          ],
        );
      }
    }

    return GestureDetector(
      onTap: () {
        if (url.toLowerCase().contains('.pdf') ||
            url.toLowerCase().contains('.docx') ||
            url.toLowerCase().contains('.doc')) {
          final type = url.toLowerCase().contains('.pdf') ? 'pdf' : 'docx';
          _handleAttachmentTap(context, url, type, text);
        } else if (url.startsWith('/')) {
          // Internal App Navigation
          context.push(url);
        } else {
          // External/Web Research
          InAppResearchBrowser.show(context, url, title: text);
        }
      },
      child: Text(
        text,
        style: GoogleFonts.nunito(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildInlineSpeakButton(
      BuildContext context, String text, String textToSpeak, String langCode) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final decodedText = Uri.decodeComponent(textToSpeak);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            HapticsService.instance.lightImpact();
            final tts = TtsService();
            String bcp47 = 'en-US';
            switch (langCode.toLowerCase().trim()) {
              case 'fr':
              case 'french':
                bcp47 = 'fr-FR';
                break;
              case 'de':
              case 'german':
                bcp47 = 'de-DE';
                break;
              case 'es':
              case 'spanish':
                bcp47 = 'es-ES';
                break;
              case 'zh':
              case 'chinese':
              case 'mandarin':
                bcp47 = 'zh-CN';
                break;
              case 'sw':
              case 'swahili':
              case 'kiswahili':
                bcp47 = 'sw-KE';
                break;
              case 'ar':
              case 'arabic':
                bcp47 = 'ar-AE';
                break;
              case 'it':
              case 'italian':
                bcp47 = 'it-IT';
                break;
              default:
                bcp47 = langCode;
            }
            await tts.setLanguage(bcp47);
            await tts.speak(decodedText);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    final baseStyle = GoogleFonts.nunito(
      fontSize: settings.fontSize + 2,
      fontWeight: FontWeight.w500,
      height: widget.message.isUser ? settings.lineHeight : 1.6,
      color: widget.message.isUser
          ? Colors.white
          : theme.colorScheme.onSurface.withValues(alpha: 0.9),
    );

    final content = _cleanContent(widget.message.text);
    final widgetRegex = RegExp(r':::ui-widget\|([a-f0-9-]+):::');

    final List<UiWidgetData> allWidgets = [];

    // 1. Add any widgets already present in widget.message.uiWidgets
    if (widget.message.uiWidgets != null) {
      allWidgets.addAll(widget.message.uiWidgets!);
    }

    // 2. Add and parse any widgets from widget.message.uiWidgetsJson
    if (widget.message.uiWidgetsJson != null) {
      for (final jsonStr in widget.message.uiWidgetsJson!) {
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            allWidgets.add(UiWidgetData.fromJson(decoded));
          }
        } catch (e) {
          developer.log('Error parsing uiWidgetsJson item: $e', name: 'ChatMessageBubble');
        }
      }
    }

    // 3. Extract any legacy :::ui-widget\n{...}\n::: blocks directly from the text of the message
    final rawText = widget.message.text;
    final legacyRegex = RegExp(r':::ui-widget[\r\n]+(.*?)([\r\n]+:::|$)', dotAll: true);
    final legacyMatches = legacyRegex.allMatches(rawText);
    for (final match in legacyMatches) {
      final jsonStr = match.group(1);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonStr.trim());
          if (decoded is Map<String, dynamic>) {
            allWidgets.add(UiWidgetData.fromJson(decoded));
          }
        } catch (e) {
          developer.log('Error parsing legacy ui-widget block: $e', name: 'ChatMessageBubble');
        }
      }
    }

    // 4. Ensure every widget has a unique, non-null ID
    for (int i = 0; i < allWidgets.length; i++) {
      final w = allWidgets[i];
      if (w.id == null || w.id!.isEmpty) {
        allWidgets[i] = UiWidgetData(
          id: 'synth_widget_${widget.message.id}_$i',
          type: w.type,
          title: w.title,
          configJson: w.configJson,
        );
      }
    }

    final Set<String> renderedWidgetIds = {};

    if (!content.contains(widgetRegex)) {
      return SelectionArea(
        key: _selectableKey,
        contextMenuBuilder: _buildContextMenu,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StyledGptMarkdown(
              content,
              style: baseStyle,
              imageBuilder: (context, url) =>
                  _buildGptImage(context, url, isDark),
              linkBuilder: (context, span, url, style) =>
                  _buildYouTubeOrTextLink(context, span.toPlainText(), url),
              codeBuilder: (context, name, code, closed) => _CodeBlockWidget(
                code: code,
                language: name,
                isDark: isDark,
              ),
            ),
            // Fallback: Render all widgets at bottom if No placeholders found
            if (allWidgets.isNotEmpty)
              _buildWidgetFallbackArea(context, allWidgets, renderedWidgetIds),
          ],
        ),
      );
    }

    // New Side-Channel Architecture: Split and render inline
    final List<String> segments = content.split(widgetRegex);
    final List<RegExpMatch> matches = widgetRegex.allMatches(content).toList();

    return SelectionArea(
      key: _selectableKey,
      contextMenuBuilder: _buildContextMenu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            if (segments[i].trim().isNotEmpty)
              StyledGptMarkdown(
                segments[i],
                style: baseStyle,
                imageBuilder: (context, url) =>
                    _buildGptImage(context, url, isDark),
                linkBuilder: (context, span, url, style) =>
                    _buildYouTubeOrTextLink(context, span.toPlainText(), url),
                codeBuilder: (context, name, code, closed) => _CodeBlockWidget(
                  code: code,
                  language: name,
                  isDark: isDark,
                ),
              ),
            if (i < matches.length) ...[
              _buildSideChannelWidget(context, matches[i].group(1)!, allWidgets),
              () {
                renderedWidgetIds.add(matches[i].group(1)!);
                return const SizedBox.shrink();
              }(),
            ],
          ],
          // Fallback: Render any widgets that weren't captured inline
          _buildWidgetFallbackArea(context, allWidgets, renderedWidgetIds),
        ],
      ),
    );
  }

  Widget _buildWidgetFallbackArea(BuildContext context,
      List<UiWidgetData> allWidgets, Set<String> renderedIds) {
    final remaining = allWidgets
        .where((w) => w.id != null && !renderedIds.contains(w.id))
        .toList();
    if (remaining.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: remaining
            .map((w) => _buildSideChannelWidget(context, w.id!, allWidgets))
            .toList(),
      ),
    );
  }

  Widget _buildSideChannelWidget(BuildContext context, String widgetId, List<UiWidgetData> allWidgets) {
    // Look up the actual widget data by its unique ID
    dynamic matchingWidget;
    try {
      matchingWidget = allWidgets.isEmpty
          ? null
          : allWidgets.firstWhere((w) => w.id == widgetId);
    } catch (e) {
      matchingWidget = null;
    }

    if (matchingWidget == null) {
      // If the text arrives before the side-channel data, show a shimmering placeholder
      return _ThinkingSkeleton(
        isDark: Theme.of(context).brightness == Brightness.dark,
      );
    }

    // Success: Dispatch to the factory for specialized rendering (Table, Image, etc.)
    return UiWidgetFactory(jsonConfig: jsonEncode(matchingWidget.toJson()));
  }

  Widget _buildContextMenu(
      BuildContext context, SelectableRegionState selectableRegionState) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: [
        ...selectableRegionState.contextMenuButtonItems,
        ContextMenuButtonItem(
          label: 'Select All',
          onPressed: () {
            selectableRegionState.selectAll();
          },
        ),
      ],
    );
  }

  Widget _buildGptImage(BuildContext context, String url, bool isDark) {
    // Reject obviously malformed URLs before we prepend backendBaseUrl and issue
    // a doomed network request. gpt_markdown occasionally mis-parses embedded
    // tool output like `[IMAGE_FOUND] ![alt](actual_url)` and hands the whole
    // blob in as the "url" — which used to produce 404s against the backend.
    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed.contains(' ') ||
        trimmed.contains('\n') ||
        trimmed.contains('[') ||
        trimmed.contains(']') ||
        trimmed.contains('!')) {
      return const SizedBox.shrink();
    }

    var imageUrl = trimmed;
    // Resolve relative URLs from backend
    if (!imageUrl.startsWith('http') && !imageUrl.startsWith('data:')) {
      final base = AppConfig.backendBaseUrl;
      imageUrl = base + (imageUrl.startsWith('/') ? '' : '/') + imageUrl;
    }

    final sanitizedUrl = CorsProxyHelper.getCorsProxyUrl(imageUrl);

    return GestureDetector(
      onTap: () => _showFullScreenImage(context, sanitizedUrl),
      child: Hero(
        tag: 'msg_img_$sanitizedUrl',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: sanitizedUrl,
            httpHeaders: CorsProxyHelper.standardHeaders,
            fit: BoxFit.contain,
            placeholder: (pContext, pUrl) => Shimmer.fromColors(
              baseColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey[300]!,
              highlightColor: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey[100]!,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            errorWidget: (eContext, eUrl, error) => Container(
              height: 150,
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiActions(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (widget.speakingMessageId == widget.message.id &&
              widget.isTtsSpeaking)
            ..._buildTtsControls(theme)
          else
            _TactileActionIcon(
              icon: CupertinoIcons.speaker_2,
              onTap: () => widget.onSpeak(widget.message.text),
              theme: theme,
              tooltip: 'Read aloud',
            ),
          _TactileActionIcon(
            icon: CupertinoIcons.doc_on_doc,
            onTap: widget.onCopy,
            theme: theme,
            tooltip: 'Copy',
            isCopy: true,
          ),
          _TactileActionIcon(
            icon: CupertinoIcons.arrow_clockwise,
            onTap: widget.onRegenerate,
            theme: theme,
            tooltip: 'Regenerate',
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.2),
          ),
          _TactileActionIcon(
            icon: CupertinoIcons.hand_thumbsup,
            onTap: () => widget.onFeedback(1),
            theme: theme,
            isActive: widget.message.feedback == 1,
            color: widget.message.feedback == 1 ? AppColors.accentTeal : null,
          ),
          _TactileActionIcon(
            icon: CupertinoIcons.hand_thumbsdown,
            onTap: () => widget.onFeedback(-1),
            theme: theme,
            isActive: widget.message.feedback == -1,
            color: widget.message.feedback == -1 ? Colors.redAccent : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTtsControls(ThemeData theme) {
    return [
      if (widget.isTtsPaused)
        _TactileActionIcon(
          icon: CupertinoIcons.play_fill,
          onTap: widget.onResumeTts,
          theme: theme,
          isActive: true,
          color: AppColors.googleBlue,
        )
      else
        _TactileActionIcon(
          icon: CupertinoIcons.pause_fill,
          onTap: widget.onPauseTts,
          theme: theme,
          isActive: true,
          color: AppColors.googleBlue,
        ),
      _TactileActionIcon(
        icon: CupertinoIcons.stop_fill,
        onTap: widget.onStopTts,
        theme: theme,
        isActive: true,
        color: Colors.redAccent,
      ),
    ];
  }


  Widget _buildArtifactActions(
    BuildContext context,
    ThemeData theme,
    String type,
    Map<String, dynamic> data,
  ) {
    if (widget.isStreaming) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _TactileArtifactActionIcon(
            icon: CupertinoIcons.doc_on_clipboard,
            onTap: () => _copyArtifactToClipboard(context, type, data),
            theme: theme,
            label: 'Copy text',
            isCopy: true,
          ),
          const SizedBox(width: 8),
          _TactileArtifactActionIcon(
            icon: CupertinoIcons.share,
            onTap: () => _shareArtifact(context, type, data),
            theme: theme,
            label: 'Share',
          ),
        ],
      ),
    );
  }


  void _copyArtifactToClipboard(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
  ) {
    final text = _formatArtifactAsText(type, data);
    ClipboardService.instance.copyText(text);
    HapticsService.instance.lightImpact();
  }

  void _shareArtifact(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
  ) {
    final text = _formatArtifactAsText(type, data);
    SharePlus.instance.share(ShareParams(text: text));
    HapticsService.instance.lightImpact();
  }

  String _formatArtifactAsText(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'quiz':
        final title = data['title'] ?? 'Quiz';
        final questions = (data['questions'] as List?) ?? [];
        var buffer = '📝 $title\n\n';
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i];
          buffer += '${i + 1}. ${q['question']}\n';
          final options = (q['options'] as List?) ?? [];
          for (var j = 0; j < options.length; j++) {
            buffer += '   ${String.fromCharCode(65 + j)}) ${options[j]}\n';
          }
          buffer += '   (Answer: ${q['correct_answer']})\n\n';
        }
        return buffer.trim();

      case 'flashcards':
        final topic = data['topic'] ?? 'Flashcards';
        final cards = (data['cards'] as List?) ?? [];
        var buffer = '🗂️ Flashcards: $topic\n\n';
        for (var i = 0; i < cards.length; i++) {
          final c = cards[i];
          buffer += 'Card ${i + 1}:\n';
          buffer += 'Front: ${c['front']}\n';
          buffer += 'Back: ${c['back']}\n';
          if (c['explanation'] != null) {
            buffer += 'Explanation: ${c['explanation']}\n';
          }
          buffer += '\n';
        }
        return buffer.trim();

      case 'math_steps':
        final steps = (data['steps'] as List?) ?? [];
        final answer = data['answer'] ?? '';
        var buffer = '🔢 Step-by-Step Solution\n\n';
        for (var i = 0; i < steps.length; i++) {
          buffer += 'Step ${i + 1}: ${steps[i]}\n';
        }
        if (answer.isNotEmpty) buffer += '\nResult: $answer';
        return buffer.trim();

      default:
        return 'Artifact content';
    }
  }

  Widget _buildSources(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.share,
                    size: 20, color: theme.primaryColor),
                onPressed: () => SharePlus.instance.share(ShareParams(
                    text:
                        widget.message.sources!.map((s) => s.url).join('\n'))),
              ),
              const SizedBox(width: 8),
              Text(
                "Sources",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.message.sources!
                .map((s) => _buildSourceChip(s, theme, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(SourceMetadata source, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () {
        final url = source.url;
        if (url != null && url.isNotEmpty) {
          InAppResearchBrowser.show(context, url, title: source.title);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          source.title,
          style: TextStyle(
            fontSize: 11,
            color: theme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseQuizData(String json) {
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _parseFlashcardData(String json) {
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (_) {
      return {};
    }
  }

  String _cleanContent(String content) {
    // Strip legacy :::ui-widget\n{...}\n::: blocks but RETAIN :::ui-widget|id:::
    // The legacy regex match requires a newline following ':::ui-widget'
    final clean = content.replaceAll(
        RegExp(r':::ui-widget[\r\n]+.*?([\r\n]+:::|$)', dotAll: true), '');
    return cleanContent(clean);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildReplyPreview(ThemeData theme, bool isUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUser
            ? Colors.white.withValues(alpha: 0.1)
            : theme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isUser ? Colors.white70 : theme.primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Text(
        widget.message.replyToText!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isUser
              ? Colors.white.withValues(alpha: 0.8)
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  bool _isImageUrl(String url) {
    if (url.isEmpty) return false;
    if (url.startsWith('data:image/')) return true;
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      return path.endsWith('.png') ||
          path.endsWith('.jpg') ||
          path.endsWith('.jpeg') ||
          path.endsWith('.gif') ||
          path.endsWith('.webp') ||
          path.endsWith('.bmp');
    } catch (e) {
      // Fallback for non-standard URLs
      final lower = url.toLowerCase().split('?').first;
      return lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.bmp');
    }
  }

  Widget _buildAiErrorCard(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'An Error occurred',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color:
                          isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Please try again with the button below.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.onRetrySend != null)
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                onPressed: widget.onRetrySend,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_clockwise,
                        size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Try Again',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CodeBlockWidget extends StatefulWidget {
  final String code;
  final String? language;
  final bool isDark;

  const _CodeBlockWidget({
    required this.code,
    this.language,
    required this.isDark,
  });

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  void _copyCode() {
    ClipboardService.instance.copyText(widget.code);
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color:
            widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with language label + copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                if (widget.language != null)
                  Text(
                    widget.language!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _copyCode,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? Row(
                            key: const ValueKey('copied'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_alt,
                                size: 14,
                                color: AppColors.accentTeal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copied',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accentTeal,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('copy'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.doc_on_clipboard,
                                size: 14,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: GoogleFonts.firaCode(
                fontSize: 14,
                color: widget.isDark ? Colors.tealAccent : Colors.teal.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Streaming Cursor Widget ---

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 16,
        margin: const EdgeInsets.only(left: 2, top: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// --- Thinking Skeleton Widget ---

class _ThinkingSkeleton extends StatefulWidget {
  final bool isDark;
  final String? status;

  const _ThinkingSkeleton({required this.isDark, this.status});

  @override
  State<_ThinkingSkeleton> createState() => _ThinkingSkeletonState();
}

class _ThinkingSkeletonState extends State<_ThinkingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)),
    );

    _pulseScale = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerColor = widget.isDark
            ? Colors.white.withValues(alpha: _shimmerAnimation.value * 0.15)
            : Colors.grey.withValues(alpha: _shimmerAnimation.value * 0.2);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLine(shimmerColor, 0.85),
              const SizedBox(height: 8),
              _buildLine(shimmerColor, 0.65),
              const SizedBox(height: 8),
              _buildLine(shimmerColor, 0.45),
              if (widget.status != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Gemini-style Pulsing Logo
                    Transform.scale(
                      scale: _pulseScale.value,
                      child: Opacity(
                        opacity: _pulseOpacity.value,
                        child: Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            color: widget.isDark
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.star),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.status!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? Colors.white70
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLine(Color color, double widthFraction) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      width: 300 * widthFraction,
    );
  }
}

class _TactileActionIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  final String? tooltip;
  final bool isActive;
  final Color? color;
  final bool isSmall;
  final bool isCopy;

  const _TactileActionIcon({
    required this.icon,
    required this.onTap,
    required this.theme,
    this.tooltip,
    this.isActive = false,
    this.color,
    this.isSmall = false,
    this.isCopy = false,
  });

  @override
  State<_TactileActionIcon> createState() => _TactileActionIconState();
}

class _TactileActionIconState extends State<_TactileActionIcon> {
  bool _showCheck = false;

  void _handleTap() {
    widget.onTap();
    if (widget.isCopy) {
      setState(() => _showCheck = true);
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showCheck = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalColor = _showCheck
        ? AppColors.accentTeal
        : (widget.color ??
            (widget.isActive
                ? AppColors.googleBlue
                : widget.theme.iconTheme.color?.withValues(alpha: 0.6)));

    return Semantics(
      label: widget.tooltip ?? 'Action button',
      button: true,
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _showCheck ? CupertinoIcons.checkmark_alt : widget.icon,
            key: ValueKey(_showCheck),
            size: widget.isSmall ? 16 : 18,
            color: finalColor,
          ),
        ),
        tooltip: widget.tooltip,
        onPressed: _showCheck ? null : _handleTap,
        splashRadius: 20,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

class _TactileArtifactActionIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  final String label;
  final bool isCopy;

  const _TactileArtifactActionIcon({
    required this.icon,
    required this.onTap,
    required this.theme,
    required this.label,
    this.isCopy = false,
  });

  @override
  State<_TactileArtifactActionIcon> createState() =>
      _TactileArtifactActionIconState();
}

class _TactileArtifactActionIconState extends State<_TactileArtifactActionIcon> {
  bool _showCheck = false;

  void _handleTap() {
    widget.onTap();
    if (widget.isCopy) {
      setState(() => _showCheck = true);
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showCheck = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.brightness == Brightness.dark;
    final activeColor = AppColors.accentTeal;

    return InkWell(
      onTap: _showCheck ? null : _handleTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _showCheck
              ? activeColor.withValues(alpha: 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(_showCheck),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showCheck ? CupertinoIcons.checkmark_alt : widget.icon,
                size: 14,
                color: _showCheck
                    ? activeColor
                    : widget.theme.iconTheme.color?.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                _showCheck ? 'Copied' : widget.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _showCheck
                      ? activeColor
                      : widget.theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
