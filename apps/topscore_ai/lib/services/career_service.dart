import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/grade_model.dart';

class CareerService {
  // Mock Data conforming to Kenyan High School grading
  List<GradeModel> getMockGrades() {
    return [
      GradeModel(
        subject: 'Mathematics',
        percentage: 85,
        grade: 'A',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'English',
        percentage: 78,
        grade: 'A-',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Kiswahili',
        percentage: 72,
        grade: 'B+',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Physics',
        percentage: 88,
        grade: 'A',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Chemistry',
        percentage: 65,
        grade: 'B',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Biology',
        percentage: 82,
        grade: 'A-',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'History',
        percentage: 55,
        grade: 'C',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Geography',
        percentage: 60,
        grade: 'B-',
        term: 'Term 3',
      ),
    ];
  }

  Future<String> analyzePerformance(List<GradeModel> grades) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/career/analyze');

      final gradesData = grades
          .map((g) => {
                'subject': g.subject,
                'percentage': g.percentage,
                'grade': g.grade,
                'term': g.term,
              })
          .toList();

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'grades': gradesData}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['analysis'] ?? 'Unable to analyze grades.';
      } else {
        if (kDebugMode) debugPrint('Career analyze API error: ${response.statusCode}');
        return 'Error: Unable to analyze performance. Please try again.';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error analyzing performance: $e');
      return 'Error analyzing performance: $e';
    }
  }

  Future<String> generateRoadmap(String careerInterest) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/career/roadmap');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'career': careerInterest}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['roadmap'] ?? 'Unable to generate roadmap.';
      } else {
        if (kDebugMode) debugPrint('Career roadmap API error: ${response.statusCode}');
        return 'Error: Unable to generate roadmap. Please try again.';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating roadmap: $e');
      return 'Error generating roadmap: $e';
    }
  }
}
