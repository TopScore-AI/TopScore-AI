/// Subscription system tests
///
/// Covers:
///   - SubscriptionService (premium check via Firebase custom claims)
///   - PaystackService (initialize + verify via backend endpoints)
///   - UserModel subscription fields
///
/// Run with: flutter test test/subscription_test.dart
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:topscore_ai/models/user_model.dart';
import 'package:topscore_ai/services/paystack_service.dart';
import 'package:topscore_ai/screens/subscription/paystack_checkout_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Mocks
// ──────────────────────────────────────────────────────────────────────────────

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserMetadata extends Mock implements UserMetadata {}

class MockIdTokenResult extends Mock implements IdTokenResult {}

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

// ──────────────────────────────────────────────────────────────────────────────
// UserModel Subscription Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('UserModel — subscription fields', () {
    test('defaults to not subscribed', () {
      final user = UserModel(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
        role: 'student',
        schoolName: 'School',
      );

      expect(user.isSubscribed, false);
      expect(user.subscriptionExpiry, isNull);
    });

    test('fromMap parses isSubscribed and subscriptionExpiry', () {
      final expiry = DateTime(2026, 4, 1);
      final map = {
        'email': 'a@b.com',
        'displayName': 'Test',
        'role': 'student',
        'schoolName': 'School',
        'isSubscribed': true,
        'subscriptionExpiry': expiry.millisecondsSinceEpoch,
      };

      final user = UserModel.fromMap(map, 'u1');

      expect(user.isSubscribed, true);
      expect(user.subscriptionExpiry, isNotNull);
      expect(user.subscriptionExpiry!.year, 2026);
      expect(user.subscriptionExpiry!.month, 4);
    });

    test('fromMap defaults isSubscribed to false when missing', () {
      final map = {
        'email': 'a@b.com',
        'displayName': 'Test',
        'role': 'student',
        'schoolName': 'School',
      };

      final user = UserModel.fromMap(map, 'u1');
      expect(user.isSubscribed, false);
      expect(user.subscriptionExpiry, isNull);
    });

    test('toMap serializes subscription fields', () {
      final expiry = DateTime(2026, 4, 1);
      final user = UserModel(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
        role: 'student',
        schoolName: 'School',
        isSubscribed: true,
        subscriptionExpiry: expiry,
      );

      final map = user.toMap();
      expect(map['isSubscribed'], true);
      expect(map['subscriptionExpiry'], expiry.millisecondsSinceEpoch);
    });

    test('copyWith updates subscription status', () {
      final user = UserModel(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
        role: 'student',
        schoolName: 'School',
      );

      final updated = user.copyWith(
        isSubscribed: true,
        subscriptionExpiry: DateTime(2026, 5, 1),
      );

      expect(updated.isSubscribed, true);
      expect(updated.subscriptionExpiry!.month, 5);
      // Original unchanged
      expect(user.isSubscribed, false);
    });

    test('freemium tracking fields default correctly', () {
      final user = UserModel(
        uid: 'u1',
        email: 'a@b.com',
        displayName: 'Test',
        role: 'student',
        schoolName: 'School',
      );

      expect(user.dailyMessageCount, 0);
      expect(user.lastMessageDate, isNull);
      expect(user.accessedDocuments, isEmpty);
    });

    test('fromMap parses freemium tracking fields', () {
      final now = DateTime.now();
      final map = {
        'email': 'a@b.com',
        'displayName': 'Test',
        'role': 'student',
        'schoolName': 'School',
        'dailyMessageCount': 3,
        'lastMessageDate': now.millisecondsSinceEpoch,
        'accessedDocuments': ['doc1', 'doc2'],
      };

      final user = UserModel.fromMap(map, 'u1');

      expect(user.dailyMessageCount, 3);
      expect(user.lastMessageDate, isNotNull);
      expect(user.accessedDocuments, ['doc1', 'doc2']);
    });

    test('round-trip toMap → fromMap preserves subscription data', () {
      final expiry = DateTime(2026, 6, 15, 12, 0, 0);
      final original = UserModel(
        uid: 'u1',
        email: 'user@test.com',
        displayName: 'Round Trip',
        role: 'student',
        schoolName: 'Test School',
        isSubscribed: true,
        subscriptionExpiry: expiry,
        dailyMessageCount: 4,
        accessedDocuments: ['d1', 'd2', 'd3'],
      );

      final map = original.toMap();
      final restored = UserModel.fromMap(map, 'u1');

      expect(restored.isSubscribed, original.isSubscribed);
      expect(
        restored.subscriptionExpiry!.millisecondsSinceEpoch,
        original.subscriptionExpiry!.millisecondsSinceEpoch,
      );
      expect(restored.dailyMessageCount, original.dailyMessageCount);
      expect(restored.accessedDocuments, original.accessedDocuments);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // SubscriptionService Tests
  // ────────────────────────────────────────────────────────────────────────────

  group('SubscriptionService — isSessionPremium', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockIdTokenResult mockTokenResult;
    late _TestableSubscriptionService service;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockTokenResult = MockIdTokenResult();

      service = _TestableSubscriptionService(mockAuth);
    });

    test('returns false when user is null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final result = await service.isSessionPremium();
      expect(result, false);
    });

    test('returns true when plan is premium and not expired', () async {
      final futureExpiry =
          (DateTime.now().millisecondsSinceEpoch / 1000).round() +
              86400; // +1 day

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({
        'plan': 'premium',
        'expiry': futureExpiry,
      });

      final result = await service.isSessionPremium();
      expect(result, true);
    });

    test('returns false when plan is premium but expired', () async {
      final pastExpiry =
          (DateTime.now().millisecondsSinceEpoch / 1000).round() -
              86400; // -1 day

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({
        'plan': 'premium',
        'expiry': pastExpiry,
      });

      final result = await service.isSessionPremium();
      expect(result, false);
    });

    test('returns false when plan is not premium', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({
        'plan': 'free',
      });

      final result = await service.isSessionPremium();
      expect(result, false);
    });

    test('returns false when claims are null', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn(null);

      final result = await service.isSessionPremium();
      expect(result, false);
    });

    test('returns false on exception', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenThrow(FirebaseAuthException('network-error', 'test'));

      final result = await service.isSessionPremium();
      expect(result, false);
    });
  });

  group('SubscriptionService — isSessionPremiumOrTrial', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockIdTokenResult mockTokenResult;
    late MockUserMetadata mockMetadata;
    late _TestableSubscriptionService service;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockTokenResult = MockIdTokenResult();
      mockMetadata = MockUserMetadata();

      service = _TestableSubscriptionService(mockAuth);
    });

    test('returns true when premium (ignores trial)', () async {
      final futureExpiry =
          (DateTime.now().millisecondsSinceEpoch / 1000).round() + 86400;

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({
        'plan': 'premium',
        'expiry': futureExpiry,
      });

      final result = await service.isSessionPremiumOrTrial();
      expect(result, true);
    });

    test('returns true when not premium but within 7-day trial', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({'plan': 'free'});

      when(() => mockUser.metadata).thenReturn(mockMetadata);
      when(() => mockMetadata.creationTime)
          .thenReturn(DateTime.now().subtract(const Duration(days: 3)));

      final result = await service.isSessionPremiumOrTrial();
      expect(result, true);
    });

    test('returns false when not premium and trial expired (8+ days)',
        () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({'plan': 'free'});

      when(() => mockUser.metadata).thenReturn(mockMetadata);
      when(() => mockMetadata.creationTime)
          .thenReturn(DateTime.now().subtract(const Duration(days: 10)));

      final result = await service.isSessionPremiumOrTrial();
      expect(result, false);
    });

    test('returns false when user is null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final result = await service.isSessionPremiumOrTrial();
      expect(result, false);
    });

    test('trial boundary: exactly 7 days returns false', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({'plan': 'free'});

      when(() => mockUser.metadata).thenReturn(mockMetadata);
      when(() => mockMetadata.creationTime)
          .thenReturn(DateTime.now().subtract(const Duration(days: 7)));

      final result = await service.isSessionPremiumOrTrial();
      expect(result, false);
    });

    test('trial boundary: 6 days 23 hours returns true', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdTokenResult(true))
          .thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({'plan': 'free'});

      when(() => mockUser.metadata).thenReturn(mockMetadata);
      when(() => mockMetadata.creationTime).thenReturn(
        DateTime.now().subtract(const Duration(days: 6, hours: 23)),
      );

      final result = await service.isSessionPremiumOrTrial();
      expect(result, true);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // PaystackInitResult model tests
  // ────────────────────────────────────────────────────────────────────────────

  group('PaystackInitResult — fromJson', () {
    test('parses backend response correctly', () {
      final json = {
        'authorization_url': 'https://checkout.paystack.com/abc123',
        'access_code': 'ac_xyz',
        'reference': 'ts-abc123def456',
      };

      final result = PaystackInitResult.fromJson(json);

      expect(result.authorizationUrl, 'https://checkout.paystack.com/abc123');
      expect(result.accessCode, 'ac_xyz');
      expect(result.reference, 'ts-abc123def456');
    });

    test('throws on missing required fields', () {
      final json = {'authorization_url': 'https://example.com'};

      expect(
        () => PaystackInitResult.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // PaystackVerifyResult model tests
  // ────────────────────────────────────────────────────────────────────────────

  group('PaystackVerifyResult — fromJson', () {
    test('parses successful verification', () {
      final json = {
        'status': 'success',
        'reference': 'ts-ref001',
        'amount': 100000,
        'currency': 'KES',
        'channel': 'card',
        'paid_at': '2026-03-04T10:00:00.000Z',
      };

      final result = PaystackVerifyResult.fromJson(json);

      expect(result.status, 'success');
      expect(result.isSuccess, true);
      expect(result.reference, 'ts-ref001');
      expect(result.amount, 100000);
      expect(result.currency, 'KES');
      expect(result.channel, 'card');
      expect(result.paidAt, '2026-03-04T10:00:00.000Z');
    });

    test('isSuccess is false for abandoned transaction', () {
      final json = {
        'status': 'abandoned',
        'reference': 'ts-ref002',
      };

      final result = PaystackVerifyResult.fromJson(json);

      expect(result.isSuccess, false);
      expect(result.status, 'abandoned');
    });

    test('isSuccess is false for failed transaction', () {
      final json = {
        'status': 'failed',
        'reference': 'ts-ref003',
      };

      final result = PaystackVerifyResult.fromJson(json);
      expect(result.isSuccess, false);
    });

    test('handles null/missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'status': 'success',
        'reference': 'ts-ref004',
      };

      final result = PaystackVerifyResult.fromJson(json);

      expect(result.isSuccess, true);
      expect(result.amount, isNull);
      expect(result.currency, isNull);
      expect(result.channel, isNull);
      expect(result.paidAt, isNull);
    });

    test('defaults status to unknown when null', () {
      final json = <String, dynamic>{};

      final result = PaystackVerifyResult.fromJson(json);

      expect(result.status, 'unknown');
      expect(result.isSuccess, false);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // PaystackService — initializeTransaction (HTTP)
  // ────────────────────────────────────────────────────────────────────────────

  group('PaystackService — initializeTransaction', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    test('returns PaystackInitResult on 200', () async {
      final backendResponse = {
        'authorization_url': 'https://checkout.paystack.com/abc123',
        'access_code': 'ac_001',
        'reference': 'ts-ref001',
      };

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode(backendResponse),
            200,
          ));

      final service = _TestablePaystackService(mockClient);
      final result = await service.initializeTransaction(
        userId: 'u1',
        email: 'test@example.com',
        amount: 100000,
      );

      expect(result.authorizationUrl, 'https://checkout.paystack.com/abc123');
      expect(result.accessCode, 'ac_001');
      expect(result.reference, 'ts-ref001');
    });

    test('sends correct request body to /paystack/initialize', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'authorization_url': 'https://x.com',
              'access_code': 'ac',
              'reference': 'ref',
            }),
            200,
          ));

      final service = _TestablePaystackService(mockClient);
      await service.initializeTransaction(
        userId: 'user_42',
        email: 'student@school.ke',
        amount: 100000,
        planName: 'TopScore Premium',
        currency: 'KES',
      );

      // Capture both URL and body in a single verify call
      final captured = verify(() => mockClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;

      final uri = captured[0] as Uri;
      expect(uri.path, '/paystack/initialize');

      final body = jsonDecode(captured[1] as String);
      expect(body['user_id'], 'user_42');
      expect(body['email'], 'student@school.ke');
      expect(body['amount'], 100000);
      expect(body['plan_name'], 'TopScore Premium');
      expect(body['currency'], 'KES');
    });

    test('throws on non-200 response', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Server Error', 500));

      final service = _TestablePaystackService(mockClient);

      expect(
        () => service.initializeTransaction(
          userId: 'u1',
          email: 'test@example.com',
          amount: 100000,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on network error', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(http.ClientException('No internet'));

      final service = _TestablePaystackService(mockClient);

      expect(
        () => service.initializeTransaction(
          userId: 'u1',
          email: 'test@example.com',
          amount: 100000,
        ),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // PaystackService — verifyTransaction (HTTP)
  // ────────────────────────────────────────────────────────────────────────────

  group('PaystackService — verifyTransaction', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    test('returns PaystackVerifyResult with success status', () async {
      final backendResponse = {
        'status': 'success',
        'reference': 'ts-ref001',
        'amount': 100000,
        'currency': 'KES',
        'channel': 'card',
        'paid_at': '2026-03-04T10:00:00.000Z',
      };

      when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode(backendResponse), 200));

      final service = _TestablePaystackService(mockClient);
      final result = await service.verifyTransaction('ts-ref001');

      expect(result.isSuccess, true);
      expect(result.reference, 'ts-ref001');
      expect(result.amount, 100000);
      expect(result.channel, 'card');
    });

    test('calls correct URL with reference', () async {
      when(() => mockClient.get(any())).thenAnswer((_) async => http.Response(
          jsonEncode({'status': 'success', 'reference': 'x'}), 200));

      final service = _TestablePaystackService(mockClient);
      await service.verifyTransaction('ts-refXYZ');

      final captured = verify(() => mockClient.get(captureAny())).captured;
      final uri = captured.first as Uri;
      expect(uri.toString(), contains('/paystack/verify/ts-refXYZ'));
    });

    test('returns abandoned status for incomplete payment', () async {
      final response = {
        'status': 'abandoned',
        'reference': 'ts-ref002',
      };

      when(() => mockClient.get(any()))
          .thenAnswer((_) async => http.Response(jsonEncode(response), 200));

      final service = _TestablePaystackService(mockClient);
      final result = await service.verifyTransaction('ts-ref002');

      expect(result.isSuccess, false);
      expect(result.status, 'abandoned');
    });

    test('throws on server error (500)', () async {
      when(() => mockClient.get(any()))
          .thenAnswer((_) async => http.Response('Internal Server Error', 500));

      final service = _TestablePaystackService(mockClient);

      expect(
        () => service.verifyTransaction('ts-ref003'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on network failure', () async {
      when(() => mockClient.get(any()))
          .thenThrow(http.ClientException('Connection refused'));

      final service = _TestablePaystackService(mockClient);

      expect(
        () => service.verifyTransaction('ts-ref004'),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // PaystackCheckoutResult tests
  // ────────────────────────────────────────────────────────────────────────────

  group('PaystackCheckoutResult', () {
    test('success factory creates successful result with verify data', () {
      final verifyResult = PaystackVerifyResult.fromJson({
        'status': 'success',
        'reference': 'ts-ref001',
        'amount': 100000,
        'currency': 'KES',
        'channel': 'card',
        'paid_at': '2026-03-04T10:00:00.000Z',
      });

      final result = PaystackCheckoutResult.success(verifyResult);

      expect(result.success, true);
      expect(result.verifyResult, isNotNull);
      expect(result.verifyResult!.isSuccess, true);
      expect(result.verifyResult!.reference, 'ts-ref001');
      expect(result.error, isNull);
    });

    test('failure factory creates failed result with message', () {
      final result =
          PaystackCheckoutResult.failure('Payment status: abandoned');

      expect(result.success, false);
      expect(result.verifyResult, isNull);
      expect(result.error, 'Payment status: abandoned');
    });

    test('cancelled factory creates failed result with cancelled flag', () {
      final result = PaystackCheckoutResult.cancelled();

      expect(result.success, false);
      expect(result.error, 'cancelled');
      expect(result.verifyResult, isNull);
    });
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Testable service wrappers (inject mocked dependencies)
// ──────────────────────────────────────────────────────────────────────────────

/// Standalone reimplementation of SubscriptionService logic
/// that uses injected FirebaseAuth instead of FirebaseAuth.instance
class _TestableSubscriptionService {
  final FirebaseAuth _mockAuth;

  _TestableSubscriptionService(this._mockAuth);

  Future<bool> isSessionPremium() async {
    User? user = _mockAuth.currentUser;
    if (user == null) return false;

    try {
      IdTokenResult tokenResult = await user.getIdTokenResult(true);
      Map<String, dynamic>? claims = tokenResult.claims;

      if (claims?['plan'] == 'premium') {
        int expiry = claims?['expiry'] ?? 0;
        bool isActive = DateTime.now().millisecondsSinceEpoch / 1000 < expiry;
        return isActive;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isSessionPremiumOrTrial() async {
    User? user = _mockAuth.currentUser;
    if (user == null) return false;

    if (await isSessionPremium()) return true;

    if (user.metadata.creationTime != null) {
      final now = DateTime.now();
      final difference = now.difference(user.metadata.creationTime!);
      if (difference.inDays < 7) {
        return true;
      }
    }

    return false;
  }
}

/// Testable Paystack service using injected HTTP client
/// (mirrors PaystackService logic but with injectable http.Client)
class _TestablePaystackService {
  final http.Client _client;
  static const String _baseUrl = 'https://agent.topscoreapp.ai';

  _TestablePaystackService(this._client);

  Future<PaystackInitResult> initializeTransaction({
    required String userId,
    required String email,
    required int amount,
    String planName = "TopScore Premium",
    String currency = "KES",
    String? callbackUrl,
  }) async {
    final url = Uri.parse('$_baseUrl/paystack/initialize');

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

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return PaystackInitResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to initialize Paystack: ${response.body}');
    }
  }

  Future<PaystackVerifyResult> verifyTransaction(String reference) async {
    final url = Uri.parse('$_baseUrl/paystack/verify/$reference');

    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return PaystackVerifyResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to verify Paystack: ${response.body}');
    }
  }
}

// Firebase exceptions helper
class FirebaseAuthException implements Exception {
  final String code;
  final String message;
  FirebaseAuthException(this.code, this.message);
  @override
  String toString() => 'FirebaseAuthException($code): $message';
}
