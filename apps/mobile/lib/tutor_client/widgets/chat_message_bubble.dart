import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/cors_proxy_helper.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../services/clipboard_service.dart';
import '../../services/haptics_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/image_cache_manager.dart';
import '../../widgets/network_aware_image.dart';
import '../../widgets/gemini_reasoning_view.dart';
import '../../widgets/math_markdown.dart';
import '../../widgets/youtube_embed_widget.dart';
import '../../widgets/quiz_widget.dart';
import '../../widgets/flashcard_artifact_widget.dart';
import '../../widgets/math_stepper_widget.dart';
import '../../widgets/level_up_overlay.dart';
import '../../providers/gamification_provider.dart';
import '../../services/xp_service.dart';
import '../../widgets/virtual_lab/video_carousel.dart';
import '../../utils/markdown/mermaid_builder.dart';
import '../../utils/markdown/table_builder.dart';
import '../../utils/markdown/desmos_builder.dart';
import '../../widgets/desmos_calculator_widget.dart';
import '../message_model.dart';
import '../../models/user_model.dart';
import 'mnemonic_card.dart';
import '../../widgets/graph_artifact_widget.dart';

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
      direction: DismissDirection.horizontal,
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
                  // Resolve file URL: prefer imageUrl, fall back to legacy embedded URL
                  final effectiveFileUrl = widget.message.imageUrl ??
                      extractAttachedDocumentUrl(widget.message.text);
                  final bool hasImage =
                      effectiveFileUrl != null && _isImageUrl(effectiveFileUrl);
                  final bool hasFileAttachment = effectiveFileUrl != null &&
                      !_isImageUrl(effectiveFileUrl);
                  final cleanedText = _cleanContent(widget.message.text).trim();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.message.replyToText != null)
                        _buildReplyPreview(theme, true),
                      if (widget.message.audioUrl != null &&
                          widget.message.text == '🎤 Audio Message')
                        _buildVoicePlayer(context, theme),
                      if (hasImage) _buildImage(context),
                      if (hasFileAttachment)
                        _buildFileAttachmentCard(context, effectiveFileUrl),
                      if (!(widget.message.audioUrl != null &&
                              widget.message.text == '🎤 Audio Message') &&
                          cleanedText.isNotEmpty)
                        _buildMarkdown(context, theme, isDark, settings),
                    ],
                  );
                },
              ),
            ),
            _buildUserActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble(BuildContext context, ThemeData theme, bool isDark,
      SettingsProvider settings) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticsService.instance.mediumImpact();
          ClipboardService.instance
              .copyWithFeedback(context, widget.message.text);
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small AI label
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

              // Content
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

              // Specialized Widgets
              if (widget.message.quizDataJson != null)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: QuizWidget(
                        quizData: _parseQuizData(widget.message.quizDataJson!),
                        onComplete: (score) {
                          final questions = (_parseQuizData(
                                          widget.message.quizDataJson!)['questions']
                                      as List?)
                                  ?.length ??
                              1;
                          final pct = score / questions;
                          final uid = context.read<AuthProvider>().userModel?.uid;
                          if (uid != null) {
                            context
                                .read<GamificationProvider>()
                                .record(uid, ActivityType.quizCompleted);
                          }
                          if (pct >= 0.7 && context.mounted) {
                            LevelUpOverlay.show(context,
                                type: LevelUpType.missionCleared);
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

              // Sources
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

  Widget _buildImage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: CorsProxyHelper.getCorsProxyUrl(widget.message.imageUrl!),
              cacheManager: ChatImageCacheManager(),
              httpHeaders: CorsProxyHelper.standardHeaders,
              height: 200,
              width: 200,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (context, url) => Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.photo,
                  color: Colors.grey,
                  size: 32,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _buildSmallFloatingAction(
              CupertinoIcons.arrow_down_circle_fill,
              () => widget.onDownloadImageUrl(widget.message.imageUrl ?? ''),
              Theme.of(context),
              tooltip: 'Download or Share',
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

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
              Positioned(
                top: 8,
                right: 8,
                child: _buildSmallFloatingAction(
                  CupertinoIcons.arrow_down_circle_fill,
                  () => widget.onDownloadImageUrl(imageUrl),
                  theme,
                  tooltip: 'Download or Share',
                ),
              ),
            ],
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
    );
  }

  Widget _buildAiActions(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Left action group
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

          // Separator
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.2),
          ),

          // Feedback
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
    ClipboardService.instance.shareText(text);
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
              Icon(
                CupertinoIcons.checkmark_shield,
                size: 16,
                color: theme.primaryColor,
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
    return Container(
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

  Widget _buildFileAttachmentCard(BuildContext context, String fileUrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPdf = _isPdfUrl(fileUrl);
    final fileName = _extractFileName(fileUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPdf
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? CupertinoIcons.doc_fill : Icons.description_rounded,
              size: 20,
              color: isPdf ? Colors.red[400] : Colors.blue[400],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isPdf ? 'PDF Document' : 'Document',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isPdfUrl(String url) {
    try {
      final path = Uri.parse(url).path.toLowerCase();
      return path.endsWith('.pdf');
    } catch (_) {
      return url.toLowerCase().split('?').first.endsWith('.pdf');
    }
  }

  String _extractFileName(String url) {
    try {
      final path = Uri.parse(url).path;
      final decoded = Uri.decodeComponent(path.split('/').last);
      if (decoded.isNotEmpty && decoded != '/') return decoded;
    } catch (_) {}
    return 'Document';
  }

  bool _isImageUrl(String url) {
    if (url.isEmpty) return false;
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
