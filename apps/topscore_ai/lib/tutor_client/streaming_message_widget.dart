import 'package:flutter/material.dart';
import 'streaming_message_handler.dart';

/// Example widget that displays a streaming AI message with real-time updates
class StreamingMessageWidget extends StatelessWidget {
  final StreamingMessageHandler handler;
  final TextStyle? textStyle;
  final bool showToolCalls;
  final bool showStatus;

  const StreamingMessageWidget({
    super.key,
    required this.handler,
    this.textStyle,
    this.showToolCalls = true,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StreamingMessageState>(
      stream: handler.stateStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final state = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator (e.g., "Thinking...", "Analyzing...")
            if (showStatus && state.hasStatus)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
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
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Tool calls indicator
            if (showToolCalls && state.hasToolCalls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: state.toolCalls.map((tool) {
                    return Chip(
                      avatar: Icon(
                        _getToolIcon(tool.name),
                        size: 16,
                      ),
                      label: Text(
                        tool.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue[50],
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ),

            // KICD certification badge
            if (state.isKicdCertified)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'KICD Certified',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Main content
            if (state.content.isNotEmpty)
              SelectableText(
                state.content,
                style: textStyle ??
                    const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
              ),

            // Streaming indicator (cursor)
            if (state.isStreaming && state.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: _BlinkingCursor(),
              ),

            // Error message
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage ?? 'An error occurred',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _getToolIcon(String toolName) {
    switch (toolName) {
      case 'kec_search_tool':
      case 'retrieve_knowledge':
        return Icons.school;
      case 'serpapi_web_search_tool':
      case 'deep_research':
        return Icons.search;
      case 'graphing_tool':
      case 'math_graphing_tool':
      case 'interactive_graphing_tool':
        return Icons.show_chart;
      case 'generate_educational_diagram':
      case 'create_geometry_diagram':
        return Icons.draw;
      case 'generate_study_quiz_tool':
        return Icons.quiz;
      case 'generate_study_flashcards_tool':
        return Icons.style;
      case 'serpapi_image_search_tool':
        return Icons.image_search;
      default:
        return Icons.build;
    }
  }
}

/// Blinking cursor to indicate streaming is in progress
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
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
        width: 8,
        height: 16,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// Example usage in a chat screen
class ChatMessageExample extends StatefulWidget {
  final String messageId;
  final StreamingMessageManager streamingManager;

  const ChatMessageExample({
    super.key,
    required this.messageId,
    required this.streamingManager,
  });

  @override
  State<ChatMessageExample> createState() => _ChatMessageExampleState();
}

class _ChatMessageExampleState extends State<ChatMessageExample> {
  late StreamingMessageHandler _handler;

  @override
  void initState() {
    super.initState();
    _handler = widget.streamingManager.getHandler(widget.messageId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamingMessageWidget(
        handler: _handler,
        showToolCalls: true,
        showStatus: true,
      ),
    );
  }
}
