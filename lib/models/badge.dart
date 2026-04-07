// lib/models/badge.dart

/// バッジ定義モデル
class Badge {
  final String id;
  final String code;
  final String nameJa;
  final String descriptionJa;
  final String icon;       // 絵文字
  final String category;  // 'checkin' | 'post' | 'social' | 'rank'
  final String conditionType;  // 'visit_count' | 'review_count' | 'likes_received' | 'total_points'
  final int conditionValue;

  const Badge({
    required this.id,
    required this.code,
    required this.nameJa,
    required this.descriptionJa,
    required this.icon,
    required this.category,
    required this.conditionType,
    required this.conditionValue,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] as String,
      code: json['code'] as String,
      nameJa: json['name_ja'] as String,
      descriptionJa: json['description_ja'] as String,
      icon: (json['badge_icon'] as String?) ?? '🏅',
      category: json['category'] as String,
      conditionType: json['condition_type'] as String,
      conditionValue: (json['condition_value'] as num).toInt(),
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'checkin':
        return 'チェックイン';
      case 'post':
        return '投稿';
      case 'social':
        return 'ソーシャル';
      case 'rank':
        return 'ランク';
      default:
        return category;
    }
  }
}

/// ユーザーが獲得したバッジ
class UserBadge {
  final String id;
  final String userId;
  final Badge badge;
  final DateTime earnedAt;

  const UserBadge({
    required this.id,
    required this.userId,
    required this.badge,
    required this.earnedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      badge: Badge.fromJson(json['badges'] as Map<String, dynamic>),
      earnedAt: DateTime.parse(json['earned_at'] as String),
    );
  }
}
