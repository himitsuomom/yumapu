// lib/models/post.dart

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
      id: json['id'] as String,
      user: json['user_name'] as String,
      avatar: json['user_avatar'] as String,
      text: json['text'] as String,
      time: json['created_at'] as String,
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

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      user: json['user_name'] as String,
      avatar: json['user_avatar'] as String,
      content: json['content'] as String,
      time: json['created_at'] as String,
      likes: json['likes_count'] as int,
      isLiked: json['is_liked'] as bool? ?? false,
      facilityId: json['facility_id'] as String,
      facilityName: json['facility_name'] as String,
      imageUrl: json['image_url'] as String,
      comments: (json['comments'] as List?)
              ?.map((c) => Comment.fromJson(c))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': user,
      'user_avatar': avatar,
      'content': content,
      'created_at': time,
      'likes_count': likes,
      'is_liked': isLiked,
      'facility_id': facilityId,
      'facility_name': facilityName,
      'image_url': imageUrl,
      'comments': comments.map((c) => c.toJson()).toList(),
    };
  }
}
