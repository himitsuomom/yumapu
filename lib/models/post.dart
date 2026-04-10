// lib/models/post.dart

/// コメントモデル
///
/// DB の comments テーブルに対応。
/// user_name / user_avatar はJOINを避けるための非正規化カラム。
class Comment {
  final String id;
  final String user;
  final String avatar;
  final String text;
  final String time;

  Comment({
    required this.id,
    required this.user,
    required this.avatar,
    required this.text,
    required this.time,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String? ?? '',
      // comments テーブルのカラム名は user_name
      user: json['user_name'] as String? ?? '削除済みユーザー',
      avatar: json['user_avatar'] as String? ?? '',
      text: json['text'] as String? ?? '',
      time: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': user,
      'user_avatar': avatar,
      'text': text,
      'created_at': time,
    };
  }
}

/// 投稿モデル
///
/// DB の posts テーブルに対応。
/// [isLiked] はDBカラムではなく、取得時にログインユーザーの
/// post_likes を別途チェックしてセットするクライアント側フラグ。
class Post {
  final String id;
  final String user;
  final String avatar;
  final String content;
  final String time;
  int likes;
  bool isLiked;
  final String facilityId;
  final String facilityName;
  final String imageUrl;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.user,
    required this.avatar,
    required this.content,
    required this.time,
    required this.likes,
    required this.isLiked,
    required this.facilityId,
    required this.facilityName,
    required this.imageUrl,
    required this.comments,
  });

  /// DBのJSONからPostを生成する。
  ///
  /// [isLiked] はDBに持たず、呼び出し元が別途 post_likes をチェックして渡す。
  /// users テーブルをJOINした場合は `json['users']` にネストされたオブジェクトが入る。
  factory Post.fromJson(Map<String, dynamic> json, {bool isLiked = false}) {
    // users テーブルをJOINしている場合はネストされたオブジェクトから取得
    final usersData = json['users'] as Map<String, dynamic>?;
    final displayName = usersData?['display_name'] as String?
        ?? usersData?['username'] as String?
        ?? '削除済みユーザー';
    final avatarUrl = usersData?['avatar_url'] as String? ?? '';

    return Post(
      id: json['id'] as String? ?? '',
      user: displayName,
      avatar: avatarUrl,
      content: json['content'] as String? ?? '',
      time: json['created_at'] as String? ?? '',
      likes: (json['likes_count'] as num?)?.toInt() ?? 0,
      isLiked: isLiked,
      facilityId: json['facility_id'] as String? ?? '',
      facilityName: json['facility_name'] as String? ?? '施設名不明',
      imageUrl: json['image_url'] as String? ?? '',
      comments: (json['comments'] as List?)
              ?.map((c) => Comment.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': time,
      'likes_count': likes,
      'facility_id': facilityId,
      'facility_name': facilityName,
      'image_url': imageUrl,
    };
  }
}
