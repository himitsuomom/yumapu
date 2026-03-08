import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/domain/entities/user.dart';

void main() {
  group('User entity', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'id': 'u1',
        'email': 'test@example.com',
        'username': 'onsen_lover',
        'display_name': '温泉太郎',
        'avatar_url': 'https://example.com/avatar.png',
        'bio': 'I love hot springs!',
        'is_premium': true,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final user = User.fromJson(json);

      expect(user.id, 'u1');
      expect(user.email, 'test@example.com');
      expect(user.username, 'onsen_lover');
      expect(user.displayName, '温泉太郎');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.bio, 'I love hot springs!');
      expect(user.isPremium, true);
      expect(user.createdAt, DateTime.parse('2025-01-01T00:00:00Z'));
    });

    test('fromJson defaults isPremium to false', () {
      final json = <String, dynamic>{
        'id': 'u2',
        'created_at': '2025-01-01T00:00:00Z',
      };

      final user = User.fromJson(json);

      expect(user.isPremium, false);
      expect(user.email, isNull);
      expect(user.username, isNull);
    });
  });
}
