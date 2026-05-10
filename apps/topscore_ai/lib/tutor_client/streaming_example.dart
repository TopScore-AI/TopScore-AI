/// MINIMAL STREAMING EXAMPLE
///
/// This file shows the absolute minimum code needed to get streaming AI responses
/// working in your app. Copy and adapt this to your existing chat implementation.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'enhanced_websocket_service.dart';
import 'streaming_message_handler.dart';

/// Minimal chat screen with streaming support
class MinimalStreamingChatScreen extends StatefulWidget {
  final String userId;

  const MinimalStreamingChatScreen({
    super.key,
    required this.userId,
  });

  @override
  State<MinimalStreamingChatScreen> createState() =>
      _MinimalStreamingChatScreenState();
}

class _MinimalStreamingChatScreenState
    extends State<MinimalStreamingChatScreen> {
  // Core components
  late EnhancedWebSocketService _wsService;
  late StreamingMessageManager _streamingManager;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  // UI state
  final TextEditingController _inputController = TextEditingController();
  final List<MessageItem> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    // 1. Create WebSocket service
    _wsService = EnhancedWebSocketService(userId: widget.userId);
    _streamingManager = StreamingMessageManager();

    // 2. Initialize and connect
    await _wsService.initialize();
    await _wsService.connect();

    // 3. Listen to incoming messages
    _wsSubscription = _wsService.messageStream.listen((message) {
      final type = message['type'];

      // Route streaming messages to the manager
      if (_isStreamingType(type)) {
        _streamingManager.handleMessage(message);
      }
    });
  }

  bool _isStreamingType(String? type) {
    return type != null &&
        [
          'response_start',
          'chunk',
          'table',
          'tool_call',
          'status',
          'is_kicd_certified',
          'done',
          'error'
        ].contains(type);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();

    // Add user message
    setState(() {
      _messages.add(MessageItem(
        text: text,
        isUser: true,
      ));
    });

    // Generate response ID
    final responseId = const Uuid().v4();

    // Get handler for this response
    final handler = _streamingManager.getHandler(responseId);

    // Add AI message placeholder
    setState(() {
      _messages.add(MessageItem(
        handler: handler,
        isUser: false,
      ));
    });

    // Send message via WebSocket
    await _wsService.sendMessage(
      message: text,
      userId: widget.userId,
      extraData: {'response_id': responseId},
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _streamingManager.dispose();
    _wsService.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming Chat'),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple message item
class MessageItem {
  final String? text;
  final StreamingMessageHandler? handler;
  final bool isUser;

  MessageItem({
    this.text,
    this.handler,
    required this.isUser,
  });
}

/// Simple message bubble
class _MessageBubble extends StatelessWidget {
  final MessageItem message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: message.isUser
            ? Text(message.text ?? '')
            : _StreamingContent(handler: message.handler!),
      ),
    );
  }
}

/// Streaming content that updates in real-time
class _StreamingContent extends StatelessWidget {
  final StreamingMessageHandler handler;

  const _StreamingContent({required this.handler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StreamingMessageState>(
      stream: handler.stateStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('...');
        }

        final state = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status (e.g., "Thinking...")
            if (state.hasStatus)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Tool calls
            if (state.hasToolCalls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: state.toolCalls.map((tool) {
                    return Chip(
                      label: Text(
                        tool.description,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.blue[50],
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),

            // Content
            if (state.content.isNotEmpty) Text(state.content),

            // Cursor while streaming
            if (state.isStreaming && state.content.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),

            // Error
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '❌ ${state.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// USAGE EXAMPLE:
///
/// ```dart
/// // In your app:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => MinimalStreamingChatScreen(
///       userId: FirebaseAuth.instance.currentUser!.uid,
///     ),
///   ),
/// );
/// ```
