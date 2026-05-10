import 'dart:async';
import 'package:flutter/foundation.dart';

/// Handles streaming AI responses by accumulating chunks and managing state
class StreamingMessageHandler {
  final String messageId;
  final StreamController<StreamingMessageState> _stateController =
      StreamController.broadcast();

  String _accumulatedContent = '';
  String _currentStatus = '';
  bool _isComplete = false;
  bool _hasError = false;
  String? _errorMessage;
  final List<ToolCall> _toolCalls = [];
  final List<String> _tables = [];
  bool _isKicdCertified = false;

  StreamingMessageHandler({required this.messageId});

  /// Stream of state updates for this message
  Stream<StreamingMessageState> get stateStream => _stateController.stream;

  /// Current accumulated content
  String get content => _accumulatedContent;

  /// Current status message
  String get status => _currentStatus;

  /// Whether the stream is complete
  bool get isComplete => _isComplete;

  /// Whether an error occurred
  bool get hasError => _hasError;

  /// Error message if any
  String? get errorMessage => _errorMessage;

  /// List of tool calls made during this response
  List<ToolCall> get toolCalls => List.unmodifiable(_toolCalls);

  /// List of tables in this response
  List<String> get tables => List.unmodifiable(_tables);

  /// Whether this response is KICD certified
  bool get isKicdCertified => _isKicdCertified;

  /// Handle an incoming WebSocket message for this streaming response
  void handleMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'response_start':
        _emitState();
        break;

      case 'chunk':
        final content = data['content'] as String? ?? '';
        _accumulatedContent += content;
        _emitState();
        break;

      case 'table':
        final tableContent = data['content'] as String? ?? '';
        _tables.add(tableContent);
        _accumulatedContent += '\n$tableContent\n';
        _emitState();
        break;

      case 'tool_call':
        final toolName = data['tool'] as String? ?? 'unknown';
        final toolInput = data['input'] as Map<String, dynamic>? ?? {};
        _toolCalls.add(ToolCall(name: toolName, input: toolInput));
        _emitState();
        break;

      case 'status':
        _currentStatus = data['content'] as String? ?? '';
        _emitState();
        break;

      case 'is_kicd_certified':
        _isKicdCertified = data['value'] as bool? ?? false;
        _emitState();
        break;

      case 'done':
        _isComplete = true;
        _currentStatus = '';
        // If full_response is provided, use it as the final content
        if (data.containsKey('full_response')) {
          _accumulatedContent = data['full_response'] as String;
        }
        _emitState();
        break;

      case 'error':
        _hasError = true;
        _errorMessage = data['content'] as String? ?? 'Unknown error';
        _isComplete = true;
        _emitState();
        break;
    }
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(StreamingMessageState(
        messageId: messageId,
        content: _accumulatedContent,
        status: _currentStatus,
        isComplete: _isComplete,
        hasError: _hasError,
        errorMessage: _errorMessage,
        toolCalls: _toolCalls,
        tables: _tables,
        isKicdCertified: _isKicdCertified,
      ));
    }
  }

  void dispose() {
    _stateController.close();
  }
}

/// Immutable state snapshot of a streaming message
class StreamingMessageState {
  final String messageId;
  final String content;
  final String status;
  final bool isComplete;
  final bool hasError;
  final String? errorMessage;
  final List<ToolCall> toolCalls;
  final List<String> tables;
  final bool isKicdCertified;

  const StreamingMessageState({
    required this.messageId,
    required this.content,
    required this.status,
    required this.isComplete,
    required this.hasError,
    this.errorMessage,
    required this.toolCalls,
    required this.tables,
    required this.isKicdCertified,
  });

  /// Whether the AI is currently generating content
  bool get isStreaming => !isComplete && !hasError;

  /// Whether to show a status indicator
  bool get hasStatus => status.isNotEmpty;

  /// Whether any tools were called
  bool get hasToolCalls => toolCalls.isNotEmpty;

  /// Whether any tables were generated
  bool get hasTables => tables.isNotEmpty;
}

/// Represents a tool call made by the AI
class ToolCall {
  final String name;
  final Map<String, dynamic> input;

  const ToolCall({
    required this.name,
    required this.input,
  });

  /// Get a human-readable description of this tool call
  String get description {
    switch (name) {
      case 'kec_search_tool':
      case 'retrieve_knowledge':
        return 'Searching curriculum resources...';
      case 'serpapi_web_search_tool':
      case 'deep_research':
        return 'Searching the web...';
      case 'graphing_tool':
      case 'math_graphing_tool':
      case 'interactive_graphing_tool':
        return 'Creating graph...';
      case 'generate_educational_diagram':
        return 'Generating diagram...';
      case 'create_geometry_diagram':
        return 'Creating geometry diagram...';
      case 'generate_study_quiz_tool':
        return 'Generating quiz...';
      case 'generate_study_flashcards_tool':
        return 'Creating flashcards...';
      case 'serpapi_image_search_tool':
        return 'Finding educational images...';
      default:
        return 'Using $name...';
    }
  }
}

/// Manager for multiple concurrent streaming messages
class StreamingMessageManager {
  final Map<String, StreamingMessageHandler> _handlers = {};
  final StreamController<String> _completedMessagesController =
      StreamController.broadcast();

  /// Stream of completed message IDs
  Stream<String> get completedMessages => _completedMessagesController.stream;

  /// Get or create a handler for a message ID
  StreamingMessageHandler getHandler(String messageId) {
    return _handlers.putIfAbsent(
      messageId,
      () => StreamingMessageHandler(messageId: messageId),
    );
  }

  /// Handle an incoming WebSocket message
  void handleMessage(Map<String, dynamic> data) {
    final messageId = data['id'] as String?;
    if (messageId == null) {
      if (kDebugMode) {
        debugPrint(
            'StreamingMessageManager: Message without ID: ${data['type']}');
      }
      return;
    }

    final handler = getHandler(messageId);
    handler.handleMessage(data);

    // Clean up completed handlers
    if (handler.isComplete) {
      _completedMessagesController.add(messageId);
      // Keep handler around for a bit in case UI needs final state
      Future.delayed(const Duration(seconds: 5), () {
        _handlers.remove(messageId);
        handler.dispose();
      });
    }
  }

  /// Get the current state of a message
  StreamingMessageState? getState(String messageId) {
    final handler = _handlers[messageId];
    if (handler == null) return null;

    return StreamingMessageState(
      messageId: messageId,
      content: handler.content,
      status: handler.status,
      isComplete: handler.isComplete,
      hasError: handler.hasError,
      errorMessage: handler.errorMessage,
      toolCalls: handler.toolCalls,
      tables: handler.tables,
      isKicdCertified: handler.isKicdCertified,
    );
  }

  /// Clean up a specific handler
  void removeHandler(String messageId) {
    final handler = _handlers.remove(messageId);
    handler?.dispose();
  }

  /// Clean up all handlers
  void dispose() {
    for (final handler in _handlers.values) {
      handler.dispose();
    }
    _handlers.clear();
    _completedMessagesController.close();
  }
}
