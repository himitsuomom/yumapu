// test/helpers/test_data.dart
//
// Reusable test data factories for consistent test setup.

import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/domain/entities/user_ranking.dart';

class TestData {
  TestData._();

  // ── Facility ──
  static Facility facility({
    String id = 'facility-1',
    String name = 'テスト温泉',
    double latitude = 35.6895,
    double longitude = 139.6917,
    String? address = '東京都渋谷区1-1-1',
    Map<String, dynamic>? amenities,
  }) {
    return Facility(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      address: address,
      amenities: amenities ?? {'sauna': true, 'outdoor_bath': true},
      dataQualityScore: 3,
    );
  }

  static Map<String, dynamic> facilityJson({
    String id = 'facility-1',
    String name = 'テスト温泉',
  }) {
    return {
      'id': id,
      'name': name,
      'name_kana': null,
      'google_place_id': null,
      'latitude': 35.6895,
      'longitude': 139.6917,
      'address': '東京都渋谷区1-1-1',
      'phone': '03-1234-5678',
      'website': 'https://example.com',
      'business_hours': <String, dynamic>{},
      'price_info': <String, dynamic>{},
      'amenities': <String, dynamic>{'sauna': true, 'outdoor_bath': true},
      'data_source': 'government',
      'data_quality_score': 3,
      'prefecture_id': 'pref-13',
      'facility_type_id': 'type-onsen',
    };
  }

  static List<Map<String, dynamic>> facilityJsonList({int count = 3}) {
    return List.generate(count, (i) => facilityJson(
      id: 'facility-$i',
      name: 'テスト温泉 $i',
    ));
  }

  // ── Review ──
  static Review review({
    String id = 'review-1',
    String userId = 'user-1',
    String facilityId = 'facility-1',
    String content = '素晴らしい温泉でした！',
    int rating = 5,
    int likesCount = 10,
  }) {
    return Review(
      id: id,
      userId: userId,
      facilityId: facilityId,
      content: content,
      rating: rating,
      likesCount: likesCount,
      createdAt: DateTime(2024, 1, 15),
    );
  }

  static Map<String, dynamic> reviewJson({
    String id = 'review-1',
    int rating = 5,
  }) {
    return {
      'id': id,
      'user_id': 'user-1',
      'facility_id': 'facility-1',
      'content': '素晴らしい温泉でした！',
      'rating': rating,
      'likes_count': 10,
      'created_at': '2024-01-15T00:00:00Z',
    };
  }

  // ── User ──
  static app.User user({
    String id = 'user-1',
    String? username = 'onsen_lover',
    String? displayName = '温泉太郎',
    bool isPremium = false,
  }) {
    return app.User(
      id: id,
      email: 'test@example.com',
      username: username,
      displayName: displayName,
      isPremium: isPremium,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  static Map<String, dynamic> userJson({String id = 'user-1'}) {
    return {
      'id': id,
      'email': 'test@example.com',
      'username': 'onsen_lover',
      'display_name': '温泉太郎',
      'avatar_url': null,
      'bio': '温泉が大好き',
      'is_premium': false,
      'created_at': '2024-01-01T00:00:00Z',
    };
  }

  // ── UserRanking ──
  static UserRanking ranking({
    String userId = 'user-1',
    int explorerPoints = 500,
    int socialPoints = 300,
    int totalPoints = 800,
    int? rankPosition = 42,
  }) {
    return UserRanking(
      id: 'rank-1',
      userId: userId,
      explorerPoints: explorerPoints,
      socialPoints: socialPoints,
      totalPoints: totalPoints,
      currentTitle: '温泉愛好家',
      rankPosition: rankPosition,
    );
  }

  static Map<String, dynamic> rankingJson({String userId = 'user-1'}) {
    return {
      'id': 'rank-1',
      'user_id': userId,
      'explorer_points': 500,
      'social_points': 300,
      'total_points': 800,
      'current_title': '温泉愛好家',
      'rank_position': 42,
    };
  }

  // ── Visit ──
  static Map<String, dynamic> visitJson({
    String id = 'visit-1',
    String facilityId = 'facility-1',
    bool verified = true,
  }) {
    return {
      'id': id,
      'user_id': 'user-1',
      'facility_id': facilityId,
      'visited_at': '2024-01-15T10:30:00Z',
      'verified': verified,
      'facilities': {
        'id': facilityId,
        'name': 'テスト温泉',
        'latitude': 35.6895,
        'longitude': 139.6917,
        'address': '東京都渋谷区1-1-1',
      },
    };
  }

  // ── Badge ──
  static Map<String, dynamic> badgeJson({
    String code = 'first_visit',
    String category = 'explorer',
  }) {
    return {
      'id': 'badge-1',
      'code': code,
      'name_ja': '初めての湯',
      'name_en': 'First Visit',
      'description_ja': '初めて施設にチェックインしました',
      'category': category,
    };
  }
}
