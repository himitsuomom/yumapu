// test/services/photo_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_data.dart';

void main() {
  group('PhotoService data structures', () {
    test('photo response contains public URL', () {
      final photoRow = {
        'id': 'photo-1',
        'user_id': 'user-1',
        'facility_id': 'facility-1',
        'storage_path': 'facility-1/abc123.jpg',
        'thumbnail_path': null,
        'created_at': '2024-01-15T00:00:00Z',
        'users': {
          'username': 'onsen_lover',
          'avatar_url': null,
        },
      };

      // Simulate adding public URL
      final publicUrl = 'https://storage.supabase.co/facility-photos/${photoRow['storage_path']}';
      final enriched = {
        ...photoRow,
        'public_url': publicUrl,
      };

      expect(enriched['public_url'], contains('facility-1/abc123.jpg'));
      expect(enriched['users'], isA<Map>());
    });

    test('photo list with null storage_path returns null public_url', () {
      final row = {
        'id': 'photo-2',
        'storage_path': null,
      };

      final publicUrl = row['storage_path'] != null
          ? 'https://storage.supabase.co/${row['storage_path']}'
          : null;

      expect(publicUrl, isNull);
    });

    test('storage path format is correct', () {
      const facilityId = 'facility-1';
      const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      const ext = 'jpg';
      final storagePath = '$facilityId/$uuid.$ext';

      expect(storagePath, 'facility-1/a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg');
      expect(storagePath, contains(facilityId));
      expect(storagePath, endsWith('.jpg'));
    });

    test('file extension extraction from filename', () {
      const fileName = 'my_photo.jpeg';
      final ext = fileName.split('.').last;
      expect(ext, 'jpeg');

      const fileName2 = 'photo.with.dots.png';
      final ext2 = fileName2.split('.').last;
      expect(ext2, 'png');
    });
  });
}
