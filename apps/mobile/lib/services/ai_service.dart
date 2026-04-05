import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Added firebase_auth
import '../config/api_config.dart';
import '../models/flashcard_model.dart';
import '../models/quiz_model.dart';
import 'auth_headers.dart';

// Data models for structured responses
class AIResponse {
  final String text;
  final VisualizationType? visualizationType;
  final dynamic visualizationData;

  AIResponse({
    required this.text,
    this.visualizationType,
    this.visualizationData,
  });
}

enum VisualizationType {
  diagram,
  mathEquation,
  stepByStep,
  comparison,
  timeline,
  chart,
}

class VisualExample {
  final String title;
  final String description;
  final List<String> steps;
  final Map<String, dynamic>? data;

  VisualExample({
    required this.title,
    required this.description,
    this.steps = const [],
    this.data,
  });

  factory VisualExample.fromJson(Map<String, dynamic> json) {
    return VisualExample(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      steps: List<String>.from(json['steps'] ?? []),
      data: json['data'],
    );
  }
}

class AIService {
  static const _uuid = Uuid();

  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  AIService() {
    // Lazy connection: don't connect in constructor to avoid redundant errors
    // when only HTTP methods like generateFlashcards are used.
  }

  Future<void> _connect() async {
    if (_isConnecting || (_channel != null && _channel!.closeCode == null)) return;
    _isConnecting = true;

    try {
      _streamSubscription?.cancel();
      _channel?.sink.close();
      _channel = null;

      // Fetch Firebase Token for Handshake
      final user = FirebaseAuth.instance.currentUser;
      String? idToken;
      if (user != null) {
        try {
          idToken = await user.getIdToken(false);
        } catch (e) {
          if (kDebugMode) debugPrint('AIService: Failed to get auth token: $e');
        }
      }

      final wsUrl = ApiConfig.wsUrl;
      final uri = Uri.parse(wsUrl);
      
      _channel = WebSocketChannel.connect(uri);
      _reconnectAttempts = 0;

      // Send Handshake only if we have a token
      if (idToken != null) {
        final handshakePayload = {
          "type": "init",
          "auth_token": idToken,
        };
        _channel!.sink.add(jsonEncode(handshakePayload));
        if (kDebugMode) debugPrint('🤝 AIService: Handshake payload sent');
      } else {
        if (kDebugMode) debugPrint('🤝 AIService: Connected as guest (no handshake)');
      }

      _streamSubscription = _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          if (kDebugMode) debugPrint('WebSocket error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          if (kDebugMode) debugPrint('WebSocket closed');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error connecting to WebSocket: $e');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _onMessage(dynamic rawMessage) {
    try {
      final data = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      
      // Ignore system messages from handshake
      if (data['type'] == 'system') return;
      
      final requestId = data['request_id'] as String?;

      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        _pendingRequests[requestId]!.complete(data);
        _pendingRequests.remove(requestId);
      } else if (_pendingRequests.length == 1) {
        // Fallback: if server doesn't echo request_id, complete the single pending request
        final entry = _pendingRequests.entries.first;
        entry.value.complete(data);
        _pendingRequests.remove(entry.key);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) debugPrint('Max reconnect attempts reached');
      // Fail all pending requests
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.completeError('Connection lost after $_maxReconnectAttempts attempts');
        }
      }
      _pendingRequests.clear();
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2); // Linear backoff
    if (kDebugMode) debugPrint('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    Future.delayed(delay, _connect);
  }

  Future<AIResponse> sendMessage(
    String message, {
    Map<String, dynamic>? context,
    Uint8List? attachmentBytes,
    String? mimeType,
  }) async {
    try {
      if (_channel == null) _connect();

      final requestId = _uuid.v4();
      final completer = Completer<Map<String, dynamic>>();
      _pendingRequests[requestId] = completer;

      final Map<String, dynamic> payload = {
        'type': 'message',
        'request_id': requestId,
        'content': message,
      };

      if (context != null) {
        payload['context'] = context;
      }

      if (attachmentBytes != null) {
        payload['attachment'] = base64Encode(attachmentBytes);
        payload['mimeType'] = mimeType ?? 'image/jpeg';
      }

      _channel!.sink.add(jsonEncode(payload));

      final data = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pendingRequests.remove(requestId);
          throw TimeoutException('AI response timed out');
        },
      );

      final responseText = data['text'] ??
          "I'm having trouble thinking right now. Can you ask again?";

      return _parseResponseWithVisualization(responseText);
    } catch (e) {
      if (kDebugMode) debugPrint('Error in sendMessage: $e');
      return AIResponse(
        text: "Oh no! My connection is a bit shaky. Please try again. ($e)",
      );
    }
  }

  // Request specific visualization for a concept
  Future<VisualExample> requestVisualization(
    String concept, {
    required String subject,
    required int grade,
  }) async {
    try {
      final prompt = """
Create a visual example for: $concept
Subject: $subject, Grade: $grade

Provide response in this format:
TITLE: [Short title]
DESCRIPTION: [Brief explanation]
STEPS:
1. [First step]
2. [Second step]
3. [Third step]
DATA: [Any numbers, values, or key facts in simple format]
""";

      final response = await sendMessage(prompt);
      return _parseVisualExample(response.text, concept);
    } catch (e) {
      if (kDebugMode) debugPrint('Error in requestVisualization: $e');
      return VisualExample(
        title: concept,
        description: "Let's explore this concept together!",
      );
    }
  }

  // Get examples with diagrams
  Future<List<VisualExample>> getExamplesWithDiagrams(
    String topic, {
    required int count,
    required String subject,
  }) async {
    try {
      final prompt = """
Give me $count visual examples for: $topic (Subject: $subject)

For each example, provide:
- A title
- Simple explanation
- Step-by-step breakdown
- Use Kenyan context (matatus, M-Pesa, ugali, football, etc.)

Make it fun and easy to visualize!
""";

      final response = await sendMessage(prompt);
      return _parseMultipleExamples(response.text);
    } catch (e) {
      if (kDebugMode) debugPrint('Error in getExamplesWithDiagrams: $e');
      return [];
    }
  }

  Future<String> analyzeImage(Uint8List imageBytes, String prompt) async {
    try {
      final response = await sendMessage(
        prompt,
        attachmentBytes: imageBytes,
        mimeType: 'image/jpeg',
      );
      return response.text;
    } catch (e) {
      return "Error analyzing image: $e";
    }
  }

  AIResponse _parseResponseWithVisualization(String responseText) {
    if (responseText.contains('[DIAGRAM:')) {
      final match = RegExp(r'\[DIAGRAM: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.diagram,
          visualizationData: match.group(1),
        );
      }
    }

    if (responseText.contains('[STEPS:')) {
      final match = RegExp(r'\[STEPS: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        final steps = match
            .group(1)!
            .split(RegExp(r'\d+\.'))
            .where((s) => s.trim().isNotEmpty)
            .toList();
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.stepByStep,
          visualizationData: steps,
        );
      }
    }

    if (responseText.contains('[MATH:')) {
      final match = RegExp(r'\[MATH: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.mathEquation,
          visualizationData: match.group(1),
        );
      }
    }

    if (responseText.contains('[COMPARE:')) {
      final match = RegExp(r'\[COMPARE: ([^\]]+)\]').firstMatch(responseText);
      if (match != null) {
        return AIResponse(
          text: responseText.replaceAll(match.group(0)!, '').trim(),
          visualizationType: VisualizationType.comparison,
          visualizationData: match.group(1),
        );
      }
    }

    return AIResponse(text: responseText);
  }

  VisualExample _parseVisualExample(String responseText, String fallbackTitle) {
    final titleMatch = RegExp(r'TITLE: (.+)').firstMatch(responseText);
    final descMatch = RegExp(r'DESCRIPTION: (.+)').firstMatch(responseText);
    final stepsMatch = RegExp(
      r'STEPS:([\s\S]+?)(?=DATA:|$)',
    ).firstMatch(responseText);

    final steps = <String>[];
    if (stepsMatch != null) {
      final stepsText = stepsMatch.group(1)!;
      steps.addAll(
        stepsText
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
            .toList(),
      );
    }

    return VisualExample(
      title: titleMatch?.group(1)?.trim() ?? fallbackTitle,
      description: descMatch?.group(1)?.trim() ?? '',
      steps: steps,
    );
  }

  List<VisualExample> _parseMultipleExamples(String responseText) {
    final examples = <VisualExample>[];
    final sections = responseText.split(RegExp(r'Example \d+:|##'));

    for (var section in sections) {
      if (section.trim().isEmpty) continue;

      final lines =
          section.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;

      final title = lines.first.replaceAll(RegExp(r'^\*+\s*'), '').trim();
      final description = lines.length > 1 ? lines[1].trim() : '';
      final steps = lines
          .skip(2)
          .map((l) => l.replaceAll(RegExp(r'^\d+\.\s*[-â€¢]\s*'), '').trim())
          .toList();

      examples.add(
        VisualExample(title: title, description: description, steps: steps),
      );
    }

    return examples;
  }

  // Reset chat session
  void resetChat() {
    _pendingRequests.clear();
    _channel?.sink.close();
    _connect();
  }

  /// Map user-visible levels to curriculum/grade specs
  static Map<String, String> mapLevelToSpecs(String level) {
    if (level.contains('Primary') || level.contains('Grade')) {
      return {'curriculum': 'CBC', 'grade': level};
    } else if (level.contains('Form') || level.contains('844') || level.contains('KCSE')) {
      return {'curriculum': '844', 'grade': level};
    } else if (level.contains('Year') || level.contains('International') || level.contains('IGCSE')) {
      return {'curriculum': 'Cambridge IGCSE', 'grade': level};
    } else {
      return {'curriculum': 'General', 'grade': level};
    }
  }

  /// Generate AI-powered flashcards using the refined /api/study namespace
  Future<FlashcardSet> generateFlashcards({
    required String userId,
    required String topic,
    int amount = 5,
    required String curriculum,
    required String grade,
    String? sourceText,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/study/flashcards');

    final payload = {
      'curriculum': curriculum,
      'grade': grade,
      'topic': topic,
      'item_count': amount,
      if (sourceText != null && sourceText.isNotEmpty)
        'source_text': sourceText,
    };

    try {
      final headers = await AuthHeaders.getHeaders({'Content-Type': 'application/json'});
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FlashcardSet.fromJson(data);
      } else {
        throw Exception('Flashcard generation failed: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating flashcards: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  /// Generate an AI-powered quiz using the refined /api/study namespace
  Future<Quiz> generateQuiz({
    required String userId,
    required String topic,
    int questionCount = 5,
    required String curriculum,
    required String grade,
    String difficulty = 'Medium',
    String? sourceText,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/study/quiz');

    final payload = {
      'curriculum': curriculum,
      'grade': grade,
      'topic': topic,
      'item_count': questionCount,
      'difficulty': difficulty,
      if (sourceText != null && sourceText.isNotEmpty)
        'source_text': sourceText,
    };

    try {
      final headers = await AuthHeaders.getHeaders({'Content-Type': 'application/json'});
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Quiz.fromJson(data);
      } else {
        throw Exception('Quiz generation failed: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating quiz: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  /// Analyze a homework image using AI Vision
  Future<String> analyzeHomework(Uint8List imageBytes) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/study/analyze-homework');
    
    try {
      final headers = await AuthHeaders.getHeaders({});
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          imageBytes, 
          filename: 'homework_${DateTime.now().millisecondsSinceEpoch}.jpg'
        )
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['analysis'] ?? "No analysis returned.";
      } else {
        throw Exception("Homework analysis failed: ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in analyzeHomework: $e');
      return "Analysis failed. Please try again. ($e)";
    }
  }

  /// Summarize a PDF using Multimodal Vision (High Fidelity)
  Future<String> summarizePdfVision({
    required Uint8List pdfBytes,
    required String filename,
    String readingLevel = 'Form 4 student',
    String summaryType = 'detailed_bullet_points',
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/study/summarize-pdf-vision');

    try {
      final headers = await AuthHeaders.getHeaders({});
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          pdfBytes,
          filename: filename,
        ),
      );

      request.fields['reading_level'] = readingLevel;
      request.fields['summary_type'] = summaryType;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['summary'] ?? "No summary returned.";
      } else {
        throw Exception("PDF Vision processing failed: ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in summarizePdfVision: $e');
      throw Exception("AI processing failed. Please ensure the backend is active. ($e)");
    }
  }

  /// Generate an AI summary for a specific topic
  Future<String> summarizeTopic({
    required String topic,
    String level = 'High School',
    String format = 'detailed_bullet_points',
  }) async {
    final prompt = """
Generate a comprehensive, high-quality executive summary for the topic: $topic.
Audience: $level
Format: $format

Use Markdown formatting. Include:
1. Core Concepts (briefly explained)
2. Key Facts or Formulas
3. Summary of why this topic is important

Ensure the tone is educational and encouraging.
""";

    try {
      final response = await sendMessage(prompt);
      return response.text;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in summarizeTopic: $e');
      throw Exception('Failed to generate summary: $e');
    }
  }

  void dispose() {
    _streamSubscription?.cancel();
    _channel?.sink.close();
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('AIService disposed');
      }
    }
    _pendingRequests.clear();
  }
}
