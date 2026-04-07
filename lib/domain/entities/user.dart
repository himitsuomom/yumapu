import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String? email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isPremium;
  final DateTime createdAt;

  const User({
    required this.id,
    this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.isPremium = false,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, username, displayName, isPremium];
}
