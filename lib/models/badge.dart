// lib/models/badge.dart
//
// badges テーブルのスキーマ（supabase/migrations/20240209000000_initial_schema.sql）:
//   id, code, name_ja, name_en, description_ja, icon_url, category, requirements (JSONB)
//
// requirements JSONB の形式例:
//   {"type":"visit_count","count":1}
//   {"type":"prefecture","name":"北海道"}
//   {"type":"spring_type","spring_code":"simple_hot_spring"}
//   {"type":"spring_all","count":8}

/// バッジ定義モデル（DB の badges テーブルに対応）
/// Flutter Material の Badge ウィジェットと名前衝突するため AppBadge と命名。
class AppBadge {
  final String id;
  final String code;
  final String nameJa;
  final String nameEn;
  final String? descriptionJa;

  /// DB の icon_url カラム。未設定時は displayIcon のカテゴリ絵文字を使用。
  final String? iconUrl;
  final String? category;

  /// DB の requirements カラム（JSONB）をそのまま保持。
  /// バッジ付与判定は DB トリガー（check_and_grant_badges）で行うため
  /// Flutter 側では表示目的のみに使用する。
  final Map<String, dynamic> requirements;

  const AppBadge({
    required this.id,
    required this.code,
    required this.nameJa,
    required this.nameEn,
    this.descriptionJa,
    this.iconUrl,
    this.category,
    this.requirements = const {},
  });

  factory AppBadge.fromJson(Map<String, dynamic> json) {
    final reqs = json['requirements'] as Map<String, dynamic>? ?? {};
    return AppBadge(
      id: json['id'] as String,
      code: json['code'] as String,
      nameJa: json['name_ja'] as String,
      nameEn: (json['name_en'] as String?) ?? '',
      descriptionJa: json['description_ja'] as String?,
      iconUrl: json['icon_url'] as String?,
      category: json['category'] as String?,
      requirements: reqs,
    );
  }

  /// カテゴリの日本語表示名
  String get categoryLabel {
    switch (category) {
      case 'milestone':
        return 'マイルストーン';
      case 'prefecture':
        return '都道府県';
      case 'spring_type':
        return '泉質';
      case 'checkin':
        return 'チェックイン';
      case 'post':
        return '投稿';
      case 'social':
        return 'ソーシャル';
      case 'rank':
        return 'ランク';
      default:
        return category ?? 'バッジ';
    }
  }

  /// アイコン表示用。icon_url があればそれを返し、なければカテゴリ絵文字を返す。
  String get displayIcon {
    if (iconUrl != null && iconUrl!.isNotEmpty) return iconUrl!;
    switch (category) {
      case 'milestone':
        return '🏅';
      case 'prefecture':
        return '🗾';
      case 'spring_type':
        return '♨️';
      case 'checkin':
        return '📍';
      case 'post':
        return '✍️';
      case 'social':
        return '❤️';
      case 'rank':
        return '👑';
      default:
        return '🏅';
    }
  }
}

/// ユーザーが獲得したバッジ
class UserBadge {
  final String id;
  final String userId;
  final AppBadge badge;
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
      badge: AppBadge.fromJson(json['badges'] as Map<String, dynamic>),
      earnedAt: DateTime.parse(json['earned_at'] as String),
    );
  }
}
