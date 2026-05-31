import 'user_model.dart';

class AuthResponse {
  final String access;
  final String refresh;
  final UserModel user;

  const AuthResponse({
    required this.access,
    required this.refresh,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        access: j['access'] as String,
        refresh: j['refresh'] as String,
        user: UserModel.fromJson(j['user'] as Map<String, dynamic>),
      );
}
