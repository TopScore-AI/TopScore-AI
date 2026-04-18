// ignore_for_file: invalid_use_of_protected_member
part of '../chat_controller.dart';

// ===========================================================================
// Messaging — send, WebSocket handling, streaming, bookmarks, edit/resend
// ===========================================================================

extension ChatControllerMessaging on ChatController {
  ChatMessage? handleIncomingMessage(dynamic dataRaw) {
    if (dataRaw is! Map<String, dynamic>) return null;
    final Map<String, dynamic> data = dataRaw;

    final type = data['type'];
    final messageId = data['id'];
    if (type == null) return null;

    if (_userStoppedGeneration &&
        (type == 'chunk' || type == 'reasoning_chunk')) {
      return null;
    }

    switch (type) {
      case 'status':
        final rawStatus = data['status'] ?? data['message'];
        if (rawStatus != null) {
          final s = rawStatus.toString().toLowerCase();
          if (s.contains('analyzing')) {
            _currentAiStatus = 'Analyzing...';
          } else if (s.contains('generating')) {
            _currentAiStatus = 'Generating...';
          } else if (s.contains('thinking')) {
            _currentAiStatus = 'Thinking...';
          } else {
            _currentAiStatus = 'Thinking...'; // Default fallback
          }
          notify();
        }
        return null; // Ensure we stop processing and don't fall into any other logic

      case 'tool_call':
        // Tool calls are for internal logic (e.g. backend functions) and should NEVER render.
        developer.log('AI Tutor received tool_call: ${data['method'] ?? 'unknown'}', name: 'ChatController');
        return null;

      case 'response_start':
        _isTyping = true;
        _userStoppedGeneration = false;
        notify();
        if (messageId != null) {
          // --- OPTIMISTIC UI: Replace or Adopt Thinking Placeholder ---
          final thinkingIdx = _messages.indexWhere((m) => m.isThinking);
          if (thinkingIdx != -1) {
             _messages.removeAt(thinkingIdx);
          }
          
          _currentStreamingMessageId = messageId;
          if (_messages.isNotEmpty && (_currentTitle == 'New Chat' || _currentTitle == 'New Chat...')) {
            final firstUserMsg = _messages.firstWhere((m) => m.isUser,
                orElse: () => _messages.first);
            final raw = stripMarkdown(firstUserMsg.text);
            final title = raw.length > 40 ? '${raw.substring(0, 37)}...' : raw;
            if (title.isNotEmpty) {
              _titleCache[_wsService.threadId] = title;
              _currentTitle = title;
              notify();
            }
          }
          if (!_messages.any((m) => m.id == messageId)) {
            _messages.add(ChatMessage(
              id: messageId,
              text: '',
              isUser: false,
              timestamp: DateTime.now(),
              isTemporary: true,
              isComplete: false,
              threadId: _wsService.threadId,
            ));
            notify();
            scrollToBottom();
          }
        }
        break;

      case 'title_updated':
        final updatedThreadId = data['thread_id'] ?? _wsService.threadId;
        final rawTitle = data['title'];
        if (rawTitle != null && rawTitle.toString().isNotEmpty) {
          final cleanTitle = stripMarkdown(rawTitle.toString());
          _titleCache[updatedThreadId] = cleanTitle;
          if (updatedThreadId == _wsService.threadId) {
            _currentTitle = cleanTitle;
          }
          _historyProvider?.addThread({
            'thread_id': updatedThreadId,
            'title': cleanTitle,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'model': _selectedModelKey,
          });
          notify();
        }
        break;

      case 'chunk':
        final chunkContent = data['content'] as String? ?? '';
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null) {
          // Clear thinking state if we start receiving real content
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1 && _messages[idx].isThinking) {
             _messages[idx] = _messages[idx].copyWith(isThinking: false);
          }
          // --- FALLBACK PARSER: Extract Desmos config from text stream ---
          if (chunkContent.contains('[INTERACTIVE_GRAPH_CONFIG]')) {
            final regex = RegExp(r'\[INTERACTIVE_GRAPH_CONFIG\]\((.*?)\)');
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final configJson = match.group(1);
              if (configJson != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1 && _messages[idx].desmosDataJson == null) {
                  developer.log('Fallback parser found Desmos config for $targetId', name: 'ChatController');
                  _messages[idx] =
                      _messages[idx].copyWith(desmosDataJson: configJson);
                  notify();
                }
              }
            }
          }

          // --- FALLBACK PARSER: Extract Quiz data from text stream ---
          if (chunkContent.contains('[QUIZ_DATA]')) {
            final regex = RegExp(r'\[QUIZ_DATA\]\((.*?)\)');
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final configJson = match.group(1);
              if (configJson != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1 && _messages[idx].quizDataJson == null) {
                  developer.log('Fallback parser found Quiz data for $targetId', name: 'ChatController');
                  _messages[idx] =
                      _messages[idx].copyWith(quizDataJson: configJson);
                  notify();
                }
              }
            }
          }

          // --- FALLBACK PARSER: Extract Flashcards data from text stream ---
          if (chunkContent.contains('[FLASHCARDS_DATA]')) {
            final regex = RegExp(r'\[FLASHCARDS_DATA\]\((.*?)\)');
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final configJson = match.group(1);
              if (configJson != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1 && _messages[idx].flashcardDataJson == null) {
                  developer.log('Fallback parser found Flashcards for $targetId', name: 'ChatController');
                  _messages[idx] =
                      _messages[idx].copyWith(flashcardDataJson: configJson);
                  notify();
                }
              }
            }
          }

          // --- FALLBACK PARSER: Extract Mnemonic data from text stream ---
          if (chunkContent.contains('[MNEMONIC_DATA]')) {
            final regex = RegExp(r'\[MNEMONIC_DATA\]\((.*?)\)');
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final configJson = match.group(1);
              if (configJson != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1 && _messages[idx].mnemonicDataJson == null) {
                  developer.log('Fallback parser found Mnemonic data for $targetId', name: 'ChatController');
                  _messages[idx] =
                      _messages[idx].copyWith(mnemonicDataJson: configJson);
                  notify();
                }
              }
            }
          }

          // --- FALLBACK PARSER: Extract Graph data from text stream ---
          if (chunkContent.contains('[GRAPH_DATA]') || chunkContent.contains('[PLOT_DATA]')) {
            final regex = RegExp(r'\[(GRAPH_DATA|PLOT_DATA)\]\((.*?)\)');
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final configJson = match.group(2);
              if (configJson != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1 && _messages[idx].graphDataJson == null) {
                  developer.log('Fallback parser found Graph data for $targetId', name: 'ChatController');
                  _messages[idx] =
                      _messages[idx].copyWith(graphDataJson: configJson);
                  notify();
                }
              }
            }
          }
          // --- FALLBACK PARSER: Extract Image data from text stream (! `url`) ---
          if (chunkContent.contains('! `')) {
            final regex = RegExp(r'!\s*`([^`]+)`');
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final imageUrl = match.group(1);
              if (imageUrl != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1 && _messages[idx].imageUrl == null) {
                  developer.log('Fallback parser found Image URL for $targetId', name: 'ChatController');
                  _messages[idx] = _messages[idx].copyWith(imageUrl: imageUrl);
                  notify();
                }
              }
            }
          }

          // --- FALLBACK PARSER: Extract Punnett data from text stream ---
          if (chunkContent.contains('[PUNNETT_SQUARE]')) {
            final regex = RegExp(r'\[PUNNETT_SQUARE\]\((.*?)\)');
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final configJson = match.group(1);
              if (configJson != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1 && _messages[idx].punnettDataJson == null) {
                  developer.log('Fallback parser found Punnett data for $targetId', name: 'ChatController');
                  _messages[idx] =
                      _messages[idx].copyWith(punnettDataJson: configJson);
                  notify();
                }
              }
            }
          }
          
          _pendingChunks[targetId] =
              (_pendingChunks[targetId] ?? '') + chunkContent;
          if (_chunkUpdateTimer?.isActive ?? false) return null;
          _chunkUpdateTimer = Timer(const Duration(milliseconds: 50), () {
            final snapshot = Map<String, String>.from(_pendingChunks);
            _pendingChunks.clear();
            for (final entry in snapshot.entries) {
              final cId = entry.key;
              final idx =
                  _messages.indexWhere((m) => m.id == cId && m.isTemporary);
              if (idx != -1) {
                final newRawText = _messages[idx].text + entry.value;
                _messages[idx] = _messages[idx]
                    .copyWith(text: postFormatAIResponse(newRawText));
              } else {
                _messages.add(ChatMessage(
                  id: cId,
                  text: postFormatAIResponse(entry.value),
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true,
                  isComplete: false,
                  threadId: _wsService.threadId,
                ));
                _currentStreamingMessageId = cId;
              }
            }
            notify();
            scrollToBottom();
          });
        }
        break;

      case 'reasoning_chunk':
        final rContent = data['content'] as String? ?? '';
        final rTargetId = messageId ?? _currentStreamingMessageId;
        if (rTargetId != null) {
          final idx = _messages.indexWhere((m) => m.id == rTargetId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(
              reasoning: (_messages[idx].reasoning ?? '') + rContent,
              isTemporary: true,
            );
          } else {
            _messages.add(ChatMessage(
              id: rTargetId,
              text: '',
              reasoning: rContent,
              isUser: false,
              timestamp: DateTime.now(),
              isTemporary: true,
              isComplete: false,
              threadId: _wsService.threadId,
            ));
            _currentStreamingMessageId = rTargetId;
          }
          notify();
          scrollToBottom();
        }
        break;

      case 'done':
      case 'complete':
      case 'end':
        _chunkUpdateTimer?.cancel();
        if (_pendingChunks.isNotEmpty) {
          final flush = Map<String, String>.from(_pendingChunks);
          _pendingChunks.clear();
          for (final entry in flush.entries) {
            final idx =
                _messages.indexWhere((m) => m.id == entry.key && m.isTemporary);
            if (idx != -1) {
              final newRawText = _messages[idx].text + entry.value;
              _messages[idx] = _messages[idx]
                  .copyWith(text: postFormatAIResponse(newRawText));
            }
          }
          notify();
        }
        final doneId = messageId ?? _currentStreamingMessageId;
        if (doneId != null) {
          final finalContentRaw = data['content'] as String?;
          final finalContent = finalContentRaw != null ? postFormatAIResponse(finalContentRaw) : null;
          final idx = _messages.indexWhere((m) => m.id == doneId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(
              text: finalContent ?? _messages[idx].text,
              isComplete: true,
              isTemporary: false,
              status: MessageStatus.sent,
            );
          }
          notify();
          final inMemoryMsg = _messages.firstWhere((m) => m.id == doneId,
              orElse: () => ChatMessage(
                    id: doneId,
                    text: finalContent ?? '',
                    isUser: false,
                    timestamp: DateTime.now(),
                    threadId: _wsService.threadId,
                  ));
          _isarService.saveMessage(inMemoryMsg.copyWith(
            text: postFormatAIResponse(inMemoryMsg.text),
            isComplete: true,
            isTemporary: false,
            status: MessageStatus.sent,
          ));
        }
        finalizeTurn(null);
        break;

      case 'message':
        final contentRaw = data['content'] as String? ?? '';
        final content = postFormatAIResponse(contentRaw);
        if (content.isNotEmpty && messageId != null) {
          final alreadyExists = _messages.any((m) =>
              m.id == messageId ||
              (!m.isUser && m.text.trim() == content.trim()));
          if (alreadyExists) break;
          final idx = _messages.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            _messages[idx] = _messages[idx]
                .copyWith(text: content, isComplete: true, isTemporary: false);
          } else {
            _messages.add(ChatMessage(
              id: messageId,
              text: content,
              isUser: false,
              timestamp: DateTime.now(),
              isTemporary: false,
              isComplete: true,
            ));
          }
          notify();
        }
        finalizeTurn(null);
        return _messages.firstWhere((m) => m.id == messageId, orElse: () => _messages.last);
      case 'error':
        final errorMsg = data['message'] ?? 'Unknown error';
        if (!_messages.any((m) => m.text.contains(errorMsg))) {
          addSystemMessage('Error: $errorMsg');
        }
        finalizeTurn(null);
        return null;
      case 'suggestions':
        if (data['suggestions'] is List) {
          try {
            final parsed = (data['suggestions'] as List).map((item) {
              final map = Map<String, dynamic>.from(item);
              return {
                'emoji': map['emoji']?.toString() ?? '✨',
                'title': map['title']?.toString() ?? '',
                'subtitle': map['subtitle']?.toString() ?? '',
              };
            }).toList();
            _dynamicSuggestions = parsed;
            notify();
          } catch (e) {
            developer.log('Error parsing suggestions: $e');
          }
        }
        break;

      case 'quiz':
        final quizData = data['quiz_data'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null && quizData != null) {
          final quizJson = quizData is String ? quizData : json.encode(quizData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(quizDataJson: quizJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
            AnalyticsService.instance.logEvent('quiz_rendered', {'topic': 'auto'});
          }
        }
        break;

      case 'flashcards':
        final flashcardData = data['flashcard_data'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null && flashcardData != null) {
          final flashcardJson =
              flashcardData is String ? flashcardData : json.encode(flashcardData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] =
                _messages[idx].copyWith(flashcardDataJson: flashcardJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
          }
        }
        break;
      
      case 'table':
        final tableContent = data['content'] as String? ?? '';
        final tId = messageId ?? _currentStreamingMessageId;
        if (tId != null && tableContent.isNotEmpty) {
          final idx = _messages.indexWhere((m) => m.id == tId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(
              text: _messages[idx].text + tableContent,
              isTemporary: true,
            );
          } else {
            _messages.add(ChatMessage(
              id: tId,
              text: tableContent,
              isUser: false,
              timestamp: DateTime.now(),
              isTemporary: true,
              isComplete: false,
              threadId: _wsService.threadId,
            ));
            _currentStreamingMessageId = tId;
          }
          notify();
          scrollToBottom();
        }
        break;

      case 'interactive_graph':
        final configData = data['config'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        developer.log('Received interactive_graph event. TargetId: $targetId', name: 'ChatController');
        if (targetId != null && configData != null) {
          final configJson =
              configData is String ? configData : json.encode(configData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(desmosDataJson: configJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
            AnalyticsService.instance.logEvent('desmos_graph_rendered', {'type': 'auto'});
          }
        }
        break;

      case 'mnemonic':
        final mnemonicData = data['mnemonic_data'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null && mnemonicData != null) {
          final mnemonicJson = mnemonicData is String ? mnemonicData : json.encode(mnemonicData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] =
                _messages[idx].copyWith(mnemonicDataJson: mnemonicJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
            AnalyticsService.instance.logEvent('mnemonic_generated', {'topic': 'auto'});
          }
        }
        break;

      case 'is_kicd_certified':
        final targetId = messageId ?? _currentStreamingMessageId;
        final isCertified = data['value'] as bool? ?? false;
        if (targetId != null) {
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(isKicdCertified: isCertified);
            notify();
            _isarService.saveMessage(_messages[idx]);
          }
        }
        break;

      case 'punnett_square':
        final pData = data['punnett_data'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null && pData != null) {
          final pJson = pData is String ? pData : json.encode(pData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(punnettDataJson: pJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
          }
        }
        break;

      case 'graph':
      case 'plot':
      case 'chart':
      case 'artifact':
        final artifactType = data['artifact_type'] ?? type;
        final targetId = messageId ?? _currentStreamingMessageId;
        
        if (artifactType == 'graph' || artifactType == 'plot' || artifactType == 'chart') {
          final graphData = json.encode(data);
          
          if (targetId != null) {
            final idx = _messages.indexWhere((m) => m.id == targetId);
            if (idx != -1) {
              _messages[idx] = _messages[idx].copyWith(graphDataJson: graphData);
              notify();
              _isarService.saveMessage(_messages[idx]);
              AnalyticsService.instance.logEvent('graph_rendered', {'type': artifactType});
            }
          } else if (messageId != null) {
            // Standalone graph message
            final alreadyExists = _messages.any((m) => m.id == messageId);
            if (!alreadyExists) {
              _messages.add(ChatMessage(
                id: messageId,
                text: '',
                isUser: false,
                timestamp: DateTime.now(),
                graphDataJson: graphData,
                isTemporary: false,
                isComplete: true,
                threadId: _wsService.threadId,
              ));
              notify();
              _isarService.saveMessage(_messages.last);
              AnalyticsService.instance.logEvent('standalone_graph_rendered', {'type': artifactType});
            }
          }
        }
        break;
    }
    return null;
  }

  void handleSources(Map<String, dynamic> data) {
    final sourcesData = data['sources'];
    if (sourcesData == null || sourcesData is! List) return;
    final sourcesList =
        sourcesData.map((s) => SourceMetadata.fromJson(s)).toList();
    final targetId = _currentStreamingMessageId;
    if (targetId != null) {
      final idx = _messages.indexWhere((m) => m.id == targetId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(sources: sourcesList);
      }
      notify();
    }
    _isarService.db.then((isar) async {
      if (isar == null) return;
      if (targetId != null) {
        final results =
            await isar.chatMessages.filter().idEqualTo(targetId).findAll();
        final existing = results.isEmpty ? null : results.first;
        if (existing != null) {
          _isarService.saveMessage(existing.copyWith(sources: sourcesList));
        }
      }
    });
  }

  void finalizeTurn(BuildContext? context) {
    _isTyping = false;
    _isUploading = false;
    _currentStreamingMessageId = null;
    _currentAiStatus = null;
    notify();

    // Award XP for each completed AI tutor exchange
    if (context != null) {
      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.userModel?.uid;
      if (uid != null) {

        authProvider.incrementGuestMessageCount().then((_) {
          if (authProvider.isGuestLimitReached && !_hasShownGuestPrompt) {
            _hasShownGuestPrompt = true;
            // No longer incrementing here - moved to sendUserMessage
          }
        });
      }
    }

    if (_messageQueue.isNotEmpty && context != null) {
      final next = _messageQueue.removeAt(0);
      final authProvider = context.read<AuthProvider>();
      final settings = context.read<SettingsProvider>();
      _isTyping = true;
      notify();
      _wsService.sendMessage(
        message: next['message'] ?? '',
        userId: authProvider.isGuestMode ? authProvider.deviceId : (authProvider.userModel?.uid ?? 'anon'),
        fileUrls: next['fileUrls'] != null ? List<String>.from(next['fileUrls']) : null,
        fileType: next['fileType'] ?? 'image',
        modelPreference: _selectedModelKey,
        dataSaver: settings.isLiteMode,
      );
    }
  }

  void addSystemMessage(String text) {
    final msg = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      threadId: _wsService.threadId,
    );
    _isarService.saveMessage(msg);
    _messages.add(msg);
    scrollToBottom();
  }

  void stopGeneration() {
    _typingTimer?.cancel();
    _chunkUpdateTimer?.cancel();
    _tokenQueue.clear();
    _pendingChunks.clear();
    try {
      if (_wsService.isConnected) {
        _wsService.sendRaw({'type': 'stop', 'thread_id': _wsService.threadId});
      }
    } catch (_) {}

    final stoppingId = _currentStreamingMessageId;
    if (stoppingId != null) {
      final idx = _messages.indexWhere((m) => m.id == stoppingId);
      if (idx != -1) {
        // Remove partial AI message
        final aiMsg = _messages.removeAt(idx);
        _isarService.deleteMessage(aiMsg.id);

        // Revert preceding user message
        if (idx > 0) {
          final userMsg = _messages[idx - 1];
          if (userMsg.isUser) {
            _messages.removeAt(idx - 1);
            _isarService.deleteMessage(userMsg.id);
            
            _textController.text = userMsg.text;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );

            if (userMsg.attachments != null && userMsg.attachments!.isNotEmpty) {
              _pendingAttachments.clear();
              for (final att in userMsg.attachments!) {
                _pendingAttachments.add(PendingAttachment(
                  id: att.id ?? generateRandomId(),
                  name: att.name ?? 'File',
                  type: att.type ?? 'image',
                  url: att.url,
                  isUploaded: true,
                ));
              }
              _isUploading = false;
            } else if (userMsg.imageUrl != null) {
              _pendingAttachments.clear();
              _pendingAttachments.add(PendingAttachment(
                id: generateRandomId(),
                name: 'image.png',
                type: 'image',
                url: userMsg.imageUrl,
                isUploaded: true,
              ));
              _isUploading = false;
            }
          }
        }
      }
    } else if (_isTyping) {
      // Revert last user message if still "Thinking" (no streaming ID yet)
      if (_messages.isNotEmpty && _messages.last.isUser) {
        final userMsg = _messages.removeLast();
        _isarService.deleteMessage(userMsg.id);
        
        _textController.text = userMsg.text;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );

        if (userMsg.attachments != null && userMsg.attachments!.isNotEmpty) {
          _pendingAttachments.clear();
          for (final att in userMsg.attachments!) {
            _pendingAttachments.add(PendingAttachment(
              id: att.id ?? generateRandomId(),
              name: att.name ?? 'File',
              type: att.type ?? 'image',
              url: att.url,
              isUploaded: true,
            ));
          }
          _isUploading = false;
        } else if (userMsg.imageUrl != null) {
          // Compatibility for old messages
          _pendingAttachments.clear();
          _pendingAttachments.add(PendingAttachment(
            id: generateRandomId(),
            name: 'image.png',
            type: 'image',
            url: userMsg.imageUrl,
            isUploaded: true,
          ));
          _isUploading = false;
        }
      }
    }

    _isTyping = false;
    _currentStreamingMessageId = null;
    _userStoppedGeneration = true;
    notify();
  }

  Future<void> sendUserMessage(BuildContext context, {String? text, List<ChatAttachmentMetadata>? attachments, String? messageId}) async {
    final authProvider = context.read<AuthProvider>();

    // --- OFFLINE GUARD: Block sending when not connected ---
    if (!isOnline) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(CupertinoIcons.wifi_slash, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text("You're offline. Reconnect to send.")),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // --- GUEST LIMIT: Per-thread count enforcement ---
    if (authProvider.isGuestMode) {
      final userMessageCount = _messages.where((m) => m.isUser).length;
      if (userMessageCount >= 5) {
        authProvider.exitGuestMode();
        context.go('/login');
        return;
      }
    }

    if (!authProvider.canSendMessage) {
      if (authProvider.isGuestMode) {
        authProvider.exitGuestMode();
        context.go('/login');
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limit Reached'),
            content: const Text(
                'You\'ve used your 5 free messages for this 6-hour window. Upgrade to Pro for unlimited chats.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'))
            ],
          ),
        );
      }
      return;
    }

    String messageText = text ?? _textController.text;
    final List<String> urlsToExtra = [];
    final List<ChatAttachmentMetadata> attachmentsMetadata = attachments ?? [];

    if (attachments == null) {
      // Collect from pending
      for (var att in _pendingAttachments) {
        if (att.url != null) {
          urlsToExtra.add(att.url!);
          attachmentsMetadata.add(ChatAttachmentMetadata(
            id: att.id,
            url: att.url,
            name: att.name,
            type: att.type,
          ));
        }
      }
    } else {
      for (var att in attachments) {
        if (att.url != null) urlsToExtra.add(att.url!);
      }
    }

    if (messageText.trim().isEmpty && urlsToExtra.isEmpty) {
      return;
    }

    _userStoppedGeneration = false;
    final pendingId = messageId ?? 'pending-${const Uuid().v4()}';
    final isBusy = _isTyping || _currentStreamingMessageId != null;

    final pendingMessage = ChatMessage(
      id: pendingId,
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
      imageUrl: urlsToExtra.isNotEmpty ? urlsToExtra.first : null,
      attachments: attachmentsMetadata.isNotEmpty ? attachmentsMetadata : null,
      replyToId: _replyTo?.id,
      replyToText: _replyTo?.text,
      status: MessageStatus.pending,
      threadId: _wsService.threadId,
    );

    _isarService.saveMessage(pendingMessage);

    _isTyping = true;
    
    // If we're updating/regenerating, don't add a new message to the list
    final existingIdx = _messages.indexWhere((m) => m.id == pendingId);
    if (existingIdx != -1) {
      _messages[existingIdx] = pendingMessage;
    } else {
      _messages.add(pendingMessage);
    }
    
    // --- OPTIMISTIC UI: Add Thinking AI Placeholder ---
    final thinkingAiId = 'ai-placeholder-${const Uuid().v4()}';
    final thinkingAiMessage = ChatMessage(
      id: thinkingAiId,
      text: '',
      isUser: false,
      timestamp: DateTime.now().add(const Duration(milliseconds: 1)),
      isThinking: true,
      isTemporary: true,
      isComplete: false,
      threadId: _wsService.threadId,
    );
    _messages.add(thinkingAiMessage);
    _currentStreamingMessageId = thinkingAiId; 
    _textController.clear();
    _replyTo = null;
    clearPendingAttachment();
    notify();
    scrollToBottom();

    // --- OPTIMISTIC UI: Update history provider if first message ---
    if (_messages.length == 2 && _historyProvider != null) {
      final historyTitle = messageText.length > 50 
          ? '${messageText.substring(0, 47)}...' 
          : messageText;
          
      _historyProvider!.addThread({
        'thread_id': _wsService.threadId,
        'title': historyTitle,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'model': _selectedModelKey,
      });
    }

    if (_messages.length == 1) {
      AnalyticsService.instance.logEvent('ai_chat_initiated', {
        'thread_id': _wsService.threadId,
        'model': _selectedModelKey,
      });
    }

    try {
      if (authProvider.isGuestMode) {
        await authProvider.incrementGuestMessageCount();
      }
      await authProvider.incrementDailyMessage();

      if (isBusy) {
        _messageQueue.add({
          'message': messageText,
          'fileUrls': urlsToExtra,
          'fileType': attachmentsMetadata.isNotEmpty ? attachmentsMetadata.first.type : 'image',
          'pendingId': pendingId,
        });
        return;
      }

      if (!context.mounted) return;
      final settings = context.read<SettingsProvider>();
      _wsService.sendMessage(
        message: messageText,
        userId: authProvider.isGuestMode ? authProvider.deviceId : (authProvider.userModel?.uid ?? 'anon'),
        fileUrls: urlsToExtra,
        fileType: attachmentsMetadata.isNotEmpty ? attachmentsMetadata.first.type : 'image',
        modelPreference: _selectedModelKey,
        dataSaver: settings.isLiteMode,
        replyToId: pendingMessage.replyToId,
        replyToText: pendingMessage.replyToText,
      );

      final idx = _messages.indexWhere((m) => m.id == pendingId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sent);
        await _isarService.saveMessage(_messages[idx]);
      }
      notify();
    } catch (e) {
      developer.log('Send Error: $e');
      final idx = _messages.indexWhere((m) => m.id == pendingId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(status: MessageStatus.error);
      }
      // Clean up the AI thinking placeholder so the user doesn't see a hung
      // "thinking" bubble under a failed message.
      _messages.removeWhere((m) => m.isThinking && m.isTemporary);
      _currentStreamingMessageId = null;
      _isTyping = false;
      _currentAiStatus = null;
      notify();
      if (context.mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: const Text('Message failed to send. Tap the message to retry.'),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Retry sending a user message that previously failed (status == error).
  /// Restores it to pending and calls the send pipeline again with the same id.
  Future<void> retryFailedMessage(BuildContext context, ChatMessage message) async {
    if (!message.isUser) return;
    if (!isOnline) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Still offline — can't retry yet."),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx == -1) return;

    // Remove any trailing thinking/AI placeholder that may have been left behind
    final trailing = _messages.sublist(idx + 1);
    for (final m in trailing) {
      if (m.isTemporary || m.isThinking) {
        _isarService.deleteMessage(m.id).catchError((e) => developer.log('Isar Delete Error: $e'));
      }
    }
    _messages.removeRange(idx + 1, _messages.length);
    // Reset this one to pending
    _messages[idx] = _messages[idx].copyWith(status: MessageStatus.pending);
    _messages.removeAt(idx);
    notify();

    await sendUserMessage(
      context,
      text: message.text,
      attachments: message.attachments,
      messageId: message.id,
    );
  }

  void handleUserEdit(BuildContext context, ChatMessage message) {
    final ctrl = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Edit your query...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final edited = ctrl.text.trim();
              if (edited.isNotEmpty) {
                regenerateResponse(context, message, editedText: edited);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(100, 44),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> toggleBookmark(ChatMessage message) async {
    final newState = !message.isBookmarked;
    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(isBookmarked: newState);
      notify();
    }
  }

  Future<void> regenerateResponse(BuildContext context, ChatMessage message,
      {String? editedText}) async {
    final idx = _messages.indexOf(message);
    if (idx < 0) return;

    if (editedText != null) {
      // Delete old message and subsequent responses from persistence
      final toDelete = _messages.sublist(idx);
      for (final m in toDelete) {
         _isarService.deleteMessage(m.id).catchError((e) => developer.log('Isar Delete Error: $e'));
      }
      _messages.removeRange(idx, _messages.length);
      notify();
      await sendUserMessage(context, 
        text: editedText, 
        messageId: message.id,
        attachments: message.attachments,
      );
    } else {
      if (message.isUser) {
        // Regenerating from a user message — delete existing AI responses
        final toDelete = _messages.sublist(idx + 1);
        for (final m in toDelete) {
          _isarService.deleteMessage(m.id).catchError((e) => developer.log('Isar Delete Error: $e'));
        }
        _messages.removeRange(idx + 1, _messages.length);
        notify();
        await sendUserMessage(context, 
          text: message.text, 
          attachments: message.attachments,
          messageId: message.id,
        );
      } else {
        // Regenerating for an AI response — find the preceding user message
        final userIdx = idx - 1;
        if (userIdx >= 0 && _messages[userIdx].isUser) {
          final userMsg = _messages[userIdx];
          // Delete old AI response from persistence
          final toDelete = _messages.sublist(idx);
          for (final m in toDelete) {
            _isarService.deleteMessage(m.id).catchError((e) => developer.log('Isar Delete Error: $e'));
          }
          _messages.removeRange(idx, _messages.length);
          notify();
          await sendUserMessage(context, 
            text: userMsg.text, 
            attachments: userMsg.attachments,
            messageId: userMsg.id,
          );
        }
      }
    }
  }

  void provideFeedback(ChatMessage message, int feedback) async {
    final newFeedback = message.feedback == feedback ? null : feedback;
    final updated = message.copyWith(feedback: newFeedback);
    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx != -1) {
      _messages[idx] = updated;
      notify();
    }
    await _isarService.saveMessage(updated);
    
    // Log message feedback to analytics
    await AnalyticsService.instance.logMessageFeedback(
      messageId: message.id,
      isPositive: feedback == 1,
    );
  }

  void shareMessage(String text) => ClipboardService.instance.shareText(text);

  void copyToClipboard(BuildContext context, String text) =>
      ClipboardService.instance.copyWithFeedback(context, text);

  void showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SessionRatingDialog(
        onSubmit: (rating, feedback) {
          AnalyticsService.instance.logSessionRating(
            rating: rating,
            feedback: feedback,
            sessionType: 'ai_tutor',
          );
        },
      ),
    );
  }

  Future<void> downloadImage(BuildContext context, String url) async {
    if (url.isEmpty) return;
    await ClipboardService.instance.shareImage(context, url);
  }
}
