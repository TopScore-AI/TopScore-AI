/// Quick WebSocket test for the TutorAgent server (Flutter/Dart version)
///
/// Run with: dart test/websocket_test.dart
/// Or: flutter test test/websocket_test.dart
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

void _log(String msg) => stdout.writeln(msg);

Future<void> testWebSocket() async {
  final sessionId = const Uuid().v4();
  final threadId = const Uuid().v4();
  final url = 'ws://localhost:8080/ws/chat/$sessionId';

  _log('Connecting to $url ...');

  try {
    final ws = await WebSocket.connect(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Connection timeout');
      },
    );

    _log('Connected! Listening for messages...\n');

    String fullResponse = '';
    int chunkCount = 0;
    const maxChunks = 50;
    bool handshakeReceived = false;

    // Listen to all messages in a single subscription
    await for (final message in ws) {
      if (chunkCount >= maxChunks) {
        _log('  ⚠️  Max chunks ($maxChunks) reached, stopping...');
        break;
      }

      try {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final msgType = data['type'] ?? 'unknown';

        // 1. Handle handshake first
        if (!handshakeReceived && msgType == 'connected') {
          _log(
              '✅ Handshake: ${const JsonEncoder.withIndent('  ').convert(data)}\n');
          handshakeReceived = true;

          // 2. Send test message after handshake
          final payload = {
            'type': 'message',
            'user_id': 'test_user_001',
            'message': 'What is 2 + 2? Answer in one sentence.',
            'thread_id': threadId,
            'model_preference': 'fast',
          };

          _log(
              '📤 Sending: ${const JsonEncoder.withIndent('  ').convert(payload)}\n');
          ws.add(jsonEncode(payload));
          _log('📥 Receiving response:');
          continue;
        }

        switch (msgType) {
          case 'chunk':
            final content = data['content']?.toString() ?? '';
            fullResponse += content;
            final preview = content.length > 120
                ? '${content.substring(0, 120)}...'
                : content;
            _log('  [chunk] $preview');
            break;

          case 'done':
          case 'complete':
          case 'end':
            final responseId = data['id'] ?? 'N/A';
            _log('  [done] ✅ Response complete. ID: $responseId');

            // Check for final content in done message
            if (data.containsKey('content')) {
              final finalContent = data['content']?.toString() ?? '';
              if (finalContent.isNotEmpty) {
                fullResponse = finalContent;
              }
            }

            await ws.close();
            break;

          case 'error':
            final errorMsg = data['message'] ?? data.toString();
            _log('  [error] ❌ $errorMsg');
            await ws.close();
            break;

          case 'status':
            final status = data['status'] ?? '';
            _log('  [status] 📊 $status');
            break;

          case 'response_start':
            final msgId = data['id'] ?? '';
            _log('  [response_start] 🚀 Starting message: $msgId');
            break;

          case 'ping':
            // Respond to ping
            ws.add(jsonEncode({'type': 'pong'}));
            _log('  [ping] 🏓 Sent pong');
            break;

          default:
            final preview = const JsonEncoder().convert(data);
            final shortPreview = preview.length > 150
                ? '${preview.substring(0, 150)}...'
                : preview;
            _log('  [$msgType] $shortPreview');
        }

        chunkCount++;

        // Break if connection was closed by done/error handlers
        if (msgType == 'done' ||
            msgType == 'complete' ||
            msgType == 'end' ||
            msgType == 'error') {
          break;
        }
      } on FormatException catch (e) {
        _log('  [parse error] Failed to parse message: $e');
      }
    }

    if (fullResponse.isNotEmpty) {
      final preview = fullResponse.length > 500
          ? '${fullResponse.substring(0, 500)}...'
          : fullResponse;
      _log('\n📝 Full AI response:\n$preview');
    } else {
      _log('\n⚠️  No response content received');
    }

    await ws.close();
    _log('\n🔌 Test complete.');
  } on TimeoutException catch (e) {
    _log('\n❌ Timeout: $e');
    exit(1);
  } on WebSocketException catch (e) {
    _log('\n❌ WebSocket Error: $e');
    exit(1);
  } catch (e) {
    _log('\n❌ Error: ${e.runtimeType}: $e');
    exit(1);
  }
}

void main() async {
  _log('=== Flutter WebSocket Test for TutorAgent ===\n');
  await testWebSocket();
}
