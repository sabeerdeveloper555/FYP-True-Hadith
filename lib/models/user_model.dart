class UserModel {
  final int userId;
  final String username;
  final DateTime createdAt;
  final String? email; // Optional, may not always be needed
  final String? profilePhotoUrl; // Profile photo URL

  UserModel({
    required this.userId,
    required this.username,
    required this.createdAt,
    this.email,
    this.profilePhotoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      email: json['email'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'created_at': createdAt.toIso8601String(),
      if (email != null) 'email': email,
      if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
    };
  }
}
