// Removed dart:io import to ensure Web compatibility
import 'dart:ui';
import 'package:flutter/cupertino.dart' hide ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/auth_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../services/recovery_service.dart';
import 'message_model.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/chat_history_sidebar.dart';
import 'widgets/empty_state_widget.dart';
import '../widgets/glass_card.dart';
import '../providers/tutor_connection_provider.dart';
import '../widgets/trial_completed_overlay.dart';

import 'chat_controller.dart';
import 'package:topscore_ai/tutor_client/connection_manager.dart' as cm;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = Provider.of<ChatController>(context, listen: false);
      final historyProvider =
          Provider.of<AiTutorHistoryProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final tutorConn =
          Provider.of<TutorConnectionProvider>(context, listen: false);

      // Ensure the shared WebSocket is active when the AI Tutor screen mounts.
      // This recovers from paused, idle-disconnected, or max-reconnect-failed
      // states that may have occurred while the user was on another screen.
      tutorConn.resume();

      controller.setHistoryProvider(historyProvider);

      final wsService = tutorConn.wsService;
      if (wsService != null) {
        wsService.userName = authProvider.userModel?.preferredName ??
            authProvider.userModel?.displayName;
        controller.init(wsService);
      }

      // Re-init if service changes (e.g. Guest -> Auth upgrade)
      tutorConn.addListener(() {
        if (!mounted) return;
        final newWs = tutorConn.wsService;
        if (newWs != null && newWs != controller.wsServiceOrNull) {
          if (kDebugMode) {
            debugPrint(
                '[ChatScreen] WebSocket service replaced, re-initializing controller');
          }
          newWs.userName = authProvider.userModel?.preferredName ??
              authProvider.userModel?.displayName;
          controller.init(newWs);
        }
      });

      // Listen for limit reached events and show popup dialog
      controller.limitReached.addListener(() {
        if (controller.limitReached.value != null) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => TrialCompletedOverlay(
                requiresAccount: authProvider.userModel == null,
              ),
            ).then((_) {
              // Clear the limit so it can be triggered again if needed
              controller.limitReached.value = null;
            });
          }
        }
      });

      final userId = authProvider.userModel?.uid;

      final threadId = widget.chatThread?['thread_id']?.toString();
      if (threadId != null) {
        controller.loadThread(
          threadId,
          historyProvider: historyProvider,
          userId: userId,
        );
      }

      // Handle initial resources (e.g. from PDF Snap & Solve)
      if (widget.initialImage != null ||
          widget.initialMessage != null ||
          widget.initialInputText != null ||
          widget.initialFileUrl != null ||
          widget.initialFileBytes != null) {
        await controller.handleInitialResources(
          image: widget.initialImage,
          text: widget.initialInputText ?? widget.initialMessage,
          fileUrl: widget.initialFileUrl,
          fileName: widget.initialFileName,
          fileType: widget.initialFileType,
          fileBytes: widget.initialFileBytes,
        );

        // AUTO-SEND: If an initial message is provided (e.g. from Summarize/Flashcards)
        // and it's not a voice-mode request, send it immediately for instant feedback.
        if (widget.initialMessage != null && !widget.startVoice) {
          if (mounted) {
            controller.sendUserMessage(context);
          }
        }
      }

      // THE LIFELINE: Check for recovered images from Background Kill routed from main.dart
      if (RecoveryService.recoveredFile != null) {
        await controller.handleInitialResources(
            image: RecoveryService.recoveredFile);
        RecoveryService.recoveredFile = null; // consume it
      }

      // Auto-start Live Voice when the caller requested it (e.g. the PDF
      // viewer's "Live Voice" shortcut). Pre-warming audio on the same user
      // gesture is important for web, where autoplay policies require it.
      if (widget.startVoice && !controller.isVoiceMode) {
        controller.preWarmAudio().whenComplete(() {
          if (!mounted) return;
          controller.startLiveVoiceMode(context);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldThreadId = oldWidget.chatThread?['thread_id']?.toString();
    final newThreadId = widget.chatThread?['thread_id']?.toString();

    if (newThreadId != null && newThreadId != oldThreadId) {
      final controller = Provider.of<ChatController>(context, listen: false);
      final historyProvider =
          Provider.of<AiTutorHistoryProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      controller.loadThread(
        newThreadId,
        historyProvider: historyProvider,
        userId: authProvider.userModel?.uid,
      );
    }

    // Handle updates to initial resources (e.g. if a URL resolves after the sheet is opened)
    if (widget.initialFileUrl != oldWidget.initialFileUrl &&
        widget.initialFileUrl != null) {
      final controller = Provider.of<ChatController>(context, listen: false);
      controller.handleInitialResources(
        fileUrl: widget.initialFileUrl,
        fileName: widget.initialFileName,
        fileType: widget.initialFileType,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.watch<ChatController>();

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _ChatScreenView(
            controller: controller, theme: theme, isDark: isDark),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 700;
        return Scaffold(
          key: controller.scaffoldKey,
          backgroundColor: theme.scaffoldBackgroundColor,
          extendBodyBehindAppBar: true,
          drawer: _buildMobileDrawer(context, controller, theme, isDark),
          appBar: _buildAppBar(context, controller, theme, isDark, isDesktop),
          body: _ChatScreenView(
              controller: controller, theme: theme, isDark: isDark),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context,
      ChatController controller, ThemeData theme, bool isDark, bool isDesktop) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 30,
      leading: IconButton(
        icon: const Icon(
          CupertinoIcons.line_horizontal_3,
          size: 30,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => controller.toggleSidebar(),
      ),
      leadingWidth: 30,
      title: Text(
        controller.currentTitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: const Icon(
              CupertinoIcons.plus_bubble,
              size: 30,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: theme.colorScheme.primary,
            tooltip: 'New Chat',
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.startNewChat(closeDrawer: false);
            },
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
        onLoadThread: (id) {
          controller.loadThread(
            id,
            historyProvider: historyProvider,
            userId: Provider.of<AuthProvider>(context, listen: false)
                .userModel
                ?.uid,
          );
          Navigator.pop(context); // Close drawer after selection
        },
        onRenameThread: (id, title) =>
            controller.showRenameDialog(context, id, title),
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

  Widget _buildConnectionBanner(BuildContext context, ChatController controller,
      ThemeData theme, bool isDark) {
    return StreamBuilder<cm.ConnectionState>(
      stream: controller.connectionStateStream,
      initialData: controller.connectionState,
      builder: (context, snap) {
        final state = snap.data ?? cm.ConnectionState.connected;
        // Only show banner for non-connected states
        final isOfflineNet = state == cm.ConnectionState.offline;
        final isReconnecting = state == cm.ConnectionState.reconnecting ||
            state == cm.ConnectionState.connecting;
        final isDisconnected = state == cm.ConnectionState.disconnected;

        // Hide transient connection states to make background persistence feel seamless
        if (state == cm.ConnectionState.connected ||
            isReconnecting ||
            isDisconnected) {
          return const SizedBox.shrink();
        }
        final color = isOfflineNet
            ? Colors.redAccent
            : (isReconnecting ? Colors.amber.shade700 : Colors.grey.shade600);
        final icon = isOfflineNet
            ? CupertinoIcons.wifi_slash
            : (isReconnecting
                ? CupertinoIcons.arrow_2_circlepath
                : CupertinoIcons.exclamationmark_triangle);
        final label = isOfflineNet
            ? "You're offline"
            : (isReconnecting
                ? 'Reconnecting…'
                : (isDisconnected ? 'Disconnected' : 'Connecting…'));
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (isReconnecting)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else if (isDisconnected)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      controller.wsServiceOrNull?.resetConnection(),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainChatArea(BuildContext context) {
    final theme = this.theme;
    final isDark = this.isDark;
    final controller = this.controller;
    final authProvider = Provider.of<AuthProvider>(context);

    final content = RepaintBoundary(
      key: controller.appRepaintBoundaryKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Stack(
            children: [
            // 1. Connection banner & Messages Stack (occupies full height of the stack!)
            Positioned.fill(
              child: Column(
                children: [
                  _buildConnectionBanner(context, controller, theme, isDark),
                  Expanded(
                    child: Stack(
                      children: [
                        if (controller.isLoadingMessages)
                          _buildLoadingSkeleton(isDark)
                        else if (controller.messages.isEmpty)
                          EmptyStateWidget(
                            isDark: isDark,
                            theme: theme,
                            userName: authProvider.userModel?.preferredName ??
                                authProvider.userModel?.displayName,
                            suggestions: controller.dynamicSuggestions,
                            onSuggestionTap: (prompt) => controller
                                .sendUserMessage(context, text: prompt),
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
                                physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics()),
                                padding: EdgeInsets.only(
                                  left: 0,
                                  right: 0,
                                  top: MediaQuery.of(context).padding.top +
                                      12, // Saved top real estate!
                                  bottom: controller.isVoiceMode
                                      ? 160
                                      : 100, // Messages scroll smoothly under the ChatInputArea
                                ),
                                itemCount: controller.messages.length +
                                    (controller.isTyping &&
                                            controller
                                                    .currentStreamingMessageId ==
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
                                        threadId: controller
                                                .wsServiceOrNull?.threadId ??
                                            '',
                                      ),
                                      isStreaming: true,
                                      status: controller.currentAiStatus ??
                                          'Thinking...',
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
                                  final lastUserIndex = controller.messages
                                      .lastIndexWhere((m) => m.isUser);
                                  final isEditable =
                                      message.isUser && index == lastUserIndex;

                                  return ChatMessageBubble(
                                    key: ValueKey(message.id),
                                    message: message,
                                    isStreaming: isStreaming,
                                    isEditable: isEditable,
                                    status: isStreaming
                                        ? controller.currentAiStatus
                                        : null,
                                    playingAudioMessageId:
                                        controller.playingAudioMessageId,
                                    isPlayingAudio: controller.isPlayingAudio,
                                    audioDuration: controller.audioDuration,
                                    audioPosition: controller.audioPosition,
                                    speakingMessageId:
                                        controller.speakingMessageId,
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
                                    onSpeak: (text) => controller.speak(text,
                                        messageId: message.id),
                                    onStopTts: () => controller.stopTts(),
                                    onPauseTts: () => controller.pauseTts(),
                                    onResumeTts: () => controller.resumeTts(),
                                    onCopy: () => controller.copyToClipboard(
                                        context, message.text),
                                    onToggleBookmark: () =>
                                        controller.toggleBookmark(message),
                                    onShare: () =>
                                        controller.shareMessage(message.text),
                                    onRegenerate: () => controller
                                        .regenerateResponse(context, message),
                                    onFeedback: (feedback) => controller
                                        .provideFeedback(message, feedback),
                                    onEdit: () => controller.handleUserEdit(
                                        context, message),
                                    onDownloadImageUrl: (url) =>
                                        controller.downloadImage(context, url),
                                    onReply: (m) => controller.replyTo = m,
                                    onLongPress: () => controller
                                        .copyToClipboard(context, message.text),
                                    onRetrySend: () => controller
                                        .retryFailedMessage(context, message),
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
                        if (controller.isVoiceMode) ...[
                          // Top indicator badge (LAB LIVE / CO-PILOT LIVE)
                          if (controller.buildVoiceIndicatorBadge(context) !=
                              null)
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 10,
                              left: 20,
                              right: 20,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  controller.buildVoiceIndicatorBadge(context)!
                                ],
                              ),
                            ),
                          // Floating camera preview
                          if (controller.buildCameraPreview(context) != null)
                            Positioned(
                              bottom: MediaQuery.of(context).padding.bottom +
                                  10 +
                                  ChatControllerLiveVoice
                                      .voiceControlBarHeight +
                                  10,
                              left: 20,
                              child: controller.buildCameraPreview(context)!,
                            ),
                          // Bottom voice control bar
                          Positioned(
                            bottom: MediaQuery.of(context).padding.bottom + 10,
                            left: 12,
                            right: 12,
                            child:
                                controller.buildVoiceControlBar(context, theme),
                          ),
                          // Live Visual Peek Overlay (NEW)
                          if (controller.isVoiceMode &&
                              controller.lastVisualMessage != null)
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 70,
                              right: 20,
                              child: _LiveVisualPeek(
                                message: controller.lastVisualMessage!,
                                onDismiss: () =>
                                    controller.clearVisualMessage(),
                                onView: () {
                                  controller.scrollToBottom();
                                },
                              ),
                            ),
                        ],
                        ...controller.xpAwards.map((award) => Positioned(
                              top: 100,
                              left: 20,
                              right: 20,
                              child: _XpAwardCelebration(
                                amount: award['amount'] as int,
                                reason: award['reason'] as String,
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Top Fading Blur Gradient Overlay (Nearly invisible top border, text dissolves on scroll)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).padding.top + 40,
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.scaffoldBackgroundColor,
                            theme.scaffoldBackgroundColor
                                .withValues(alpha: 0.9),
                            theme.scaffoldBackgroundColor
                                .withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Bottom Fading Blur Gradient Overlay (Nearly invisible bottom border, text dissolves on scroll)
            if (!controller.isVoiceMode)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 120, // Extends slightly above ChatInputArea
                child: IgnorePointer(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              theme.scaffoldBackgroundColor,
                              theme.scaffoldBackgroundColor
                                  .withValues(alpha: 0.95),
                              theme.scaffoldBackgroundColor
                                  .withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Floating ChatInputArea (Positions beautifully at the bottom, overlays stack!)
            if (!controller.isVoiceMode)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom,
                left: 0,
                right: 0,
                child: ChatInputArea(
                  textController: controller.textController,
                  messageFocusNode: controller.messageFocusNode,
                  attachButtonKey: controller.attachButtonKey,
                  pendingAttachments: controller.pendingAttachments,
                  onRemoveAttachment: (id) => controller.removeAttachment(id),
                  isUploading: controller.isUploading,
                  isTyping: controller.isTyping,
                  isGenerating: controller.isTyping ||
                      controller.currentStreamingMessageId != null,
                  isRecording: controller.isRecording,
                  isLocked: !authProvider.canSendMessage,
                  isOffline: controller.isOffline,
                  isConnecting: controller.isConnecting,
                  placeholderMessages: controller.placeholderMessages,
                  onSendMessage: () => controller.sendUserMessage(context),
                  onSendMessageWithText: ({String? text}) =>
                      controller.sendUserMessage(context, text: text),
                  onShowAttachmentMenu: () =>
                      controller.showAttachmentMenu(context, theme, isDark),
                  onPaste: () => controller.handleGenericPaste(),
                  onStopGeneration: () => controller.stopGeneration(),
                  onStopListeningAndSend: () =>
                      controller.stopDictationAndSend(context),
                  onStartLiveVoiceMode: () =>
                      controller.startLiveVoiceMode(context),
                  onStartFeynmanMode: () =>
                      controller.startLiveVoiceMode(context, feynmanMode: true),
                  onClearPendingAttachment: () =>
                      controller.clearPendingAttachment(),
                  onShuffleQuestions: () {},
                  onDictation: () => controller.startDictation(context),
                  replyingToMessage: controller.replyTo,
                  onCancelReply: () => controller.cancelReply(),
                  amplitudeStream: controller.aiAmplitudeStream,
                ),
              ),
          ],
        ),
      ),
      ),
    );

    if (controller.isEmbedded) {
      return content;
    }

    return Center(child: content);
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
            5,
            (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Shimmer.fromColors(
                    baseColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey[300]!,
                    highlightColor: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey[100]!,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 100,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: "80%".contains('%')
                              ? 250
                              : 250, // Simple placeholder for width
                          height: 14,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7)),
                        ),
                      ],
                    ),
                  ),
                )),
      ),
    );
  }
}

class _LiveVisualPeek extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onDismiss;
  final VoidCallback onView;

  const _LiveVisualPeek({
    required this.message,
    required this.onDismiss,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 280,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 20,
        opacity: 0.15,
        blur: 20,
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CupertinoIcons.sparkles,
                          size: 14, color: theme.primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Visual Shared',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(CupertinoIcons.xmark_circle_fill,
                      size: 20, color: theme.hintColor.withValues(alpha: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                width: double.infinity,
                color: isDark
                    ? AppColors.text.withValues(alpha: 0.26)
                    : Colors.grey[100],
                child: _buildPreviewContent(context),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(12),
                onPressed: onView,
                child: Text(
                  'Focus View',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    if (message.imageUrl != null) {
      return Image.network(
        message.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) =>
            const Center(child: Icon(Icons.broken_image)),
      );
    }
    if (message.quizDataJson != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.question_circle,
                size: 32, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              'Interactive Quiz',
              style:
                  GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Center(
      child: Text(
        'Tap to view content',
        style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey),
      ),
    );
  }
}

class _XpAwardCelebration extends StatefulWidget {
  final int amount;
  final String reason;

  const _XpAwardCelebration({required this.amount, required this.reason});

  @override
  State<_XpAwardCelebration> createState() => _XpAwardCelebrationState();
}

class _XpAwardCelebrationState extends State<_XpAwardCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              opacity: 0.1,
              blur: 20,
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
                width: 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.star_fill,
                        color: Colors.amber, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '+${widget.amount} XP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.reason,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white70
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
