// ignore_for_file: invalid_use_of_protected_member
part of '../chat_controller.dart';

// ===========================================================================
// Thread Management — loading, creating, deleting, renaming
// ===========================================================================

extension ChatControllerThread on ChatController {
  Future<void> loadThread(String threadId, {AiTutorHistoryProvider? historyProvider, String? userId}) async {
    _isLoadingMessages = true;
    _currentStreamingMessageId = null;
    _isTyping = false;
    _isVoiceMode = false;
    _messages.clear();
    _wsService.setThreadId(threadId);
    notify();

    try {
      final isar = await _isarService.db;
      
      // On web, isar is null, so fetch from backend API
      if (isar == null) {
        developer.log('Web platform detected - fetching from backend API', name: 'ChatController');
        
        // Get user ID for API call
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
        if (userId == 'guest') {
          developer.log('Guest user - no history available', name: 'ChatController');
          _isLoadingMessages = false;
          notify();
          return;
        }
        
        // Fetch messages from backend API
        try {
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/chat/$threadId'),
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
                quizDataJson: map['quiz_data'],
                flashcardDataJson: map['flashcard_data'],
                desmosDataJson: map['desmos_data'],
                mnemonicDataJson: map['mnemonic_data'],
                graphDataJson: map['graph_data'],
                reasoning: map['reasoning'],
                isKicdCertified: map['is_kicd_certified'] ?? false,
              );
            }).toList();
            
            _messages.addAll(messages);
            developer.log('✅ Loaded ${messages.length} messages from API', name: 'ChatController');
          } else {
            developer.log('⚠️ API returned ${response.statusCode} for thread $threadId', name: 'ChatController');
            if (!kIsWeb) {
              // Report non-200 responses to Crashlytics (native only)
              FirebaseCrashlytics.instance.log('Failed to load thread: HTTP ${response.statusCode}');
              FirebaseCrashlytics.instance.recordError(
                Exception('Thread load failed: ${response.statusCode}'),
                StackTrace.current,
                reason: 'API returned ${response.statusCode} for thread $threadId',
                fatal: false,
              );
            }
          }
        } catch (apiError, stackTrace) {
          developer.log('❌ Error fetching from API: $apiError', name: 'ChatController');
          if (!kIsWeb) {
            // Report API errors to Crashlytics (native only)
            FirebaseCrashlytics.instance.log('Thread load API error: $apiError');
            FirebaseCrashlytics.instance.recordError(
              apiError,
              stackTrace,
              reason: 'Failed to fetch thread $threadId from API',
              fatal: false,
            );
          }
        }
        
        _currentTitle = _titleCache[threadId] ?? 'Chat';
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
        developer.log('Thread $threadId is empty locally. Syncing on-demand...', name: 'ChatController');
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
          _messages[_messages.length - 1] = last.copyWith(isComplete: true, isTemporary: false);
        }
      }
      _currentTitle = _titleCache[threadId] ?? 'Chat';
      _isLoadingMessages = false;
      notify();
      scrollToBottom();
    } catch (e) {
      developer.log('Error loading thread: $e', name: 'ChatController');
      _isLoadingMessages = false;
      notify();
    }
  }

  Future<void> startNewChat({bool closeDrawer = true}) async {
    if (closeDrawer && scaffoldKey.currentState?.isDrawerOpen == true) {
      scaffoldKey.currentState?.closeDrawer();
    }
    
    _messages.clear();
    _currentStreamingMessageId = null;
    _isTyping = false;
    _isVoiceMode = false;
    _currentTitle = 'New Chat';
    
    final newThreadId = const Uuid().v4();
    _wsService.setThreadId(newThreadId);
    
    notify();
  }

  Future<void> refreshChat() async {
    if (_wsService.threadId.isNotEmpty) {
      await loadThread(_wsService.threadId);
    }
  }

  Future<void> confirmDeleteThread(BuildContext context, String threadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This will permanently remove this conversation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _isarService.deleteThread(threadId);
      if (threadId == _wsService.threadId) {
        startNewChat(closeDrawer: false);
      }
      fetchThreadList();
    }
  }

  Future<void> showRenameDialog(BuildContext context, String threadId, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Enter new title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Rename')),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      _titleCache[threadId] = newTitle;
      if (threadId == _wsService.threadId) {
        _currentTitle = newTitle;
        notify();
      }
      fetchThreadList();
    }
  }

  Future<void> deleteAllChatHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Chats?'),
        content: const Text('This will delete all your conversation history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final isar = await _isarService.db;
      if (isar != null) {
        await isar.writeTxn(() => isar.chatMessages.clear());
      }
      startNewChat(closeDrawer: false);
      fetchThreadList();
    }
  }

  Future<void> fetchThreadList({bool silent = false}) async {
    if (!silent) _isLoadingHistory = true;
    notify();
    // Logic to fetch threads
    _isLoadingHistory = false;
    notify();
  }
}
