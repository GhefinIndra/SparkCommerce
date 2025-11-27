// lib/models/user.dart
class User {
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final String? groupId;
  final String authToken;

  User({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.groupId,
    required this.authToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      groupId: json['group_id'],
      authToken: json['auth_token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'group_id': groupId,
      'auth_token': authToken,
    };
  }

  @override
  String toString() {
    return 'User{userId: $userId, name: $name, email: $email, phone: $phone}';
  }
}
