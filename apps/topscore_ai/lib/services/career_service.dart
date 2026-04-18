import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_headers.dart';

class CareerService {
  /// Analyzes user interests and returns suggested career paths.
  /// POST /career/analyze
  Future<List<Map<String, dynamic>>> analyzeInterests(List<String> interests) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/career/analyze');
    
    try {
      final headers = await AuthHeaders.getHeaders({'Content-Type': 'application/json'});
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'interests': interests}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['careers'] ?? []);
      } else {
        throw Exception('Career analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to career service: $e');
    }
  }

  /// Generates a detailed roadmap for a specific career path.
  /// POST /career/roadmap
  Future<Map<String, dynamic>> getRoadmap(String career) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/career/roadmap');
    
    try {
      final headers = await AuthHeaders.getHeaders({'Content-Type': 'application/json'});
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'career': career}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Roadmap generation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to career service: $e');
    }
  }
}
