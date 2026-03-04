import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Response from POST /paystack/initialize
class PaystackInitResult {
  final String authorizationUrl;
  final String accessCode;
  final String reference;

  PaystackInitResult({
    required this.authorizationUrl,
    required this.accessCode,
    required this.reference,
  });

  factory PaystackInitResult.fromJson(Map<String, dynamic> json) {
    return PaystackInitResult(
      authorizationUrl: json['authorization_url'] as String,
      accessCode: json['access_code'] as String,
      reference: json['reference'] as String,
    );
  }
}

/// Response from GET /paystack/verify/{reference}
class PaystackVerifyResult {
  final String status; // 'success', 'abandoned', 'failed', etc.
  final String reference;
  final int? amount;
  final String? currency;
  final String? channel;
  final String? paidAt;

  PaystackVerifyResult({
    required this.status,
    required this.reference,
    this.amount,
    this.currency,
    this.channel,
    this.paidAt,
  });

  bool get isSuccess => status == 'success';

  factory PaystackVerifyResult.fromJson(Map<String, dynamic> json) {
    return PaystackVerifyResult(
      status: json['status'] as String? ?? 'unknown',
      reference: json['reference'] as String? ?? '',
      amount: json['amount'] as int?,
      currency: json['currency'] as String?,
      channel: json['channel'] as String?,
      paidAt: json['paid_at'] as String?,
    );
  }
}

class PaystackService {
  /// POST /paystack/initialize
  /// Creates a checkout session and returns the hosted payment URL.
  Future<PaystackInitResult> initializeTransaction({
    required String userId,
    required String email,
    required int amount, // in smallest currency unit (cents)
    String planName = "TopScore Premium",
    String currency = "KES",
    String? callbackUrl,
  }) async {
    final url = Uri.parse(ApiConfig.paystackInitialize);

    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'email': email,
        'amount': amount,
        'plan_name': planName,
        'currency': currency,
      };
      if (callbackUrl != null) {
        body['callback_url'] = callbackUrl;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return PaystackInitResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to initialize Paystack: ${response.body}');
      }
    } catch (e) {
      debugPrint('Paystack Service Error: $e');
      rethrow;
    }
  }

  /// GET /paystack/verify/{reference}
  /// Verifies a transaction by reference after checkout redirect.
  Future<PaystackVerifyResult> verifyTransaction(String reference) async {
    final url = Uri.parse('${ApiConfig.paystackVerify}/$reference');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return PaystackVerifyResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to verify Paystack: ${response.body}');
      }
    } catch (e) {
      debugPrint('Paystack Verification Error: $e');
      rethrow;
    }
  }
}
