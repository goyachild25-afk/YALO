import 'package:flutter_test/flutter_test.dart';
import 'package:serviciosya/features/auth/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('UserRole.client has correct string representation', () {
      expect(UserRole.client.toString(), 'UserRole.client');
    });

    test('UserRole.provider has correct string representation', () {
      expect(UserRole.provider.toString(), 'UserRole.provider');
    });

    test('UserRole.admin has correct string representation', () {
      expect(UserRole.admin.toString(), 'UserRole.admin');
    });

    test('Can create User object with valid data', () {
      const user = User(
        id: 'test-user-123',
        email: 'test@example.com',
        fullName: 'Test User',
      );

      expect(user.id, 'test-user-123');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'Test User');
    });

    test('User equality works correctly', () {
      const user1 = User(
        id: 'same-id',
        email: 'test@example.com',
        fullName: 'Test',
      );
      const user2 = User(
        id: 'same-id',
        email: 'test@example.com',
        fullName: 'Test',
      );

      expect(user1, user2);
    });

    test('User inequality detects different IDs', () {
      const user1 = User(
        id: 'user-1',
        email: 'test@example.com',
        fullName: 'Test',
      );
      const user2 = User(
        id: 'user-2',
        email: 'test@example.com',
        fullName: 'Test',
      );

      expect(user1 == user2, false);
    });
  });
}
