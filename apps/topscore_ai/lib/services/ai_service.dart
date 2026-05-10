import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/flashcard_model.dart';
import '../models/quiz_model.dart';
import 'auth_headers.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class AIResponse {
  final String text;
  final VisualizationType? visualizationType;
  final dynamic visualizationData;

  AIResponse(
      {required this.text, this.visualizationType, this.visualizationData});
}

enum VisualizationType {
  diagram,
  mathEquation,
  stepByStep,
  comparison,
  timeline,
  chart
}

class VisualExample {
  final String title;
  final String description;
  final List<String> steps;
  final Map<String, dynamic>? data;

  const VisualExample({
    required this.title,
    required this.description,
    this.steps = const [],
    this.data,
  });

  factory VisualExample.fromJson(Map<String, dynamic> json) => VisualExample(
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        steps: List<String>.from(json['steps'] as List? ?? []),
        data: json['data'] as Map<String, dynamic>?,
      );
}

// ---------------------------------------------------------------------------
// AIService — HTTP-only.
//
// All real-time chat goes through EnhancedWebSocketService (one connection).
// This service handles stateless tool calls only: PDF summarization,
// flashcard/quiz generation, homework analysis, document conversion, and
// PDF chat sessions.
// ---------------------------------------------------------------------------

class AIService {
  // Internal HTTP POST helper
  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}$path');
    final headers =
        await AuthHeaders.getHeaders(existingHeaders: {'Content-Type': 'application/json'});
    final response =
        await http.post(url, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('$path failed (${response.statusCode}): ${response.body}');
  }

  // ---------------------------------------------------------------------------
  // Tool APIs
  // ---------------------------------------------------------------------------

  /// POST /api/study/flashcards
  Future<FlashcardSet> generateFlashcards({
    required String userId,
    required String topic,
    int amount = 5,
    required String curriculum,
    required String grade,
    String? sourceText,
  }) async {
    final data = await _post('/api/study/flashcards', {
      'curriculum': curriculum,
      'grade': grade,
      'topic': topic,
      'item_count': amount,
      if (sourceText != null && sourceText.isNotEmpty)
        'source_text': sourceText,
    });
    return FlashcardSet.fromJson(data);
  }

  /// POST /api/study/flashcards-from-file (multipart)
  Future<FlashcardSet> generateFlashcardsFromFile({
    required Uint8List pdfBytes,
    required String filename,
    String curriculum = 'General',
    String grade = 'General',
    int amount = 5,
  }) async {
    final url =
        Uri.parse('${AppConfig.backendBaseUrl}/api/study/flashcards-from-file');
    final headers = await AuthHeaders.getHeaders(existingHeaders: {});
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..files.add(
          http.MultipartFile.fromBytes('file', pdfBytes, filename: filename))
      ..fields['curriculum'] = curriculum
      ..fields['grade'] = grade
      ..fields['item_count'] = amount.toString();

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return FlashcardSet.fromJson(decoded);
    }
    throw Exception(
        'Flashcard generation from file failed (${response.statusCode}): ${response.body}');
  }

  /// POST /api/study/quiz
  Future<Quiz> generateQuiz({
    required String userId,
    required String topic,
    int questionCount = 5,
    required String curriculum,
    required String grade,
    String difficulty = 'Medium',
    String? sourceText,
  }) async {
    final data = await _post('/api/study/quiz', {
      'curriculum': curriculum,
      'grade': grade,
      'topic': topic,
      'item_count': questionCount,
      'difficulty': difficulty,
      if (sourceText != null && sourceText.isNotEmpty)
        'source_text': sourceText,
    });
    return Quiz.fromJson(data);
  }

  /// POST /api/study/summarize-pdf-vision (multipart)
  Future<String> summarizePdfVision({
    required Uint8List pdfBytes,
    required String filename,
    String readingLevel = 'Form 4 student',
    String summaryType = 'detailed_bullet_points',
  }) async {
    final url =
        Uri.parse('${AppConfig.backendBaseUrl}/api/study/summarize-pdf-vision');
    final headers = await AuthHeaders.getHeaders(existingHeaders: {});
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..files.add(
          http.MultipartFile.fromBytes('file', pdfBytes, filename: filename))
      ..fields['reading_level'] = readingLevel
      ..fields['summary_type'] = summaryType;

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) {
      return (jsonDecode(utf8.decode(response.bodyBytes))['summary']
              as String?) ??
          'No summary returned.';
    }
    throw Exception(
        'PDF Vision failed (${response.statusCode}): ${response.body}');
  }

  /// POST /api/study/analyze-homework (multipart)
  Future<String> analyzeHomework(Uint8List imageBytes) async {
    final url =
        Uri.parse('${AppConfig.backendBaseUrl}/api/study/analyze-homework');
    final headers = await AuthHeaders.getHeaders(existingHeaders: {});
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'homework_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['analysis'] as String?) ??
          'No analysis returned.';
    }
    return 'Analysis failed (${response.statusCode}). Please try again.';
  }

  /// POST /documents/convert-from-url
  Future<Uint8List> convertToPdf(String fileUrl) async {
    final url =
        Uri.parse('${AppConfig.backendBaseUrl}/documents/convert-from-url');
    final headers =
        await AuthHeaders.getHeaders(existingHeaders: {'Content-Type': 'application/json'});
    final response = await http.post(url,
        headers: headers, body: jsonEncode({'url': fileUrl}));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception(
        'Conversion failed (${response.statusCode}): ${response.body}');
  }

  /// POST /api/study/grade-composition
  Future<Map<String, dynamic>> gradeComposition({
    required String text,
    String? title,
    String? subject,
    String? gradeLevel,
  }) async {
    return _post('/api/study/grade-composition', {
      'text': text,
      if (title != null) 'title': title,
      if (subject != null) 'subject': subject,
      if (gradeLevel != null) 'grade_level': gradeLevel,
    });
  }

  // ---------------------------------------------------------------------------
  // PDF Chat Session APIs
  // ---------------------------------------------------------------------------

  /// POST /pdf-chat/start-session (multipart)
  Future<String> startPdfSession(Uint8List pdfBytes, String filename) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/pdf-chat/start-session');
    final headers = await AuthHeaders.getHeaders(existingHeaders: {});
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..files.add(
          http.MultipartFile.fromBytes('file', pdfBytes, filename: filename));

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['thread_id'] ?? data['session_id']) as String;
    }
    throw Exception(
        'Failed to start PDF session (${response.statusCode}): ${response.body}');
  }

  /// POST /pdf-chat/message
  Future<AIResponse> sendPdfMessage(String threadId, String message) async {
    final data = await _post(
        '/pdf-chat/message', {'thread_id': threadId, 'message': message});
    final text = (data['response'] ?? data['text'] ?? '') as String;
    return _parseResponseWithVisualization(text);
  }

  // ---------------------------------------------------------------------------
  // Flashcard CRUD APIs
  // ---------------------------------------------------------------------------

  Future<void> saveFlashcardSet(FlashcardSet set) async {
    await _post('/flashcards/save_set', set.toJson());
  }

  Future<void> updateFlashcardMastery(String cardId, int rating) async {
    try {
      await _post(
          '/flashcards/update_mastery', {'card_id': cardId, 'rating': rating});
    } catch (e) {
      if (kDebugMode) debugPrint('updateFlashcardMastery: $e');
    }
  }

  Future<List<FlashcardSet>> getDueFlashcards(String userId) async {
    final url =
        Uri.parse('${AppConfig.backendBaseUrl}/flashcards/due?user_id=$userId');
    try {
      final headers = await AuthHeaders.getHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List)
            .map((e) => FlashcardSet.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getDueFlashcards: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AIResponse _parseResponseWithVisualization(String text) {
    for (final entry in {
      '[DIAGRAM:': VisualizationType.diagram,
      '[STEPS:': VisualizationType.stepByStep,
      '[MATH:': VisualizationType.mathEquation,
      '[COMPARE:': VisualizationType.comparison,
    }.entries) {
      if (text.contains(entry.key)) {
        final tag = entry.key.replaceAll('[', r'\[');
        final match = RegExp('$tag ([^\\]]+)\\]').firstMatch(text);
        if (match != null) {
          return AIResponse(
            text: text.replaceAll(match.group(0)!, '').trim(),
            visualizationType: entry.value,
            visualizationData: entry.value == VisualizationType.stepByStep
                ? match
                    .group(1)!
                    .split(RegExp(r'\d+\.'))
                    .where((s) => s.trim().isNotEmpty)
                    .toList()
                : match.group(1),
          );
        }
      }
    }
    return AIResponse(text: text);
  }

  static Map<String, String> mapLevelToSpecs(String level) {
    if (level.contains('Primary') || level.contains('Grade')) {
      return {'curriculum': 'CBC', 'grade': level};
    }
    if (level.contains('Form') ||
        level.contains('844') ||
        level.contains('KCSE')) {
      return {'curriculum': '844', 'grade': level};
    }
    if (level.contains('Year') ||
        level.contains('International') ||
        level.contains('IGCSE')) {
      return {'curriculum': 'Cambridge IGCSE', 'grade': level};
    }
    return {'curriculum': 'General', 'grade': level};
  }
}
