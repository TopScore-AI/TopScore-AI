import 'package:flutter_test/flutter_test.dart';
import 'package:topscore_ai/services/ai_service.dart';

void main() {
  group('AIService Tests', () {
    late AIService aiService;

    setUp(() {
      aiService = AIService();
    });

    test('AIService initializes without error', () {
      expect(aiService, isNotNull);
    });
  });
}
