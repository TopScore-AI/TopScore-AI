import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_headers.dart';

class StudyPlanService {
  /// Generates a personalized study plan for the user.
  /// POST /api/study-plan/generate
  Future<Map<String, dynamic>> generateStudyPlan({
    required List<String> subjects,
    required String goal,
    int? days,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/api/study-plan/generate');
    
    try {
      final headers = await AuthHeaders.getHeaders({'Content-Type': 'application/json'});
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'subjects': subjects,
          'goal': goal,
          if (days != null) 'days': days,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Study plan generation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating study plan: $e');
    }
  }

  /// Fetches the currently active study plan for the user.
  /// GET /api/study-plan/active
  Future<Map<String, dynamic>?> getActiveStudyPlan() async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/api/study-plan/active');
    
    try {
      final headers = await AuthHeaders.getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to fetch active study plan: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching study plan: $e');
    }
  }

  /// Checks in for today's study task.
  /// POST /api/study-plan/check-in
  Future<void> checkIn(String taskId) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/api/study-plan/check-in');
    
    try {
      final headers = await AuthHeaders.getHeaders({'Content-Type': 'application/json'});
      await http.post(
        url,
        headers: headers,
        body: jsonEncode({'task_id': taskId}),
      );
    } catch (e) {
      throw Exception('Check-in failed: $e');
    }
  }
}
