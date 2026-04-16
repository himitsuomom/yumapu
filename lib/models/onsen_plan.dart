// lib/models/onsen_plan.dart
//
// onsen_plans テーブルのスキーマ:
//   id, user_id, title, description, facility_ids (UUID[]), is_public,
//   created_at, updated_at

/// 湯めぐりプランモデル
class OnsenPlan {
  final String id;
  final String userId;
  final String title;
  final String? description;

  /// 施設 ID の配列。Supabase の UUID[] カラムに対応。
  final List<String> facilityIds;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OnsenPlan({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.facilityIds,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OnsenPlan.fromJson(Map<String, dynamic> json) {
    final rawIds = json['facility_ids'];
    final facilityIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : <String>[];

    return OnsenPlan(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      facilityIds: facilityIds,
      isPublic: (json['is_public'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// 施設がすでにこのプランに含まれているか
  bool containsFacility(String facilityId) => facilityIds.contains(facilityId);
}
