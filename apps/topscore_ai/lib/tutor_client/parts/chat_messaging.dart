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

    // --- HYBRID STREAMING: EARLY ID REGISTRATION ---
    // Extract ID early to ensure any event with a message ID updates the tracking state
    // and lazily initializes the message object for artifact storage.
    String? effectiveId = messageId ??
        (type == 'chunk' || type == 'reasoning_chunk'
            ? _currentStreamingMessageId
            : null);

    if (effectiveId != null) {
      final existingIdx = _messages.indexWhere((m) => m.id == effectiveId);
      if (existingIdx != -1 && _messages[existingIdx].isComplete) {
        // If message is already marked as complete, ignore any further chunks
        // (This prevents the 'double rendering' of the final chunk if both chunk + done arrive)
        if (type == 'chunk' || type == 'reasoning_chunk') return null;
      }

      _currentStreamingMessageId = effectiveId;

      // Lazily initialize the message if it doesn't exist yet.
      // This is CRITICAL for artifacts that arrive before the first text chunk.
      // We check for both the effectiveId AND the temporary tracker ID it might be replacing.
      final exists = _messages.any((m) => m.id == effectiveId);

      if (!exists && type != 'status' && type != 'tool_call') {
        // Check if we can transition an existing optimistic placeholder instead of creating a new one
        final thinkingIdx = _messages.indexWhere((m) => 
          (m.isThinking || m.isTemporary) && m.text.isEmpty && !m.isUser);

        if (thinkingIdx != -1) {
          // Smooth transition: Reuse the existing bubble
          _messages[thinkingIdx] = _messages[thinkingIdx].copyWith(
            id: effectiveId,
            isThinking: type == 'chunk' || type == 'reasoning_chunk' ? false : true,
            isTemporary: true,
            isComplete: false,
            threadId: _wsService?.threadId ?? '',
          );
        } else {
          // No placeholder to reuse, create a fresh one
          _messages.add(ChatMessage(
            id: effectiveId,
            text: '',
            isUser: false,
            timestamp: DateTime.now(),
            isTemporary: true,
            isComplete: false,
            isThinking: true, 
            threadId: _wsService?.threadId ?? '',
          ));
        }
        notify();
        scrollToBottom();
      }

      // --- BUNDLED ARTIFACTS SUPPORT ---
      if (data['artifacts'] is List) {
        _processArtifactsList(data['artifacts'], effectiveId);
      }
      if (data['widgets'] is List) {
        _processArtifactsList(data['widgets'], effectiveId);
      }
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

          // If the status contains an ID, update the tracking but don't force message creation
          // yet (status often arrives long before text).
          if (messageId != null) {
            _currentStreamingMessageId = messageId;
          }
        }
        return null;

      case 'widget':
        return _handleUiWidgetEvent(data);

      // Defensive fallbacks: older/legacy backend payloads sometimes arrive with the
      // concrete widget kind as the top-level `type` instead of being wrapped in a
      // `'widget'` envelope. Route them the same way so widgets don't silently drop.
      case 'interactive_table':
      case 'image':
      case 'image_widget':
      case 'plotly':
      case 'p5_playground':
      case 'code_playground':
        return _handleUiWidgetEvent(data);

      case 'artifact':
        final artifactType = data['artifact_type'] ?? type;
        final rawUrl = data['url']?.toString();
        final isValidUrl = rawUrl != null && rawUrl.startsWith('http');

        if ((artifactType == 'image' || artifactType == 'graph' || artifactType == 'diagram' || artifactType == 'image_widget') && isValidUrl) {
          // Image/Graph/Diagram tools (serpapi / wikimedia / fetch_educational_images / graphing_tool / generate_educational_diagram) emit
          // `{type:'artifact', artifact_type:'image'|'graph'|'diagram', url, title, source}` WITHOUT
          // an `id`. _handleUiWidgetEvent requires a non-null id to attach the
          // widget, so synthesize a stable one from the url if needed.
          final rawId = data['id'];
          final url = data['url']?.toString() ?? '';
          final synthId = (rawId is String && rawId.isNotEmpty)
              ? rawId
              : 'img_${url.hashCode}';
          final normalizedWidget = {
            'id': synthId,
            'type': 'image_widget',
            'title': data['title'] ?? (artifactType == 'graph' ? 'Generated Graph' : 'Image Illustration'),
            'config': {
              'url': data['url'],
              'title': data['title'] ?? (artifactType == 'graph' ? 'Generated Graph' : 'Image Illustration'),
              'source': data['source'],
              'source_url': data['source_url'],
            }
          };
          return _handleUiWidgetEvent(normalizedWidget);
        }

        // Other unhandled artifacts
        return null;

      case 'tool_call':
        // Tool calls are for internal logic (e.g. backend functions) and should NEVER render.
        developer.log(
            'AI Tutor received tool_call: ${data['method'] ?? 'unknown'}',
            name: 'ChatController');
        return null;

      case 'response_start':
        _cancelResponseTimeout();
        _isTyping = true;
        _userStoppedGeneration = false;
        notify();

        if (messageId != null) {
          final oldTrackerId = _currentStreamingMessageId;
          _currentStreamingMessageId = messageId;

          // --- SMOOTH ID TRANSITION ---
          // Find the existing "Thinking..." placeholder (either by its ID or by state)
          // and update it to the server's real response ID.
          final thinkingIdx = _messages.indexWhere((m) => 
            m.id == oldTrackerId || (m.isThinking && m.text.isEmpty && !m.isUser));

          if (thinkingIdx != -1) {
            final oldMsg = _messages[thinkingIdx];
            // Only update if it doesn't already have the target ID
            if (oldMsg.id != messageId) {
              _messages[thinkingIdx] = oldMsg.copyWith(
                id: messageId,
                isThinking: false, // Transition to real streaming state
                isTemporary: true,
                isComplete: false,
                threadId: _wsService?.threadId ?? '',
              );
              notify();
            }
          } else {
            // No placeholder found (rare), but we might have just created it above in the lazy init
            final alreadyCreated = _messages.any((m) => m.id == messageId);
            if (!alreadyCreated) {
              _messages.add(ChatMessage(
                id: messageId,
                text: '',
                isUser: false,
                timestamp: DateTime.now(),
                isTemporary: true,
                isComplete: false,
                threadId: _wsService?.threadId ?? '',
              ));
              notify();
              scrollToBottom();
            }
          }

          // Handle thread title generation if this is a new chat
          if (_messages.isNotEmpty &&
              (_currentTitle == 'New Chat' || _currentTitle == 'New Chat...')) {
            final firstUserMsg = _messages.firstWhere((m) => m.isUser,
                orElse: () => _messages.first);
            final raw = stripMarkdown(firstUserMsg.text);
            final title = raw.length > 40 ? '${raw.substring(0, 37)}...' : raw;
            if (title.isNotEmpty) {
              _titleCache[_wsService?.threadId ?? ''] = title;
              _currentTitle = title;
              notify();
            }
          }
        }
        break;

      case 'title_updated':
        final updatedThreadId = data['thread_id'] ?? _wsService?.threadId ?? '';
        final rawTitle = data['title'];
        if (rawTitle != null && rawTitle.toString().isNotEmpty) {
          final cleanTitle = stripMarkdown(rawTitle.toString());
          _titleCache[updatedThreadId] = cleanTitle;
          if (updatedThreadId == (_wsService?.threadId ?? '')) {
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
        // --- MULTI-MODAL CHUNK SUPPORT ---
        // If the chunk contains a URL, it's an artifact (image/graph/table)
        final rawUrl = data['url']?.toString();
        final isValidUrl = rawUrl != null && rawUrl.startsWith('http');

        if (isValidUrl) {
          final normalized = {
            'id': data['id'] ?? rawUrl.hashCode.toString(),
            'type': 'image_widget',
            'title': data['title'] ?? 'Image Illustration',
            'config': {
              'url': data['url'],
              'title': data['title'],
              'source': data['source'],
            }
          };
          _handleUiWidgetEvent(normalized);

          // If this chunk ONLY contains an artifact (no text), stop processing here
          if (data['content'] == null || data['content'].toString().isEmpty) {
            return null;
          }
        }

        final chunkContent = data['content'] as String? ?? '';

        // Haptic Trigger 2: First Token Arrival
        if (!_firstTokenHapticFired && chunkContent.isNotEmpty) {
          _cancelResponseTimeout();
          HapticFeedback.mediumImpact();
          _firstTokenHapticFired = true;
        }

        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null) {
          // Clear thinking state if we start receiving real content
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1 && _messages[idx].isThinking) {
            _messages[idx] = _messages[idx].copyWith(isThinking: false);
          }

          // --- FALLBACK PARSER: Extract Quiz data from text stream ---
          if (chunkContent.contains('[QUIZ_DATA]')) {
            final configJson = extractBalancedTagContent(chunkContent, 'QUIZ_DATA');
            if (configJson != null) {
              final idx = _messages.indexWhere((m) => m.id == targetId);
              if (idx != -1 && _messages[idx].quizDataJson == null) {
                developer.log('Fallback parser found Quiz data for $targetId',
                    name: 'ChatController');
                _messages[idx] =
                    _messages[idx].copyWith(quizDataJson: configJson);
                notify();
              }
            }
          }

          // --- FALLBACK PARSER: Extract Flashcards data from text stream ---
          if (chunkContent.contains('[FLASHCARDS_DATA]')) {
            final configJson = extractBalancedTagContent(chunkContent, 'FLASHCARDS_DATA');
            if (configJson != null) {
              final idx = _messages.indexWhere((m) => m.id == targetId);
              if (idx != -1 && _messages[idx].flashcardDataJson == null) {
                developer.log(
                    'Fallback parser found Flashcards for $targetId',
                    name: 'ChatController');
                _messages[idx] =
                    _messages[idx].copyWith(flashcardDataJson: configJson);
                notify();
              }
            }
          }

          // --- FALLBACK PARSER: Extract Mnemonic data from text stream ---
          if (chunkContent.contains('[MNEMONIC_DATA]')) {
            final configJson = extractBalancedTagContent(chunkContent, 'MNEMONIC_DATA');
            if (configJson != null) {
              final idx = _messages.indexWhere((m) => m.id == targetId);
              if (idx != -1 && _messages[idx].mnemonicDataJson == null) {
                developer.log(
                    'Fallback parser found Mnemonic data for $targetId',
                    name: 'ChatController');
                _messages[idx] =
                    _messages[idx].copyWith(mnemonicDataJson: configJson);
                notify();
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
                  developer.log('Fallback parser found Image URL for $targetId',
                      name: 'ChatController');
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
                  developer.log(
                      'Fallback parser found Punnett data for $targetId',
                      name: 'ChatController');
                  _messages[idx] =
                      _messages[idx].copyWith(punnettDataJson: configJson);
                  notify();
                }
              }
            }
          }

          // --- FALLBACK PARSER: Extract dynamic UI widgets (Interactive Tables, etc.) ---
          // Updated to skip the side-channel format :::ui-widget|id:::
          if (chunkContent.contains(':::ui-widget') &&
              !chunkContent.contains(':::ui-widget|')) {
            final regex =
                RegExp(r':::ui-widget[\r\n]+(.*?)([\r\n]+:::|$)', dotAll: true);
            final match = regex.firstMatch(chunkContent);
            if (match != null) {
              final widgetJson = match.group(1);
              if (widgetJson != null) {
                final idx = _messages.indexWhere((m) => m.id == targetId);
                if (idx != -1) {
                  final existingWidgets = _messages[idx].uiWidgetsJson ?? [];
                  if (!existingWidgets.contains(widgetJson)) {
                    developer.log(
                        'Fallback parser found UI Widget for $targetId',
                        name: 'ChatController');
                    _messages[idx] = _messages[idx].copyWith(
                      uiWidgetsJson: [...existingWidgets, widgetJson],
                    );
                    notify();
                  }
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
              threadId: _wsService?.threadId ?? '',
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
        HapticFeedback.lightImpact();
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
          final finalContent = finalContentRaw != null
              ? postFormatAIResponse(finalContentRaw)
              : null;
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
                    threadId: _wsService?.threadId ?? '',
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
        return _messages.firstWhere((m) => m.id == messageId,
            orElse: () => _messages.last);
      case 'error':
        final errorCode = data['code'] as String?;
        final errorMsg =
            data['message'] ?? 'An Error occurred, please try again';

        // --- SERVER-SIDE LIMIT REACHED ---
        if (errorCode == 'FREE_LIMIT_REACHED') {
          developer.log('Server-side limit reached (FREE_LIMIT_REACHED)',
              name: 'ChatController');
          limitReached.value = errorCode;

          // Clean up thinking area so it doesn't hang
          _messages.removeWhere((m) => m.isThinking && m.isTemporary);
          _currentStreamingMessageId = null;
          _isTyping = false;

          finalizeTurn(null);
          return null;
        }

        final targetId =
            messageId ?? _currentStreamingMessageId ?? const Uuid().v4();
        final idx = _messages.indexWhere((m) => m.id == targetId);

        if (idx != -1) {
          // UPDATE EXISTING MESSAGE (Clean area as requested)
          _messages[idx] = _messages[idx].copyWith(
            text: errorMsg,
            status: MessageStatus.error,
            isComplete: true,
            isTemporary: false,
            reasoning: '', // Clear thinking area
          );
        } else {
          // ADD NEW ERROR MESSAGE (Only if no target exists)
          final errorChatMsg = ChatMessage(
            id: targetId,
            text: errorMsg,
            isUser: false,
            timestamp: DateTime.now(),
            status: MessageStatus.error,
            threadId: _wsService?.threadId ?? '',
            isComplete: true,
            isTemporary: false,
          );
          _messages.add(errorChatMsg);
        }

        notify();
        scrollToBottom();
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
          final quizJson =
              quizData is String ? quizData : json.encode(quizData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(quizDataJson: quizJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
            AnalyticsService.instance
                .logEvent('quiz_rendered', {'topic': 'auto'});
          } else {
            final msg = ChatMessage(
              id: targetId,
              text: '',
              isUser: false,
              timestamp: DateTime.now(),
              isTemporary: true,
              isComplete: false,
              quizDataJson: quizJson,
              threadId: _wsService?.threadId ?? '',
            );
            _messages.add(msg);
            _currentStreamingMessageId = targetId;
            notify();
            scrollToBottom();
          }
        }
        break;

      case 'flashcards':
        final flashcardData = data['flashcard_data'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null && flashcardData != null) {
          final flashcardJson = flashcardData is String
              ? flashcardData
              : json.encode(flashcardData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] =
                _messages[idx].copyWith(flashcardDataJson: flashcardJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
          } else {
            // Message not yet created — add it now so the artifact isn't lost
            final msg = ChatMessage(
              id: targetId,
              text: '',
              isUser: false,
              timestamp: DateTime.now(),
              isTemporary: true,
              isComplete: false,
              flashcardDataJson: flashcardJson,
              threadId: _wsService?.threadId ?? '',
            );
            _messages.add(msg);
            _currentStreamingMessageId = targetId;
            notify();
            scrollToBottom();
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
              threadId: _wsService?.threadId ?? '',
            ));
            _currentStreamingMessageId = tId;
          }
          notify();
          scrollToBottom();
        }
        break;

      case 'mnemonic':
        final mnemonicData = data['mnemonic_data'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null && mnemonicData != null) {
          final mnemonicJson =
              mnemonicData is String ? mnemonicData : json.encode(mnemonicData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] =
                _messages[idx].copyWith(mnemonicDataJson: mnemonicJson);
            notify();
            _isarService.saveMessage(_messages[idx]);
            AnalyticsService.instance
                .logEvent('mnemonic_generated', {'topic': 'auto'});
          }
        }
        break;

      case 'ui_widget':
        final widgetData = data['widget_data'] ?? data['content'];
        final targetId = messageId ?? _currentStreamingMessageId;
        if (targetId != null && widgetData != null) {
          final widgetJson =
              widgetData is String ? widgetData : json.encode(widgetData);
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            final existingWidgets = _messages[idx].uiWidgetsJson ?? [];
            if (!existingWidgets.contains(widgetJson)) {
              _messages[idx] = _messages[idx].copyWith(
                uiWidgetsJson: [...existingWidgets, widgetJson],
              );
              notify();
              _isarService.saveMessage(_messages[idx]);
            }
          }
        }
        break;

      case 'is_kicd_certified':
        final targetId = messageId ?? _currentStreamingMessageId;
        final isCertified = data['value'] as bool? ?? false;
        if (targetId != null) {
          final idx = _messages.indexWhere((m) => m.id == targetId);
          if (idx != -1) {
            _messages[idx] =
                _messages[idx].copyWith(isKicdCertified: isCertified);
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

      case 'video_results':
        final videosList = data['video_results'] as List<dynamic>?;
        final targetVideoId = messageId ?? _currentStreamingMessageId;
        if (targetVideoId != null && videosList != null) {
          try {
            final parsedVideos = videosList
                .map((v) => VideoResult.fromJson(Map<String, dynamic>.from(v)))
                .toList();
            final idx = _messages.indexWhere((m) => m.id == targetVideoId);
            if (idx != -1) {
              _messages[idx] = _messages[idx].copyWith(videos: parsedVideos);
              notify();
              _isarService.saveMessage(_messages[idx]);
            } else {
              _messages.add(ChatMessage(
                id: targetVideoId,
                text: '',
                isUser: false,
                timestamp: DateTime.now(),
                isTemporary: true,
                isComplete: false,
                videos: parsedVideos,
                threadId: _wsService?.threadId ?? '',
              ));
              _currentStreamingMessageId = targetVideoId;
              notify();
              scrollToBottom();
            }
          } catch (e) {
            developer.log('Error parsing video_results: $e',
                name: 'ChatController');
          }
        }
        break;

      case 'video_simulation':
        final simUrl = data['video_simulation'] as String?;
        final targetSimId = messageId ?? _currentStreamingMessageId;
        if (targetSimId != null && simUrl != null) {
          final simVideo = VideoResult(
            id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
            title: 'AI Experiment Simulation',
            videoUrl: simUrl,
            thumbnailUrl: '',
            source: 'Veo Simulation',
            duration: '0:10',
          );
          final idx = _messages.indexWhere((m) => m.id == targetSimId);
          if (idx != -1) {
            final existing =
                List<VideoResult>.from(_messages[idx].videos ?? []);
            if (!existing.any((v) => v.videoUrl == simUrl)) {
              existing.add(simVideo);
              _messages[idx] = _messages[idx].copyWith(videos: existing);
              notify();
              _isarService.saveMessage(_messages[idx]);
            }
          }
        }
        break;

      case 'mock_exam':
        final examData = data['mock_exam'] as Map<String, dynamic>?;
        final targetExamId = messageId ?? _currentStreamingMessageId;
        if (targetExamId != null && examData != null) {
          final widgetData = UiWidgetData(
            id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
            type: 'mock_exam',
            title: examData['title'] ?? 'Mock Exam',
            configJson: jsonEncode(examData),
          );
          final idx = _messages.indexWhere((m) => m.id == targetExamId);
          if (idx != -1) {
            final existing =
                List<UiWidgetData>.from(_messages[idx].uiWidgets ?? []);
            if (!existing.any((w) {
              if (w.configJson == null) return false;
              try {
                final cfg = jsonDecode(w.configJson!);
                return cfg['url'] == examData['url'];
              } catch (_) {
                return false;
              }
            })) {
              existing.add(widgetData);
              _messages[idx] = _messages[idx].copyWith(uiWidgets: existing);
              notify();
              _isarService.saveMessage(_messages[idx]);
            }
          }
        }
        break;

      case 'interactive_sim':
        final simData = data['interactive_sim'] as Map<String, dynamic>?;
        final targetSimId = messageId ?? _currentStreamingMessageId;
        if (targetSimId != null && simData != null) {
          final widgetData = UiWidgetData(
            id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
            type: 'interactive_sim',
            title: simData['title'] ?? 'Interactive Simulation',
            configJson: jsonEncode(simData),
          );
          final idx = _messages.indexWhere((m) => m.id == targetSimId);
          if (idx != -1) {
            final existing =
                List<UiWidgetData>.from(_messages[idx].uiWidgets ?? []);
            if (!existing.any((w) {
              if (w.configJson == null) return false;
              try {
                final cfg = jsonDecode(w.configJson!);
                return cfg['url'] == simData['url'];
              } catch (_) {
                return false;
              }
            })) {
              existing.add(widgetData);
              _messages[idx] = _messages[idx].copyWith(uiWidgets: existing);
              notify();
              _isarService.saveMessage(_messages[idx]);
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

    if (_messageQueue.isNotEmpty && context != null) {
      final next = _messageQueue.removeAt(0);
      final authProvider = context.read<AuthProvider>();
      final settings = context.read<SettingsProvider>();
      _isTyping = true;
      notify();
      _wsService?.sendMessage(
        message: next['message'] ?? '',
        userId: authProvider.userModel?.uid ?? 'anon',
        fileUrls: next['fileUrls'] != null
            ? List<String>.from(next['fileUrls'])
            : null,
        fileType: next['fileType'] ?? 'image',
        modelPreference: _selectedModelKey,
        dataSaver: settings.isLiteMode,
        userName: authProvider.userModel?.preferredName ??
            authProvider.userModel?.displayName,
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
      threadId: _wsService?.threadId ?? '',
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
      if (_wsService?.isConnected ?? false) {
        _wsService
            ?.sendRaw({'type': 'stop', 'thread_id': _wsService?.threadId});
      }
    } catch (_) {}

    final stoppingId = _currentStreamingMessageId;
    if (stoppingId != null) {
      final idx = _messages.indexWhere((m) => m.id == stoppingId);
      if (idx != -1) {
        // Halt and preserve partial AI message
        final currentText = _messages[idx].text;
        _messages[idx] = _messages[idx].copyWith(
          text: currentText.isNotEmpty
              ? '$currentText\n\n[Generation stopped]'
              : '[Generation stopped]',
          isTemporary: false,
          isComplete: true,
          isThinking: false,
          status: MessageStatus.sent,
        );
        _isarService.saveMessage(_messages[idx]);
        _userStoppedGeneration = true;
        _currentStreamingMessageId = null;
        _isTyping = false;
        notify();
        return;
      }
    }

    // Fallback: If still "Thinking" (no streaming ID yet), revert last user message
    if (_isTyping) {
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
      _isTyping = false;
      _userStoppedGeneration = true;
      notify();
    }
  }

  Future<void> sendUserMessage(BuildContext context,
      {String? text,
      List<ChatAttachmentMetadata>? attachments,
      String? messageId}) async {
    HapticFeedback.lightImpact();
    _firstTokenHapticFired = false;
    final authProvider = context.read<AuthProvider>();
    developer.log('sendUserMessage: Checking connection (isOnline: $isOnline, hasInternet: $hasInternet)',
        name: 'ChatController');

    // --- CONNECTION GUARD: Wait briefly if connecting, block only if truly offline ---
    if (!isOnline) {
      if (hasInternet && isConnecting) {
        // Socket is mid-handshake — wait up to 5s for it to come up
        bool connected = false;
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (isOnline) {
            connected = true;
            break;
          }
        }
        if (!connected) {
          // Trigger a fresh connect attempt and let the message queue handle it
          _wsService?.resetConnection();
        }
      } else if (!hasInternet) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(CupertinoIcons.wifi_slash, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        "You're offline. Check your internet connection.")),
              ],
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      // If we have internet but socket is still not up after waiting,
      // fall through — sendMessage will queue the message in offline storage.
    }

    if (authProvider.userModel == null) return;

    developer.log('sendUserMessage: Checking auth (canSendMessage: ${authProvider.canSendMessage})',
        name: 'ChatController');

    if (!authProvider.canSendMessage) {
      developer.log('sendUserMessage: Local limit reached, showing dialog',
          name: 'ChatController');
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => TrialCompletedOverlay(
            requiresAccount: authProvider.userModel == null,
          ),
        );
      }
      return;
    }

    // --- UPLOAD GUARD: Wait for pending attachment uploads to complete ---
    if (_isUploading && attachments == null) {
      developer.log('sendUserMessage: Upload in progress, waiting for completion...', name: 'ChatController');
      for (int i = 0; i < 40; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isUploading) {
          developer.log('sendUserMessage: Upload finished!', name: 'ChatController');
          break;
        }
      }
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
      threadId: _wsService?.threadId ?? '',
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

    // Buddy: fire-and-forget language detection. If user typed in a supported
    // foreign language we haven't suggested this session, show the banner.
    _maybeDetectLanguage(messageText);

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
      threadId: _wsService?.threadId ?? '',
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
        'thread_id': _wsService?.threadId ?? '',
        'title': historyTitle,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'model': _selectedModelKey,
      });
    }

    if (_messages.length == 1) {
      AnalyticsService.instance.logEvent('ai_chat_initiated', {
        'thread_id': _wsService?.threadId ?? '',
        'model': _selectedModelKey,
      });
    }

    try {
      // Note: We increment the message count AFTER successful AI response
      // (see case 'complete' handler below), not here. This ensures only
      // successful messages count toward the freemium limit.

      if (isBusy) {
        _messageQueue.add({
          'message': messageText,
          'fileUrls': urlsToExtra,
          'fileType': attachmentsMetadata.isNotEmpty
              ? attachmentsMetadata.first.type
              : 'image',
          'pendingId': pendingId,
        });
        return;
      }

      if (!context.mounted) return;
      developer.log(
          'sendUserMessage: Sending message ID: $pendingId, content length: ${messageText.length}',
          name: 'ChatController');
      developer.log('sendUserMessage: WebSocket State: ${connectionState.name}',
          name: 'ChatController');

      final settings = context.read<SettingsProvider>();
      if (_wsService == null) {
        developer.log('sendUserMessage: CRITICAL - _wsService is null!',
            name: 'ChatController');
      }
      _wsService?.sendMessage(
        message: messageText,
        userId: authProvider.userModel?.uid ?? 'anon',
        fileUrls: urlsToExtra,
        fileType: attachmentsMetadata.isNotEmpty
            ? attachmentsMetadata.first.type
            : 'image',
        modelPreference: _selectedModelKey,
        dataSaver: settings.isLiteMode,
        replyToId: pendingMessage.replyToId,
        replyToText: pendingMessage.replyToText,
        userName: authProvider.userModel?.preferredName ??
            authProvider.userModel?.displayName,
      );

      _startResponseTimeout(pendingId);

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
            content:
                const Text('Message failed to send. Tap the message to retry.'),
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
  Future<void> retryFailedMessage(
      BuildContext context, ChatMessage message) async {
    developer.log('retryFailedMessage: Attempting retry for ID: ${message.id}',
        name: 'ChatController');

    if (!message.isUser) {
      developer.log('retryFailedMessage: Message is AI error bubble, finding last user message...',
          name: 'ChatController');
      // Find the last user message to retry
      try {
        final lastUserMsg = _messages.lastWhere((m) => m.isUser);
        developer.log('retryFailedMessage: Found last user message: ${lastUserMsg.id}, retrying that.',
            name: 'ChatController');
        return retryFailedMessage(context, lastUserMsg);
      } catch (e) {
        developer.log('retryFailedMessage: No user message found to retry.',
            name: 'ChatController');
        return;
      }
    }
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
        _isarService
            .deleteMessage(m.id)
            .catchError((e) => developer.log('Isar Delete Error: $e'));
      }
    }
    _messages.removeRange(idx + 1, _messages.length);
    // Reset this one to pending
    _messages[idx] = _messages[idx].copyWith(status: MessageStatus.pending);
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
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
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
              style: TextStyle(
                  color: Color(0xFF475569), fontWeight: FontWeight.w600),
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
        _isarService
            .deleteMessage(m.id)
            .catchError((e) => developer.log('Isar Delete Error: $e'));
      }
      _messages.removeRange(idx, _messages.length);
      notify();
      await sendUserMessage(
        context,
        text: editedText,
        messageId: message.id,
        attachments: message.attachments,
      );
    } else {
      if (message.isUser) {
        // Regenerating from a user message — delete existing AI responses
        final toDelete = _messages.sublist(idx + 1);
        for (final m in toDelete) {
          _isarService
              .deleteMessage(m.id)
              .catchError((e) => developer.log('Isar Delete Error: $e'));
        }
        _messages.removeRange(idx + 1, _messages.length);
        notify();
        await sendUserMessage(
          context,
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
            _isarService
                .deleteMessage(m.id)
                .catchError((e) => developer.log('Isar Delete Error: $e'));
          }
          _messages.removeRange(idx, _messages.length);
          notify();
          await sendUserMessage(
            context,
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

    // Persist feedback to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('message_feedback').add({
        'messageId': message.id,
        'threadId': _wsService?.threadId ?? '',
        'userId': user?.uid ?? 'guest',
        'feedback': newFeedback, // 1, -1, or null (toggled off)
        'messagePreview': message.text.length > 100
            ? message.text.substring(0, 100)
            : message.text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Failed to save message feedback: $e',
          name: 'ChatController');
    }

    // Log message feedback to analytics
    if (newFeedback != null) {
      await AnalyticsService.instance.logMessageFeedback(
        messageId: message.id,
        isPositive: newFeedback == 1,
      );
    }
  }

  void shareMessage(String text) => ClipboardService.instance.shareText(text);

  void copyToClipboard(BuildContext context, String text) =>
      ClipboardService.instance.copyText(text);

  void showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SessionRatingDialog(
        onSubmit: (rating, feedback) async {
          // Persist to Firestore so ratings are not lost
          try {
            final user = FirebaseAuth.instance.currentUser;
            await FirebaseFirestore.instance.collection('session_ratings').add({
              'userId': user?.uid ?? 'guest',
              'userEmail': user?.email ?? 'anonymous',
              'rating': rating,
              'feedback': feedback,
              'sessionType': 'ai_tutor',
              'threadId': _wsService?.threadId ?? '',
              'timestamp': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            developer.log('Failed to save session rating: $e',
                name: 'ChatController');
          }
          // Also log to analytics
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

  /// Helper to process a list of bundled artifacts or widgets
  void _processArtifactsList(List<dynamic> artifacts, String targetId) {
    for (final item in artifacts) {
      if (item is! Map<String, dynamic>) continue;

      final type = item['type'] ?? item['artifact_type'];

      if (type == 'image' || type == 'image_widget' || type == 'graph' || type == 'diagram') {
        final rawId = item['id'];
        final url = item['url'] ?? item['image_url'] ?? '';
        final synthId = (rawId is String && rawId.isNotEmpty)
            ? rawId
            : 'img_${url.hashCode}';
        final normalized = {
          'id': synthId,
          'type': 'image_widget',
          'to_message_id': targetId,
          'title': item['title'] ?? (type == 'graph' ? 'Generated Graph' : 'Image Illustration'),
          'config': {
            'url': url,
            'title': item['title'] ?? (type == 'graph' ? 'Generated Graph' : 'Image Illustration'),
            'source': item['source'],
          }
        };
        _handleUiWidgetEvent(normalized);
      } else {
        // Fallback for other widget types (tables, etc.)
        final normalized = Map<String, dynamic>.from(item);
        if (!normalized.containsKey('to_message_id')) {
          normalized['to_message_id'] = targetId;
        }
        _handleUiWidgetEvent(normalized);
      }
    }
  }

  /// Helper to process normalized UI widget events from different producers (widget vs artifact)
  ChatMessage? _handleUiWidgetEvent(Map<String, dynamic> data) {
    final widgetId = data['id'];
    final targetId = data['to_message_id'] ?? _currentStreamingMessageId;
    if (widgetId != null && targetId != null) {
      final idx = _messages.indexWhere((m) => m.id == targetId);
      if (idx != -1) {
        // The backend envelope uses `type: 'widget'` for routing and carries the
        // concrete widget kind in `widget_type`. Flatten it so UiWidgetData.fromJson
        // (which reads `type`) sees the correct renderer key.
        final Map<String, dynamic> forFactory = Map<String, dynamic>.from(data);
        final wt = data['widget_type'];
        if (wt is String && wt.isNotEmpty) {
          forFactory['type'] = wt;
        }
        final widgetData = UiWidgetData.fromJson(forFactory);
        final List<UiWidgetData> existing =
            List.from(_messages[idx].uiWidgets ?? []);

        // Check if widget already exists (by ID) to avoid duplicates
        final existingIdx = existing.indexWhere((w) => w.id == widgetId);
        if (existingIdx != -1) {
          existing[existingIdx] = widgetData;
        } else {
          existing.add(widgetData);
        }

        _messages[idx] = _messages[idx].copyWith(uiWidgets: existing);
        _isarService.saveMessage(_messages[idx]);
        notify();
      }
    }
    return null;
  }

  void _handleResponseTimeout(String messageId) {
    developer.log('AI Tutor response timeout for message: $messageId',
        name: 'ChatController');

    // Find and clean up any thinking skeletons or temporary messages
    _messages.removeWhere((m) => m.isThinking && m.isTemporary);
    _currentStreamingMessageId = null;
    _isTyping = false;
    _currentAiStatus = null;

    // Find the original user message that timed out
    final userIdx = _messages.indexWhere((m) => m.id == messageId);
    if (userIdx != -1) {
      _messages[userIdx] = _messages[userIdx].copyWith(
        status: MessageStatus.error,
      );
      _isarService.saveMessage(_messages[userIdx]);
    }

    // Add an error message if one doesn't exist yet for this context
    final errorId = 'err_${const Uuid().v4()}';
    final timeoutErrorMsg = ChatMessage(
      id: errorId,
      text:
          "The AI Tutor is taking longer than usual to respond. This can happen during peak times. Please check your connection and try again.",
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.error,
      threadId: _wsService?.threadId ?? '',
      isComplete: true,
      isTemporary: false,
    );
    _messages.add(timeoutErrorMsg);
    // Note: We don't save the error bubble itself to Isar/Firestore so it doesn't
    // clutter the persistent history or count toward usage limits.

    notify();
    scrollToBottom();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Buddy: language detection on outbound text
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _maybeDetectLanguage(String text) async {
    final trimmed = text.trim();
    if (trimmed.length < 12) return;
    try {
      final detected = await LanguageDetectService.instance.detect(trimmed);
      if (detected == null) return;
      if (_suggestedThisSession.contains(detected.language)) return;
      // Add immediately to dedupe even if the user re-types before tap.
      _suggestedThisSession.add(detected.language);
      languageSuggestion.value = LanguageSuggestion(detected.language);
    } catch (_) {
      // Detection is best-effort; ignore errors silently.
    }
  }
}
