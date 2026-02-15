// lib/services/photo_service.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service for photo upload / retrieval via Supabase Storage.
class PhotoService {
  final SupabaseClient _client;
  static const String _bucketName = 'facility-photos';
  static const _uuid = Uuid();

  PhotoService(this._client);

  /// Upload a photo and create a DB record.
  /// Returns the public URL of the uploaded photo.
  Future<String> uploadPhoto({
    required Uint8List fileBytes,
    required String fileName,
    required String facilityId,
    String? reviewId,
    String? visitId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final ext = fileName.split('.').last;
    final storagePath = '$facilityId/${_uuid.v4()}.$ext';

    // Upload to Supabase Storage
    await _client.storage
        .from(_bucketName)
        .uploadBinary(storagePath, fileBytes);

    final publicUrl = _client.storage
        .from(_bucketName)
        .getPublicUrl(storagePath);

    // Insert DB record
    await _client.from('photos').insert({
      'user_id': userId,
      'facility_id': facilityId,
      'review_id': reviewId,
      'visit_id': visitId,
      'storage_path': storagePath,
      'thumbnail_path': null, // thumbnail generation can be a future enhancement
    });

    return publicUrl;
  }

  /// List photos for a facility.
  Future<List<Map<String, dynamic>>> getPhotosForFacility(
    String facilityId, {
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('photos')
          .select('*, users(username, avatar_url)')
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false)
          .limit(limit);

      // Attach public URLs
      return response.map<Map<String, dynamic>>((row) {
        final path = row['storage_path'] as String?;
        return {
          ...row,
          'public_url': path != null
              ? _client.storage.from(_bucketName).getPublicUrl(path)
              : null,
        };
      }).toList();
    } catch (e) {
      debugPrint('PhotoService.getPhotosForFacility error: $e');
      return [];
    }
  }

  /// Delete a photo (owner only via RLS).
  Future<void> deletePhoto(String photoId, String storagePath) async {
    await _client.storage.from(_bucketName).remove([storagePath]);
    await _client.from('photos').delete().eq('id', photoId);
  }
}
