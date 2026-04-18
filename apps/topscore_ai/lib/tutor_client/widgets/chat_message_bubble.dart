import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import 'chat_media_viewers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../services/clipboard_service.dart';
import '../../services/haptics_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/network_aware_image.dart';
import '../../widgets/gemini_reasoning_view.dart';
import '../../widgets/math_markdown.dart';
import '../../widgets/youtube_embed_widget.dart';
import '../../widgets/quiz_widget.dart';
import '../../widgets/flashcard_artifact_widget.dart';
import '../../widgets/math_stepper_widget.dart';

import '../../widgets/shared/video_carousel.dart';
import '../../utils/markdown/mermaid_builder.dart';
import '../../utils/markdown/table_builder.dart';
import '../../utils/markdown/desmos_builder.dart';
import '../../widgets/desmos_calculator_widget.dart';
import '../message_model.dart';
import '../../models/user_model.dart';
import 'mnemonic_card.dart';
import '../../widgets/graph_artifact_widget.dart';
import 'punnett_square_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/in_app_research_browser.dart';

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
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool isPlaybackError = false;

  Widget _buildDesmosCalculator(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      final type = data['calculator_type'] ?? data['type'] ?? 'graphing';
      
      // Handle both list of strings and comma-separated string
      List<String> expressions = [];
      final rawExpressions = data['expressions'] ?? data['expression'];
      if (rawExpressions is List) {
        expressions = List<String>.from(rawExpressions);
      } else if (rawExpressions != null) {
        expressions = rawExpressions.toString().split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final settings = data['settings'] as Map<String, dynamic>?;
      final viewport = data['viewport'] as Map<String, dynamic>?;

      return DesmosCalculatorWidget(
        calculatorType: type == 'desmos_config' ? 'graphing' : type,
        expressions: expressions,
        settings: settings,
        viewport: viewport,
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

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
    final hasNewAttachments = widget.message.attachments != null && widget.message.attachments!.isNotEmpty;
    final hasAttachment = hasLegacyAttachment || hasNewAttachments;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (hasAttachment) _buildAttachmentsCollection(context, theme, isDark),
            const SizedBox(height: 4),
            if (_cleanContent(widget.message.text).trim().isNotEmpty || 
                (widget.message.audioUrl != null && widget.message.text == '🎤 Audio Message'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                      : theme.colorScheme.primary,
                  border: isDark
                      ? Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        )
                      : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : theme.colorScheme.primary.withValues(alpha: 0.15)),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    final cleanedText = _cleanContent(widget.message.text).trim();

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

  Widget _buildAttachmentsCollection(BuildContext context, ThemeData theme, bool isDark) {
    // If we have new structured attachments, use them
    if (widget.message.attachments != null && widget.message.attachments!.isNotEmpty) {
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
    final fileUrl = widget.message.imageUrl ?? extractAttachedDocumentUrl(widget.message.text) ?? '';
    final fileType = widget.message.fileType ?? (fileUrl.isNotEmpty ? (_isImageUrl(fileUrl) ? 'image' : 'pdf') : 'document');
    final fileId = widget.message.fileId ?? (fileUrl.isNotEmpty ? 'FILE' : '');
    final fileName = widget.message.fileName ?? 'Document';

    return _buildAttachmentChip(context, theme, isDark, 
      url: fileUrl, type: fileType, id: fileId, name: fileName);
  }

  Widget _buildAttachmentChip(BuildContext context, ThemeData theme, bool isDark,
      {required String url, required String type, required String id, required String name}) {
    final isRawImage = widget.message.imageUrl != null &&
        (_isImageUrl(widget.message.imageUrl!) ||
            widget.message.imageUrl!.contains('FirebaseStorage'));
    final isImage = type.contains('image') || isRawImage;
    
    return GestureDetector(
      onTap: () => _handleAttachmentTap(context, url, type, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1F22) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
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
                    placeholder: (context, url) => Container(color: Colors.grey[800], child: const Icon(CupertinoIcons.photo, size: 16)),
                    errorWidget: (context, url, error) => const Icon(CupertinoIcons.photo, size: 16),
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
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isImage)
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black54,
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
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  void _handleAttachmentTap(BuildContext context, String url, String type, String name) {
    if (url.isEmpty) return;
    
    if (type == 'image') {
       Navigator.of(context).push(
         CupertinoPageRoute(builder: (_) => FullScreenImageViewer(
           imageUrl: url,
           heroTag: 'attachment_$url',
         ))
       );
    } else if (type == 'pdf') {
       Navigator.of(context).push(
         CupertinoPageRoute(builder: (_) => PdfViewerScreen(url: url, title: name))
       );
    } else if (type == 'docx' || type == 'doc') {
       _showConversionAndViewer(context, url, name);
    } else {
       InAppResearchBrowser.show(context, url, title: name);
    }
  }

  Future<void> _showConversionAndViewer(BuildContext context, String url, String name) async {
    showCupertinoDialog(
      context: context,
      builder: (context) => const CupertinoActivityIndicator(radius: 20),
    );
    
    try {
      final convertedUrl = await _convertToPdf(url, context);
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      
      if (convertedUrl != null) {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => PdfViewerScreen(url: convertedUrl, title: name))
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
    }
  }

  Future<String?> _convertToPdf(String originalUrl, BuildContext context) async {
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
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E1F22) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TopScore AI',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    if (widget.message.isKicdCertified) ...[
                      const SizedBox(width: 8),
                      _buildKicdBadge(isDark),
                    ],
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((widget.isStreaming || widget.message.isThinking) &&
                        widget.message.text.isEmpty &&
                        (widget.message.reasoning == null ||
                            widget.message.reasoning!.isEmpty))
                      _ThinkingSkeleton(
                        isDark: isDark, 
                        status: widget.status ?? (widget.message.isThinking ? "Thinking..." : null)
                      ),
                    if (widget.message.reasoning != null &&
                        widget.message.reasoning!.isNotEmpty)
                      TopScoreReasoningView(
                        content: widget.message.reasoning!,
                        isThinking: widget.message.text.isEmpty,
                      ),
                    if (widget.message.replyToText != null)
                      _buildReplyPreview(theme, false),
                    if (widget.message.text.isNotEmpty)
                      _buildMarkdown(context, theme, isDark, settings),
                    if (widget.isStreaming && widget.message.text.isNotEmpty)
                      const _StreamingCursor(),
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
                        flashcardData:
                            _parseFlashcardData(widget.message.flashcardDataJson!),
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
              if (widget.message.desmosDataJson != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildDesmosCalculator(widget.message.desmosDataJson!),
                ),
              if (widget.message.graphDataJson != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GraphArtifactWidget(
                    graphDataJson: widget.message.graphDataJson!,
                  ),
                ),
              if (widget.message.punnettDataJson != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PunnettSquareWidget(
                    dataJson: widget.message.punnettDataJson!,
                  ),
                ),

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

  Widget _buildKicdBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
              : [const Color(0xFF003399), const Color(0xFF0066CC)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.checkmark_seal_fill,
            color: isDark ? Colors.black : Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            'KICD Certified',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

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
          _buildSmallActionIcon(
            CupertinoIcons.pencil,
            widget.onEdit,
            theme,
            tooltip: 'Edit',
          ),
          _buildSmallActionIcon(
            CupertinoIcons.doc_on_clipboard,
            widget.onCopy,
            theme,
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    final markdownStyle = MarkdownStyleSheet(
      p: GoogleFonts.nunito(
        fontSize: settings.fontSize + 2,
        fontWeight: FontWeight.w500,
        height: settings.lineHeight,
        color: widget.message.isUser ? Colors.white : theme.colorScheme.onSurface,
      ),
      h1: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: theme.primaryColor,
      ),
      h2: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: theme.primaryColor.withValues(alpha: 0.8),
      ),
      h3: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
      strong: const TextStyle(fontWeight: FontWeight.bold),
      em: const TextStyle(fontStyle: FontStyle.italic),
      listBullet: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.primaryColor),
      listIndent: 24.0,
      blockquote: GoogleFonts.nunito(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.primaryColor, width: 4)),
        color: theme.primaryColor.withValues(alpha: 0.05),
      ),
      code: GoogleFonts.firaCode(
        fontSize: 14,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08),
        color: isDark ? Colors.tealAccent : Colors.teal.shade800,
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      tableHead: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: theme.primaryColor,
      ),
      tableBody: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: widget.message.isUser ? Colors.white : theme.colorScheme.onSurface,
      ),
      tableBorder: TableBorder.all(
        color: theme.dividerColor.withValues(alpha: 0.15),
        width: 1,
        borderRadius: BorderRadius.circular(8),
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      tableCellsDecoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
      ),
      tableHeadAlign: TextAlign.center,
    );

    return MarkdownBody(
      data: _cleanContent(widget.message.text),
      selectable: true,
      softLineBreak: true,
      sizedImageBuilder: (config) {
        final imageUrl = config.uri.toString();
        Widget image;
        if (config.uri.scheme == 'http' || config.uri.scheme == 'https') {
          image = NetworkAwareImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            width: config.width,
            height: config.height,
          );
        } else {
          image = NetworkAwareImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            width: config.width,
            height: config.height,
          );
        }

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => FullScreenImageViewer(
                  imageUrl: imageUrl,
                  heroTag: 'msg_img_$imageUrl',
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Hero(
                    tag: 'msg_img_$imageUrl',
                    child: image,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildSmallFloatingAction(
                    CupertinoIcons.arrow_down_circle_fill,
                    () => SharePlus.instance.share(ShareParams(text: imageUrl)),
                    theme,
                    tooltip: 'Download or Share',
                  ),
                ),
              ],
            ),
          ),
        );
      },
      builders: {
        'latex': LatexElementBuilder(),
        'mermaid': MermaidElementBuilder(),
        'interactive-graph': InteractiveGraphElementBuilder(),
        'table': MarkdownTableBuilder(context, markdownStyle),
        'a': YouTubeLinkBuilder(context, isDark,
            isStreaming: widget.isStreaming),
        'pre': _CodeBlockBuilder(isDark: isDark),
      },
      extensionSet: md.ExtensionSet(
        [...md.ExtensionSet.gitHubFlavored.blockSyntaxes, MermaidBlockSyntax()],
        [
          md.EmojiSyntax(),
          LatexSyntax(),
          InteractiveGraphSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      styleSheet: markdownStyle,
      onTapLink: (text, href, title) {
        if (href != null) {
          if (href.toLowerCase().contains('youtube.com') || href.toLowerCase().contains('youtu.be')) {
            String? videoId = YoutubePlayerController.convertUrlToId(href);
            if (videoId != null) {
              _showInAppYouTubePlayer(context, videoId);
              return;
            }
          }
          
          if (href.toLowerCase().contains('.pdf') || 
              href.toLowerCase().contains('.docx') || 
              href.toLowerCase().contains('.doc')) {
            final type = href.toLowerCase().contains('.pdf') ? 'pdf' : 'docx';
            _handleAttachmentTap(context, href, type, text);
          } else {
            InAppResearchBrowser.show(context, href, title: text);
          }
        }
      },
    );
  }

  void _showInAppYouTubePlayer(BuildContext context, String videoId) {
    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        strictRelatedVideos: true,
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              YoutubePlayer(
                controller: controller,
                aspectRatio: 16 / 9,
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "TopScore AI Study Mode",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              )
            ],
          ),
        );
      },
    ).then((value) {
      controller.close();
    });
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
            _buildActionIcon(
              CupertinoIcons.speaker_2,
              () => widget.onSpeak(widget.message.text),
              theme,
              tooltip: 'Read aloud',
            ),
          _buildActionIcon(CupertinoIcons.doc_on_doc, widget.onCopy, theme,
              tooltip: 'Copy'),
          _buildActionIcon(
              CupertinoIcons.arrow_clockwise, widget.onRegenerate, theme,
              tooltip: 'Regenerate'),
          _buildActionIcon(
            widget.message.isBookmarked
                ? CupertinoIcons.bookmark_fill
                : CupertinoIcons.bookmark,
            widget.onToggleBookmark,
            theme,
            tooltip: 'Bookmark',
            color: widget.message.isBookmarked ? Colors.amber : null,
          ),
          _buildActionIcon(CupertinoIcons.share, widget.onShare, theme,
              tooltip: 'Share'),

          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.2),
          ),

          _buildActionIcon(
            CupertinoIcons.hand_thumbsup,
            () => widget.onFeedback(1),
            theme,
            isActive: widget.message.feedback == 1,
            color: widget.message.feedback == 1 ? AppColors.accentTeal : null,
          ),
          _buildActionIcon(
            CupertinoIcons.hand_thumbsdown,
            () => widget.onFeedback(-1),
            theme,
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
        _buildActionIcon(
          CupertinoIcons.play_fill,
          widget.onResumeTts,
          theme,
          isActive: true,
          color: AppColors.googleBlue,
        )
      else
        _buildActionIcon(
          CupertinoIcons.pause_fill,
          widget.onPauseTts,
          theme,
          isActive: true,
          color: AppColors.googleBlue,
        ),
      _buildActionIcon(
        CupertinoIcons.stop_fill,
        widget.onStopTts,
        theme,
        isActive: true,
        color: Colors.redAccent,
      ),
    ];
  }

  Widget _buildActionIcon(
    IconData icon,
    VoidCallback onTap,
    ThemeData theme, {
    String? tooltip,
    bool isActive = false,
    Color? color,
  }) {
    final finalColor = color ??
        (isActive
            ? AppColors.googleBlue
            : theme.iconTheme.color?.withValues(alpha: 0.6));
    return Semantics(
      label: tooltip ?? 'Action button',
      button: true,
      child: IconButton(
        icon: Icon(icon, size: 18, color: finalColor),
        tooltip: tooltip,
        onPressed: onTap,
        splashRadius: 20,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildSmallActionIcon(
    IconData icon,
    VoidCallback onTap,
    ThemeData theme, {
    String? tooltip,
  }) {
    return Semantics(
      label: tooltip ?? 'Small action button',
      button: true,
      child: IconButton(
        icon: Icon(icon,
            size: 16, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildSmallFloatingAction(
    IconData icon,
    VoidCallback onTap,
    ThemeData theme, {
    String? tooltip,
  }) {
    return Semantics(
      label: tooltip ?? 'Action button',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
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
          _buildArtifactActionIcon(
            CupertinoIcons.doc_on_clipboard,
            () => _copyArtifactToClipboard(context, type, data),
            theme,
            label: 'Copy text',
          ),
          const SizedBox(width: 8),
          _buildArtifactActionIcon(
            CupertinoIcons.share,
            () => _shareArtifact(context, type, data),
            theme,
            label: 'Share',
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactActionIcon(
    IconData icon,
    VoidCallback onTap,
    ThemeData theme, {
    required String label,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: theme.iconTheme.color?.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyArtifactToClipboard(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
  ) {
    final text = _formatArtifactAsText(type, data);
    ClipboardService.instance.copyWithFeedback(context, text);
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
          if (c['explanation'] != null) buffer += 'Explanation: ${c['explanation']}\n';
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
        color: isDark ? const Color(0xFF252525) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.share, size: 20, color: theme.primaryColor),
                onPressed: () => SharePlus.instance.share(ShareParams(text: widget.message.sources!.map((s) => s.url).join('\n'))),
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
    return cleanContent(content);
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
}

// --- Code Block with Copy Button ---

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;

  _CodeBlockBuilder({required this.isDark});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Extract code text from the element tree
    String codeText = element.textContent;

    // Try to detect language from the class attribute of the <code> child
    String? language;
    if (element.children != null && element.children!.isNotEmpty) {
      final firstChild = element.children!.first;
      if (firstChild is md.Element && firstChild.attributes['class'] != null) {
        final className = firstChild.attributes['class']!;
        if (className.startsWith('language-')) {
          language = className.substring('language-'.length);
        }
      }
    }

    return _CodeBlockWidget(
      code: codeText,
      language: language,
      isDark: isDark,
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
    ClipboardService.instance.copyWithFeedback(context, widget.code);
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
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shimmerColor = widget.isDark
            ? Colors.white.withValues(alpha: _animation.value * 0.15)
            : Colors.grey.withValues(alpha: _animation.value * 0.2);

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.status!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color:
                              widget.isDark ? Colors.white70 : Colors.black54,
                          fontStyle: FontStyle.italic,
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
