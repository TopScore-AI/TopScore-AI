import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_headers.dart';

class UsageModel {
  final int used;
  final int limit;
  final int remaining;

  UsageModel(
      {required this.used, required this.limit, required this.remaining});

  factory UsageModel.fromJson(Map<String, dynamic> json) {
    final limit = json['limit'] as int? ?? 6;
    final used = json['used'] as int? ?? 0;
    // Default remaining to full limit — never assume 0 on missing data
    final remaining = json['remaining'] as int? ?? (limit - used);
    return UsageModel(used: used, limit: limit, remaining: remaining);
  }

  /// Default empty usage
  factory UsageModel.empty() => UsageModel(used: 0, limit: 6, remaining: 6);
}

class UsageService {
  /// Fetches the current message usage from the backend.
  static Future<UsageModel?> fetchUsage() async {
    try {
      final headers = await AuthHeaders.getHeaders();
      final url = Uri.parse('${AppConfig.backendBaseUrl}/usage');

      if (kDebugMode) debugPrint('Fetching usage from: $url');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UsageModel.fromJson(data);
      } else {
        if (kDebugMode) {
          debugPrint(
              'Usage: Failed to fetch (Status ${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Usage: Error fetching usage: $e');
    }
    return null;
  }
}
