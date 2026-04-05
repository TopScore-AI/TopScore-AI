// Removed dart:io import to ensure Web compatibility
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:confetti/confetti.dart';

import '../providers/auth_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import 'message_model.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/chat_history_sidebar.dart';
import 'widgets/empty_state_widget.dart';
import '../widgets/glass_card.dart';
import '../screens/auth/guest_welcome_screen.dart';
import 'chat_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? chatThread;
  final XFile? initialImage;
  final String? initialMessage;
  final String? subject;
  final String? initialFileUrl;
  final String? initialFileName;
  final String? initialFileType;
  final String? initialInputText;
  final Uint8List? initialFileBytes;
  final bool isEmbedded;
  final bool startVoice;

  const ChatScreen({
    super.key,
    this.chatThread,
    this.initialImage,
    this.initialMessage,
    this.subject,
    this.initialFileUrl,
    this.initialFileName,
    this.initialFileType,
    this.initialInputText,
    this.initialFileBytes,
    this.isEmbedded = false,
    this.startVoice = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<ChatController>(context, listen: false);
      final historyProvider = Provider.of<AiTutorHistoryProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid;

      if (widget.chatThread != null) {
        controller.loadThread(
          widget.chatThread!['thread_id'],
          historyProvider: historyProvider,
          userId: userId,
        );
      }
      if (widget.startVoice) {
        controller.startLiveVoiceMode(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.watch<ChatController>();

    if (widget.isEmbedded) {
      return Container(
        color: isDark ? const Color(0xFF000000) : theme.scaffoldBackgroundColor,
        child: _ChatScreenView(controller: controller, theme: theme, isDark: isDark),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 700;
        return Scaffold(
          key: controller.scaffoldKey,
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          drawer: _buildMobileDrawer(context, controller, theme, isDark),
          appBar: _buildAppBar(context, controller, theme, isDark, isDesktop),
          body: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF000000)
                  : theme.scaffoldBackgroundColor,
              gradient: isDark
                  ? const RadialGradient(
                      center: Alignment.topCenter,
                      radius: 2.5,
                      colors: [Color(0xFF181835), Color(0xFF0A0A14)],
                      stops: [0.0, 1.0],
                    )
                  : null,
            ),
            child: SafeArea(
                child: _ChatScreenView(controller: controller, theme: theme, isDark: isDark)),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context,
      ChatController controller, ThemeData theme, bool isDark, bool isDesktop) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(CupertinoIcons.line_horizontal_3,
            color: theme.colorScheme.primary),
        onPressed: () => controller.toggleSidebar(),
      ),
      title: Text(
        controller.stripMarkdown(controller.currentTitle),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Icon(CupertinoIcons.square_pencil,
                color: theme.colorScheme.primary),
            onPressed: () => controller.startNewChat(closeDrawer: false),
            tooltip: 'New Chat',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDrawer(BuildContext context, ChatController controller,
      ThemeData theme, bool isDark) {
    final historyProvider = Provider.of<AiTutorHistoryProvider>(context);
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: ChatHistorySidebar(
        isDark: isDark,
        threads: historyProvider.threads,
        historySearchQuery: controller.historySearchQuery,
        historySearchController: controller.historySearchController,
        isLoadingHistory: controller.isLoadingHistory,
        currentThreadId: controller.wsServiceOrNull?.threadId ?? '',
        onCloseSidebar: () => Navigator.pop(context),
        onStartNewChat: ({bool closeDrawer = true}) =>
            controller.startNewChat(closeDrawer: closeDrawer),
        onLoadThread: (id) => controller.loadThread(
          id,
          historyProvider: historyProvider,
          userId: Provider.of<AuthProvider>(context, listen: false).userModel?.uid,
        ),
        onRenameThread: (id, title) => controller.showRenameDialog(context, id, title),
        onDeleteThread: (id) => controller.confirmDeleteThread(context, id),
        onDeleteAllThreads: () => controller.deleteAllChatHistory(context),
        onFinishLesson: () => controller.showRatingDialog(context),
        onSearchChanged: (q) => controller.onSearchChanged(q),
      ),
    );
  }
}

class _ChatScreenView extends StatelessWidget {
  final ChatController controller;
  final ThemeData theme;
  final bool isDark;

  const _ChatScreenView({
    required this.controller,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _buildMainChatArea(context);
  }


  Widget _buildGamificationBar(BuildContext context, ChatController controller,
      ThemeData theme, bool isDark) {
    if (controller.totalXp == 0 && controller.gamificationAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: controller.showGamificationConfetti
              ? Colors.amber.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '${controller.totalXp} XP',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      color: controller.currentStreak > 0
                          ? Colors.deepOrange
                          : Colors.grey,
                      size: 24),
                  const SizedBox(width: 4),
                  Text(
                    '${controller.currentStreak} Day Streak',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: controller.currentStreak > 0
                          ? Colors.deepOrange
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (controller.gamificationAlerts.isNotEmpty) ...[
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.sparkles,
                        size: 16, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.gamificationAlerts.last,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.clearGamificationAlerts(),
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.grey),
                    )
                  ],
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildPersistenceBanner(BuildContext context, ChatController controller,
      ThemeData theme, bool isDark) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Only show if: Web + Guest + Not Dismissed
    if (!kIsWeb || !authProvider.isGuestMode || controller.dismissedPersistenceBanner) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      opacity: 0.05,
      borderRadius: 16,
      border: Border.all(
        color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.4),
        width: 1,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, 
              color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unsaved History',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Refreshing your browser will clear this chat.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const GuestSavePromptDialog(),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Sign Up to Save',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => controller.dismissPersistenceBanner(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 16,
            color: theme.hintColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMainChatArea(BuildContext context) {
    final theme = this.theme;
    final isDark = this.isDark;
    final controller = this.controller;
    final authProvider = Provider.of<AuthProvider>(context);

    return Center(
      child: RepaintBoundary(
        key: controller.appRepaintBoundaryKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
        child: Column(
          children: [
            _buildGamificationBar(context, controller, theme, isDark),
            _buildPersistenceBanner(context, controller, theme, isDark),
            Expanded(
              child: Stack(
                children: [
                  if (controller.isLoadingMessages)
                    Center(
                        child: CircularProgressIndicator(
                            color: theme.primaryColor))
                  else if (controller.messages.isEmpty)
                    EmptyStateWidget(
                      isDark: isDark,
                      theme: theme,
                      userName: authProvider.userModel?.displayName,
                      suggestions: controller.dynamicSuggestions,
                      onSuggestionTap: (prompt) =>
                          controller.sendUserMessage(context, text: prompt),
                    )
                  else
                    RefreshIndicator(
                      onRefresh: () => controller.refreshChat(),
                      color: theme.primaryColor,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        child: ListView.builder(
                          controller: controller.scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 24),
                          itemCount: controller.messages.length +
                              (controller.isTyping &&
                                      controller.currentStreamingMessageId ==
                                          null
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (index == controller.messages.length) {
                              return ChatMessageBubble(
                                key: const ValueKey('thinking'),
                                message: ChatMessage(
                                  id: 'thinking',
                                  text: '',
                                  isUser: false,
                                  isComplete: false,
                                  isTemporary: true,
                                  timestamp: DateTime.now(),
                                  threadId: controller.wsServiceOrNull?.threadId ?? '',
                                ),
                                isStreaming: true,
                                status: controller.currentAiStatus ?? 'Thinking...',
                                onPlayVoice: () {},
                                onPauseVoice: () {},
                                onResumeVoice: () {},
                                onSpeak: (_) {},
                                onStopTts: () {},
                                onPauseTts: () {},
                                onResumeTts: () {},
                                onCopy: () {},
                                onToggleBookmark: () {},
                                onShare: () {},
                                onRegenerate: () {},
                                onFeedback: (_) {},
                                onEdit: () {},
                                onDownloadImageUrl: (_) {},
                                onReply: (_) {},
                                onLongPress: () {},
                                user: authProvider.userModel,
                              );
                            }

                            final message = controller.messages[index];
                            final isStreaming =
                                controller.currentStreamingMessageId ==
                                    message.id;

                            return ChatMessageBubble(
                              key: ValueKey(message.id),
                              message: message,
                              isStreaming: isStreaming,
                              status: isStreaming
                                  ? controller.currentAiStatus
                                  : null,
                              playingAudioMessageId:
                                  controller.playingAudioMessageId,
                              isPlayingAudio: controller.isPlayingAudio,
                              audioDuration: controller.audioDuration,
                              audioPosition: controller.audioPosition,
                              speakingMessageId: controller.speakingMessageId,
                              isTtsSpeaking: controller.isTtsSpeaking,
                              isTtsPaused: controller.isTtsPaused,
                              onPlayVoice: () {
                                if (message.audioUrl != null) {
                                  controller.playVoiceMessage(
                                      message.id, message.audioUrl!);
                                }
                              },
                              onPauseVoice: () =>
                                  controller.pauseVoiceMessage(),
                              onResumeVoice: () =>
                                  controller.resumeVoiceMessage(),
                              onSpeak: (text) =>
                                  controller.speak(text, messageId: message.id),
                              onStopTts: () => controller.stopTts(),
                              onPauseTts: () => controller.pauseTts(),
                              onResumeTts: () => controller.resumeTts(),
                                onCopy: () =>
                                  controller.copyToClipboard(context, message.text),
                              onToggleBookmark: () =>
                                  controller.toggleBookmark(message),
                              onShare: () =>
                                  controller.shareMessage(message.text),
                              onRegenerate: () =>
                                  controller.regenerateResponse(context, message),
                              onFeedback: (feedback) =>
                                  controller.provideFeedback(message, feedback),
                              onEdit: () => controller.handleUserEdit(context, message),
                              onDownloadImageUrl: (url) => controller
                                  .downloadImage(context, url),
                              onReply: (m) => controller.replyTo = m,
                              onLongPress: () =>
                                  controller.copyToClipboard(context, message.text),
                              user: authProvider.userModel,
                            );
                          },
                        ),
                      ),
                    ),
                  if (controller.showScrollDownButton)
                    Positioned(
                      bottom: 16,
                      right: 20,
                      child: FloatingActionButton.small(
                        backgroundColor: theme.primaryColor,
                        onPressed: () => controller.scrollToBottom(),
                        elevation: 4,
                        child: const Icon(Icons.arrow_downward,
                            color: Colors.white),
                      ),
                    ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: controller.confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        Colors.green,
                        Colors.blue,
                        Colors.pink,
                        Colors.orange,
                        Colors.purple
                      ],
                    ),
                  ),
                  if (controller.isVoiceMode)
                    Positioned.fill(
                        child: controller.buildVoiceOverlay(context, theme)),
                ],
              ),
            ),
            ChatInputArea(
              textController: controller.textController,
              messageFocusNode: controller.messageFocusNode,
              pendingFileName: controller.pendingFileName,
              pendingPreviewData: controller.pendingPreviewData,
              pendingFileUrl: controller.pendingPreviewData,
              isUploading: controller.isUploading,
              isTyping: controller.isTyping,
              isGenerating: controller.isTyping ||
                  controller.currentStreamingMessageId != null,
              isRecording: controller.isRecording,
              suggestions: controller.dynamicSuggestions,
              placeholderMessages: controller.placeholderMessages,
              onSendMessage: () => controller.sendUserMessage(context),
              onSendMessageWithText: ({String? text}) =>
                  controller.sendUserMessage(context, text: text),
              onShowAttachmentMenu: () =>
                  controller.showAttachmentMenu(context, theme, isDark),
              onPaste: () => controller.handleGenericPaste(),
              onStopGeneration: () => controller.stopGeneration(),
              onStopListeningAndSend: () => controller.stopDictationAndSend(context),
              onStartLiveVoiceMode: () => controller.startLiveVoiceMode(context),
              onStartFeynmanMode: () => controller.startLiveVoiceMode(context, feynmanMode: true),
              onClearPendingAttachment: () =>
                  controller.clearPendingAttachment(),
              onShuffleQuestions: () {},
              onDictation: () => controller.startDictation(context),
              replyingToMessage: controller.replyTo,
              onCancelReply: () => controller.cancelReply(),
              amplitudeStream: controller.aiAmplitudeStream,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Text(
                'TopScore AI can make mistakes, please verify important information.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w400,
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
