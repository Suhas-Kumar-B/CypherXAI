// lib/models/user.dart
import '../services/auth_service.dart';

class User {
  final String id;
  final String fullName;
  final String email;

  User({required this.id, required this.fullName, required this.email});

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    return _nameFromEmail(email);
  }

  static String _nameFromEmail(String email) {
    return AuthService.displayNameFromEmail(email);
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? '',
        fullName: json['full_name'] ?? '',
        email: json['email'] ?? '',
      );

  static Future<User> me() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final email = AuthService().username ?? 'dummy@gmail.com';
    final derived = _nameFromEmail(email);
    return User(id: '1', fullName: derived, email: email);
  }

  static Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 80));
  }
}
