// lib/models/user.dart

class UserProfile {
  String name;
  String handle;
  String bio;
  String avatar;
  bool isPremium;

  UserProfile({
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatar,
    this.isPremium = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String,
      handle: json['handle'] as String,
      bio: json['bio'] as String,
      avatar: json['avatar'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'handle': handle,
      'bio': bio,
      'avatar': avatar,
      'is_premium': isPremium,
    };
  }
}
