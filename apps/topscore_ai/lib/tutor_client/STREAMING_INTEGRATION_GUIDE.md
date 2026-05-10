# Streaming AI Responses - Integration Guide

This guide explains how to integrate streaming AI responses into your TopScore AI chat interface.

## Overview

The streaming system consists of three main components:

1. **EnhancedWebSocketService** - Handles WebSocket connection and message routing
2. **StreamingMessageHandler** - Manages state for individual streaming messages
3. **StreamingMessageWidget** - UI component that displays streaming content

## Message Flow

```
Backend → WebSocket → EnhancedWebSocketService → StreamingMessageManager → StreamingMessageHandler → UI Widget
```

## Message Types

The backend sends these message types during streaming:

| Type | Description | Example |
|------|-------------|---------|
| `response_start` | Marks beginning of response | `{"type": "response_start", "id": "msg-123"}` |
| `chunk` | Incremental text content | `{"type": "chunk", "content": "Hello ", "id": "msg-123"}` |
| `table` | Table content | `{"type": "table", "content": "\| A \| B \|", "id": "msg-123"}` |
| `tool_call` | AI using a tool | `{"type": "tool_call", "tool": "graphing_tool", "input": {...}}` |
| `status` | Status update | `{"type": "status", "content": "Thinking...", "id": "msg-123"}` |
| `is_kicd_certified` | Curriculum certification | `{"type": "is_kicd_certified", "value": true, "id": "msg-123"}` |
| `done` | End of stream | `{"type": "done", "id": "msg-123"}` |
| `error` | Error occurred | `{"type": "error", "content": "Error message", "id": "msg-123"}` |

## Integration Steps

### Step 1: Initialize the Streaming Manager

In your chat provider or state management class:

```dart
import 'package:topscore_ai/tutor_client/streaming_message_handler.dart';
import 'package:topscore_ai/tutor_client/enhanced_websocket_service.dart';

class ChatProvider extends ChangeNotifier {
  late EnhancedWebSocketService _wsService;
  late StreamingMessageManager _streamingManager;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  ChatProvider({required String userId}) {
    _wsService = EnhancedWebSocketService(userId: userId);
    _streamingManager = StreamingMessageManager();
  }

  Future<void> initialize() async {
    await _wsService.initialize();
    await _wsService.connect();

    // Listen to WebSocket messages and route to streaming manager
    _messageSubscription = _wsService.messageStream.listen((message) {
      final type = message['type'];
      
      // Route streaming messages to the manager
      if (_isStreamingMessage(type)) {
        _streamingManager.handleMessage(message);
      } else {
        // Handle non-streaming messages (legacy, queued, etc.)
        _handleLegacyMessage(message);
      }
    });
  }

  bool _isStreamingMessage(String? type) {
    return type != null && [
      'response_start',
      'chunk',
      'table',
      'tool_call',
      'status',
      'is_kicd_certified',
      'done',
      'error',
    ].contains(type);
  }

  void _handleLegacyMessage(Map<String, dynamic> message) {
    // Handle non-streaming messages
    // e.g., 'queued', 'sync_complete', etc.
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _streamingManager.dispose();
    _wsService.dispose();
    super.dispose();
  }
}
```

### Step 2: Send a Message and Get Handler

```dart
class ChatProvider extends ChangeNotifier {
  // ... previous code ...

  Future<StreamingMessageHandler> sendMessage(String message) async {
    // Generate a response ID for this message
    final responseId = const Uuid().v4();
    
    // Get the handler before sending (so we can return it immediately)
    final handler = _streamingManager.getHandler(responseId);
    
    // Send the message via WebSocket
    await _wsService.sendMessage(
      message: message,
      userId: _currentUserId,
      threadId: _currentThreadId,
      modelPreference: 'smart',
      // Pass the response ID so backend can tag all chunks with it
      extraData: {'response_id': responseId},
    );
    
    return handler;
  }
}
```

### Step 3: Display Streaming Message in UI

```dart
import 'package:flutter/material.dart';
import 'package:topscore_ai/tutor_client/streaming_message_widget.dart';
import 'package:topscore_ai/tutor_client/streaming_message_handler.dart';

class ChatMessageBubble extends StatelessWidget {
  final StreamingMessageHandler handler;
  final bool isUser;

  const ChatMessageBubble({
    Key? key,
    required this.handler,
    required this.isUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: StreamingMessageWidget(
          handler: handler,
          showToolCalls: !isUser,
          showStatus: !isUser,
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
```

### Step 4: Complete Chat Screen Example

```dart
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  late ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear input
    _messageController.clear();

    // Add user message to UI
    setState(() {
      _messages.add(ChatMessage(
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    // Send message and get streaming handler
    final handler = await _chatProvider.sendMessage(text);

    // Add AI message placeholder to UI
    setState(() {
      _messages.add(ChatMessage(
        handler: handler,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    // Scroll to bottom
    _scrollToBottom();
  }

  void _scrollToBottom() {
    // Implement scroll logic
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TopScore AI')),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message.isUser) {
                  return ChatMessageBubble(
                    handler: StreamingMessageHandler(
                      messageId: 'user-${message.timestamp.millisecondsSinceEpoch}',
                    )..handleMessage({
                      'type': 'chunk',
                      'content': message.content,
                      'id': 'user-${message.timestamp.millisecondsSinceEpoch}',
                    })..handleMessage({
                      'type': 'done',
                      'id': 'user-${message.timestamp.millisecondsSinceEpoch}',
                    }),
                    isUser: true,
                  );
                } else {
                  return ChatMessageBubble(
                    handler: message.handler!,
                    isUser: false,
                  );
                }
              },
            ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask me anything...',
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

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final StreamingMessageHandler? handler;

  ChatMessage({
    this.content = '',
    required this.isUser,
    required this.timestamp,
    this.handler,
  });
}
```

## Advanced Features

### 1. Auto-scroll During Streaming

```dart
class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<StreamingMessageState>? _streamSubscription;

  void _listenToStreaming(StreamingMessageHandler handler) {
    _streamSubscription?.cancel();
    _streamSubscription = handler.stateStream.listen((state) {
      // Auto-scroll as content arrives
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
```

### 2. Typing Indicator

```dart
class TypingIndicator extends StatelessWidget {
  final StreamingMessageHandler handler;

  const TypingIndicator({Key? key, required this.handler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StreamingMessageState>(
      stream: handler.stateStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.isStreaming) {
          return const SizedBox.shrink();
        }

        return Row(
          children: [
            const SizedBox(width: 16),
            _BouncingDots(),
            const SizedBox(width: 8),
            Text(
              snapshot.data!.status.isEmpty 
                ? 'TopScore AI is typing...' 
                : snapshot.data!.status,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

### 3. Save Complete Message to Firestore

```dart
void _listenForCompletion(StreamingMessageHandler handler) {
  handler.stateStream.listen((state) {
    if (state.isComplete && !state.hasError) {
      // Save to Firestore
      _saveMessageToFirestore(
        messageId: state.messageId,
        content: state.content,
        isKicdCertified: state.isKicdCertified,
        toolCalls: state.toolCalls.map((t) => t.name).toList(),
      );
    }
  });
}

Future<void> _saveMessageToFirestore({
  required String messageId,
  required String content,
  required bool isKicdCertified,
  required List<String> toolCalls,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(_userId)
      .collection('chat_sessions')
      .doc(_threadId)
      .collection('messages')
      .doc(messageId)
      .set({
    'content': content,
    'role': 'assistant',
    'timestamp': FieldValue.serverTimestamp(),
    'is_kicd_certified': isKicdCertified,
    'tool_calls': toolCalls,
  });
}
```

## Testing

### Test Streaming Locally

```dart
void testStreaming() {
  final handler = StreamingMessageHandler(messageId: 'test-123');

  // Simulate streaming chunks
  handler.handleMessage({'type': 'response_start', 'id': 'test-123'});
  handler.handleMessage({'type': 'status', 'content': 'Thinking...', 'id': 'test-123'});
  handler.handleMessage({'type': 'chunk', 'content': 'Hello ', 'id': 'test-123'});
  handler.handleMessage({'type': 'chunk', 'content': 'world!', 'id': 'test-123'});
  handler.handleMessage({'type': 'done', 'id': 'test-123'});

  // Listen to state changes
  handler.stateStream.listen((state) {
    print('Content: ${state.content}');
    print('Status: ${state.status}');
    print('Complete: ${state.isComplete}');
  });
}
```

## Troubleshooting

### Issue: Messages not streaming

**Solution**: Ensure the backend is sending the `response_id` in all streaming messages:

```python
# Backend (Python)
async for chunk in result.stream():
    await output_queue.put({
        "type": "chunk",
        "content": chunk,
        "id": response_id  # ← Must include this!
    })
```

### Issue: UI not updating

**Solution**: Make sure you're using `StreamBuilder` to listen to the handler's state stream:

```dart
StreamBuilder<StreamingMessageState>(
  stream: handler.stateStream,
  builder: (context, snapshot) {
    // UI updates automatically when state changes
  },
)
```

### Issue: Multiple handlers for same message

**Solution**: Use `StreamingMessageManager.getHandler()` which ensures only one handler per message ID:

```dart
// ✅ Correct - reuses existing handler
final handler = streamingManager.getHandler(messageId);

// ❌ Wrong - creates duplicate handler
final handler = StreamingMessageHandler(messageId: messageId);
```

## Performance Tips

1. **Dispose handlers**: Handlers are automatically cleaned up 5 seconds after completion
2. **Limit history**: Only keep recent messages in memory
3. **Debounce auto-scroll**: Don't scroll on every single chunk
4. **Use const widgets**: Mark widgets as const where possible

## Next Steps

- [ ] Integrate into existing chat screen
- [ ] Add markdown rendering for formatted content
- [ ] Implement code syntax highlighting
- [ ] Add support for LaTeX math rendering
- [ ] Create unit tests for streaming logic
