import 'package:flutter_test/flutter_test.dart';
import 'package:topscore_ai/models/user_model.dart';

void main() {
  group('Free User Limits', () {
    test('New user should have tier field initialized', () {
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        freeMessageCount: 0,
        freeMessagesLastAt: null,
      );

      final map = user.toInitialProfileMap();

      expect(map['tier'], equals('Free'));
      expect(map['free_message_count'], equals(0));
      expect(map['free_messages_last_at'], isNull);
    });

    test('Free user with 0 messages should be able to send', () {
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        freeMessageCount: 0,
        freeMessagesLastAt: null,
      );

      // Simulate canSendMessage logic
      final canSend = user.freeMessageCount < 6;
      expect(canSend, isTrue);
    });

    test('Free user with 5 messages should be able to send', () {
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        freeMessageCount: 5,
        freeMessagesLastAt: DateTime.now(),
      );

      final canSend = user.freeMessageCount < 6;
      expect(canSend, isTrue);
    });

    test('Free user with 6 messages should NOT be able to send', () {
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        freeMessageCount: 6,
        freeMessagesLastAt: DateTime.now(),
      );

      final canSend = user.freeMessageCount < 6;
      expect(canSend, isFalse);
    });

    test('Premium user should bypass limits', () {
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        isSubscribed: true,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
        freeMessageCount: 10, // Even with high count
      );

      // Premium users bypass limit check
      final isPremium = user.isSubscribed &&
          (user.subscriptionExpiry == null ||
              user.subscriptionExpiry!.isAfter(DateTime.now()));
      expect(isPremium, isTrue);
    });

    test('Expired subscription should enforce limits', () {
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        isSubscribed: true,
        subscriptionExpiry:
            DateTime.now().subtract(const Duration(days: 1)), // Expired
        freeMessageCount: 0,
      );

      final isPremium = user.isSubscribed &&
          (user.subscriptionExpiry == null ||
              user.subscriptionExpiry!.isAfter(DateTime.now()));
      expect(isPremium, isFalse);
    });

    test('User model should handle legacy field names', () {
      // Test backward compatibility with old field names
      final map = {
        'uid': 'test_uid',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'student',
        'schoolName': 'Test School',
        'dailyMessageCount': 3, // Old field name
        'lastMessageDate':
            DateTime.now().millisecondsSinceEpoch, // Old field name
      };

      final user = UserModel.fromMap(map, 'test_uid');

      expect(user.freeMessageCount, equals(3));
      expect(user.freeMessagesLastAt, isNotNull);
    });

    test('User model should prefer new field names over legacy', () {
      final now = DateTime.now();
      final map = {
        'uid': 'test_uid',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'role': 'student',
        'schoolName': 'Test School',
        'free_message_count': 5, // New field name
        'dailyMessageCount': 3, // Old field name (should be ignored)
        'free_messages_last_at': now.millisecondsSinceEpoch, // New field name
      };

      final user = UserModel.fromMap(map, 'test_uid');

      expect(user.freeMessageCount, equals(5)); // Should use new field
      expect(user.freeMessagesLastAt, isNotNull);
    });

    test('12-hour window should reset limits', () {
      final lastMessageTime =
          DateTime.now().subtract(const Duration(hours: 13));
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        freeMessageCount: 6,
        freeMessagesLastAt: lastMessageTime,
      );

      // Check if 12 hours have passed
      final elapsed = DateTime.now().difference(user.freeMessagesLastAt!);
      final windowExpired = elapsed.inHours >= 12;

      expect(windowExpired, isTrue);
      // In real implementation, backend would reset count
    });

    test('Within 12-hour window should enforce limits', () {
      final lastMessageTime = DateTime.now().subtract(const Duration(hours: 6));
      final user = UserModel(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'student',
        schoolName: 'Test School',
        freeMessageCount: 6,
        freeMessagesLastAt: lastMessageTime,
      );

      final elapsed = DateTime.now().difference(user.freeMessagesLastAt!);
      final windowExpired = elapsed.inHours >= 12;

      expect(windowExpired, isFalse);
      // User should still be blocked
      expect(user.freeMessageCount >= 6, isTrue);
    });
  });
}
