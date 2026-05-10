// ignore_for_file: invalid_use_of_protected_member
part of '../chat_controller.dart';

// ===========================================================================
// Thread Management — loading, creating, deleting, renaming
// ===========================================================================

extension ChatControllerThread on ChatController {
  Future<void> loadThread(String threadId,
      {AiTutorHistoryProvider? historyProvider, String? userId}) async {
    _isLoadingMessages = true;
    _currentStreamingMessageId = null;
    _isTyping = false;
    _isVoiceMode = false;
    _messages.clear();
    _cancelResponseTimeout();
    _wsService?.setThreadId(threadId);
    notify();

    try {
      final isar = await _isarService.db;

      // On web, isar is null, so fetch from backend API
      if (isar == null) {
        developer.log('Web platform detected - fetching from backend API',
            name: 'ChatController');

        // Get user ID for API call - MUST be a verified Firebase user
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          developer.log('No authenticated user - no history available',
              name: 'ChatController');
          _isLoadingMessages = false;
          notify();
          return;
        }

        // Fetch messages from backend API
        try {
          final response = await http.get(
            Uri.parse('${AppConfig.backendBaseUrl}/api/chat/$threadId'),
            headers: await AuthHeaders.getHeaders(),
          );

          if (response.statusCode == 200) {
            final List<dynamic> data = jsonDecode(response.body);
            final messages = data.map((m) {
              final map = m as Map<String, dynamic>;
              return ChatMessage(
                id: map['id']?.toString() ?? '',
                text: map['content']?.toString() ?? '',
                isUser: map['role'] == 'user',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                  map['timestamp'] is int ? map['timestamp'] : 0,
                ),
                imageUrl: map['image_url'],
                audioUrl: map['audio_url'],
                feedback: map['feedback'],
                threadId: threadId,
                status: MessageStatus.sent,
                isTemporary: false,
                isComplete: true,
                quizDataJson: map['quiz_data'] is Map ? jsonEncode(map['quiz_data']) : map['quiz_data'],
                flashcardDataJson: map['flashcards'] is Map ? jsonEncode(map['flashcards']) : map['flashcards'],
                mnemonicDataJson: map['mnemonics'] is Map ? jsonEncode(map['mnemonics']) : map['mnemonics'],
                punnettDataJson: map['punnett_data'] is Map ? jsonEncode(map['punnett_data']) : map['punnett_data'],
                mathSteps: map['math_steps'] is List ? List<String>.from(map['math_steps']) : null,
                mathAnswer: map['math_answer'],
                uiWidgets: (map['ui_widgets'] ?? map['uiWidgets'] as List?)
                    ?.map(
                        (w) => UiWidgetData.fromJson(w as Map<String, dynamic>))
                    .toList(),
                uiWidgetsJson: map['ui_widgets_json'] is List
                    ? List<String>.from(map['ui_widgets_json'])
                    : (map['uiWidgetsJson'] is List
                        ? List<String>.from(map['uiWidgetsJson'])
                        : null),
                reasoning: map['reasoning'],
                fileId: map['file_id'],
                fileName: map['file_name'],
                fileType: map['file_type'],
                attachments: (map['attachments'] as List?)
                    ?.map((a) => ChatAttachmentMetadata.fromJson(
                        a as Map<String, dynamic>))
                    .toList(),
                videos: (map['videos'] as List?)
                    ?.map(
                        (v) => VideoResult.fromJson(v as Map<String, dynamic>))
                    .toList(),
                sources: (map['sources'] as List?)
                    ?.map((s) =>
                        SourceMetadata.fromJson(s as Map<String, dynamic>))
                    .toList(),
                isKicdCertified:
                    map['is_kicd_certified'] ?? map['isKicdCertified'] ?? false,
              );
            }).toList();

            _messages.addAll(messages);
            developer.log('✅ Loaded ${messages.length} messages from API',
                name: 'ChatController');
          } else {
            developer.log(
                '⚠️ API returned ${response.statusCode} for thread $threadId',
                name: 'ChatController');
            if (!kIsWeb) {
              // Report non-200 responses to Crashlytics (native only)
              FirebaseCrashlytics.instance
                  .log('Failed to load thread: HTTP ${response.statusCode}');
              FirebaseCrashlytics.instance.recordError(
                Exception('Thread load failed: ${response.statusCode}'),
                StackTrace.current,
                reason:
                    'API returned ${response.statusCode} for thread $threadId',
                fatal: false,
              );
            }
          }
        } catch (apiError, stackTrace) {
          developer.log('❌ Error fetching from API: $apiError',
              name: 'ChatController');
          if (!kIsWeb) {
            // Report API errors to Crashlytics (native only)
            FirebaseCrashlytics.instance
                .log('Thread load API error: $apiError');
            FirebaseCrashlytics.instance.recordError(
              apiError,
              stackTrace,
              reason: 'Failed to fetch thread $threadId from API',
              fatal: false,
            );
          }
        }

        // Title lookup
        String? foundTitle = _titleCache[threadId];
        if (foundTitle == null && _historyProvider != null) {
          final thread = _historyProvider!.threads.firstWhere(
            (t) => t['thread_id'] == threadId,
            orElse: () => {},
          );
          foundTitle = thread['title']?.toString();
        }

        _currentTitle = foundTitle ?? 'Chat';
        _isLoadingMessages = false;
        notify();
        scrollToBottom();
        return;
      }

      // Native platform - use Isar
      final history = await isar.chatMessages
          .filter()
          .threadIdEqualTo(threadId)
          .sortByTimestamp()
          .findAll();

      if (history.isEmpty && historyProvider != null && userId != null) {
        developer.log('Thread $threadId is empty locally. Syncing on-demand...',
            name: 'ChatController');
        await historyProvider.syncThreadMessages(threadId, userId);

        // Re-fetch after sync
        final syncedHistory = await isar.chatMessages
            .filter()
            .threadIdEqualTo(threadId)
            .sortByTimestamp()
            .findAll();
        _messages.addAll(syncedHistory);
      } else {
        _messages.addAll(history);
      }
      if (_messages.isNotEmpty) {
        final last = _messages.last;
        if (!last.isComplete) {
          _messages[_messages.length - 1] =
              last.copyWith(isComplete: true, isTemporary: false);
        }
      }

      // Title lookup
      String? foundTitle = _titleCache[threadId];
      if (foundTitle == null && _historyProvider != null) {
        final thread = _historyProvider!.threads.firstWhere(
          (t) => t['thread_id'] == threadId,
          orElse: () => {},
        );
        foundTitle = thread['title']?.toString();
      }

      _currentTitle = foundTitle ?? 'Chat';
      _isLoadingMessages = false;
      notify();
      scrollToBottom();
    } catch (e) {
      developer.log('Error loading thread: $e', name: 'ChatController');
      _isLoadingMessages = false;
      notify();
    }
  }

  Future<void> _clearAllMessagingState() async {
    _messages.clear();
    _currentStreamingMessageId = null;
    _currentAiStatus = null;
    _isTyping = false;
    _isUploading = false;
    _isVoiceMode = false;
    _currentTitle = 'New Chat';
    _textController.clear();
    _pendingAttachments.clear();
    _messageQueue.clear();
    _pendingChunks.clear();
    _tokenQueue.clear();
    _replyTo = null;
    _userStoppedGeneration = true;
    _firstTokenHapticFired = false;
    _chunkUpdateTimer?.cancel();
    _typingTimer?.cancel();
    _transcriptionDebounce?.cancel();
    _cancelResponseTimeout();
  }

  Future<void> startNewChat({bool closeDrawer = true}) async {
    if (closeDrawer && scaffoldKey.currentState?.isDrawerOpen == true) {
      scaffoldKey.currentState?.closeDrawer();
    }

    await _clearAllMessagingState();

    final newThreadId = const Uuid().v4();
    _wsService?.setThreadId(newThreadId);

    notify();
  }

  Future<void> refreshChat() async {
    if ((_wsService?.threadId ?? '').isNotEmpty) {
      await loadThread(_wsService?.threadId ?? '');
    }
  }

  Future<void> confirmDeleteThread(
      BuildContext context, String threadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This will permanently remove this conversation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      // Delete from backend if possible
      if (userId != 'guest' && _historyProvider != null) {
        await _historyProvider!.deleteThread(userId, threadId);
      } else {
        // Fallback or guest mode - at least clear local
        await _isarService.deleteThread(threadId);
      }

      if (threadId == (_wsService?.threadId ?? '')) {
        startNewChat(closeDrawer: false);
      }
      fetchThreadList();
    }
  }

  Future<void> showRenameDialog(
      BuildContext context, String threadId, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter new title')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty) return;

    // 1. Update local cache and current title immediately for instant UI feedback
    _titleCache[threadId] = newTitle;
    if (threadId == (_wsService?.threadId ?? '')) {
      _currentTitle = newTitle;
    }

    // 2. Update the history provider's in-memory list so the sidebar reflects it
    _historyProvider?.renameThread(threadId, newTitle);
    notify();

    // 3. Persist to backend
    try {
      final headers = await AuthHeaders.getHeaders(
          existingHeaders: {'Content-Type': 'application/json'});
      await http.patch(
        Uri.parse('${AppConfig.backendBaseUrl}/api/threads/$threadId'),
        headers: headers,
        body: jsonEncode({'title': newTitle}),
      );
    } catch (e) {
      developer.log('Rename thread backend error (non-fatal): $e',
          name: 'ChatController');
    }

    // 4. Persist to local Isar (native only)
    if (!kIsWeb) {
      try {
        final isar = await _isarService.db;
        if (isar != null) {
          // Update the title on all messages in this thread so it survives a reload
          await isar.writeTxn(() async {
            // ChatMessage doesn't store a thread title — the title lives in
            // the provider list. The provider.renameThread() call above is
            // the source of truth for the sidebar.
          });
        }
      } catch (e) {
        developer.log('Rename thread Isar error (non-fatal): $e',
            name: 'ChatController');
      }
    }
  }

  Future<void> deleteAllChatHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Chats?'),
        content: const Text(
            'This will delete all your conversation history. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      // Delete from backend if possible
      if (userId != 'guest' && _historyProvider != null) {
        await _historyProvider!.deleteAllThreads(userId);
      } else {
        // Fallback or guest mode - clear local
        final isar = await _isarService.db;
        if (isar != null) {
          await isar.writeTxn(() => isar.chatMessages.clear());
        }
      }

      startNewChat(closeDrawer: false);
      fetchThreadList();
    }
  }

  Future<void> fetchThreadList({bool silent = false}) async {
    if (!silent) _isLoadingHistory = true;
    notify();

    // Sync title cache with history provider
    if (_historyProvider != null) {
      for (var thread in _historyProvider!.threads) {
        final tid = thread['thread_id']?.toString();
        final title = thread['title']?.toString();
        if (tid != null && title != null) {
          _titleCache[tid] = title;
        }
      }
    }

    _isLoadingHistory = false;
    notify();
  }
}
