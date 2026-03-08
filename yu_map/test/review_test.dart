import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/domain/entities/review.dart';

void main() {
  group('Review entity', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'id': 'r1',
        'user_id': 'u1',
        'facility_id': 'f1',
        'content': 'Great onsen with beautiful outdoor bath.',
        'rating': 5,
        'likes_count': 12,
        'created_at': '2025-06-15T10:30:00Z',
      };

      final review = Review.fromJson(json);

      expect(review.id, 'r1');
      expect(review.userId, 'u1');
      expect(review.facilityId, 'f1');
      expect(review.content, 'Great onsen with beautiful outdoor bath.');
      expect(review.rating, 5);
      expect(review.likesCount, 12);
      expect(review.createdAt, DateTime.parse('2025-06-15T10:30:00Z'));
    });

    test('fromJson defaults likesCount to 0', () {
      final json = <String, dynamic>{
        'id': 'r2',
        'user_id': 'u2',
        'facility_id': 'f2',
        'content': 'Nice place.',
        'rating': 3,
        'created_at': '2025-07-01T08:00:00Z',
      };

      final review = Review.fromJson(json);

      expect(review.likesCount, 0);
    });

    test('two reviews with same props are equal (Equatable)', () {
      final dt = DateTime.parse('2025-06-15T10:30:00Z');
      final a = Review(
        id: 'r1', userId: 'u1', facilityId: 'f1',
        content: 'Test', rating: 4, createdAt: dt,
      );
      final b = Review(
        id: 'r1', userId: 'u1', facilityId: 'f1',
        content: 'Test', rating: 4, createdAt: dt,
      );

      expect(a, equals(b));
    });
  });
}
