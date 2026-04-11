import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GradingResult {
  final String grading;

  GradingResult({required this.grading});

  factory GradingResult.fromJson(Map<String, dynamic> json) {
    return GradingResult(
      grading: json['grading'] as String,
    );
  }
}

class CompositionService {
  static Future<GradingResult> gradeComposition({
    required String text,
    required String studentId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.gradeComposition),
        body: {
          'text': text,
          'student_id': studentId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GradingResult.fromJson(data);
      } else {
        throw Exception('Failed to grade composition: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Grading service error: $e');
    }
  }
}
