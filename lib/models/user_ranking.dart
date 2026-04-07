// lib/models/user_ranking.dart
/// ユーザーランキングモデル
class UserRanking {
  final String id;
  final String userId;
  final int explorerPoints; // 訪問・お気に入りなどのポイント
  final int socialPoints;   // 投稿・いいね獲得などのポイント
  final int totalPoints;    // 合計ポイント（DB上でexplorer + social）
  final int visitCount;     // チェックイン回数
  final int reviewCount;    // 投稿数
  final int photoCount;     // 写真数
  final int likesReceived;  // もらったいいね数
  final String currentTitle; // 現在のタイトル
  final int? rankPosition;   // ランキング順位

  const UserRanking({
    required this.id,
    required this.userId,
    required this.explorerPoints,
    required this.socialPoints,
    required this.totalPoints,
    required this.visitCount,
    required this.reviewCount,
    required this.photoCount,
    required this.likesReceived,
    required this.currentTitle,
    this.rankPosition,
  });

  factory UserRanking.fromJson(Map<String, dynamic> json) {
    return UserRanking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      explorerPoints: (json['explorer_points'] as num?)?.toInt() ?? 0,
      socialPoints: (json['social_points'] as num?)?.toInt() ?? 0,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      visitCount: (json['visit_count'] as num?)?.toInt() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
      likesReceived: (json['likes_received'] as num?)?.toInt() ?? 0,
      currentTitle: (json['current_title'] as String?) ?? '湯めぐり初心者',
      rankPosition: (json['rank_position'] as num?)?.toInt(),
    );
  }

  /// ポイントからタイトルを計算
  static String titleFromPoints(int points) {
    if (points >= 10000) return '湯マスター';
    if (points >= 5000) return '湯の達人';
    if (points >= 2000) return '湯めぐり名人';
    if (points >= 1000) return '温泉愛好家';
    if (points >= 500) return '湯めぐり中級者';
    return '湯めぐり初心者';
  }

  /// 次のタイトルに必要なポイント（null = 最高ランク）
  static int? nextTitlePoints(int points) {
    if (points >= 10000) return null;
    if (points >= 5000) return 10000;
    if (points >= 2000) return 5000;
    if (points >= 1000) return 2000;
    if (points >= 500) return 1000;
    return 500;
  }
}

/// ランキング一覧表示用（他のユーザー情報を含む）
class RankingEntry {
  final int rank;
  final String userId;
  final String userName;
  final String userAvatar;
  final int totalPoints;
  final String currentTitle;

  const RankingEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.totalPoints,
    required this.currentTitle,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>? ?? {};
    return RankingEntry(
      rank: (json['rank_position'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String,
      userName: (users['display_name'] as String?) ??
          (users['username'] as String?) ??
          '名無し',
      userAvatar: (users['avatar_url'] as String?) ?? '',
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      currentTitle: (json['current_title'] as String?) ?? '湯めぐり初心者',
    );
  }
}
