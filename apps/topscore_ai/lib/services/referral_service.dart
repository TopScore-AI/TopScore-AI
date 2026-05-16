import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  /// Redeems a referral code for the current user.
  /// POST /api/referral/redeem
  Future<bool> redeemCode(String code) async {
    final auth = AuthProvider.instance;
    final user = auth.userModel;
    if (user == null) return false;

    try {
      final idToken = await auth.authService.auth.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/referral/redeem'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'code': code.trim().toUpperCase(),
          'user_id': user.uid,
        }),
      );

      if (response.statusCode == 200) {
        // Refresh user profile to reflect changes (e.g. bonus XP or subscription)
        await auth.refreshUser();
        return true;
      }

      if (kDebugMode) {
        debugPrint('Referral redemption failed: ${response.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error redeeming referral code: $e');
      return false;
    }
  }

  /// Gets the referral stats for the current user.
  /// GET /api/referral/stats
  Future<Map<String, dynamic>?> getStats() async {
    final auth = AuthProvider.instance;
    final user = auth.userModel;
    if (user == null) return null;

    try {
      final idToken = await auth.authService.auth.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${AppConfig.backendBaseUrl}/api/referral/stats'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting referral stats: $e');
      return null;
    }
  }
}
