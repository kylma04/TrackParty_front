import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});

class AuthService {
  final Dio _dio;
  const AuthService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AuthResponse> login(String email, String password) => _call(() async {
        final resp = await _dio.post('auth/login/', data: {'email': email, 'password': password});
        return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<AuthResponse> register({
    required String email,
    required String displayName,
    required String password,
  }) =>
      _call(() async {
        final resp = await _dio.post('auth/register/', data: {
          'email': email,
          'display_name': displayName,
          'password': password,
        });
        return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<void> logout(String refreshToken) => _call(() async {
        await _dio.post('auth/logout/', data: {'refresh': refreshToken});
      });

  Future<UserModel> getMe() => _call(() async {
        final resp = await _dio.get('auth/me/');
        return UserModel.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<UserModel> patchMe(Map<String, dynamic> data) => _call(() async {
        final resp = await _dio.patch('auth/me/', data: data);
        return UserModel.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<void> requestPasswordReset(String email) => _call(() async {
        await _dio.post('auth/password-reset/', data: {'email': email});
      });

  Future<void> resendVerification() => _call(() async {
        await _dio.post('auth/resend-verification/');
      });

  Future<AuthResponse> googleAuth(String idToken) => _call(() async {
        final resp = await _dio.post('auth/google/', data: {'id_token': idToken});
        return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<AuthResponse> appleAuth(String idToken, {String? displayName}) => _call(() async {
        final resp = await _dio.post('auth/apple/', data: {
          'id_token': idToken,
          if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
        });
        return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<AuthResponse> facebookAuth(String accessToken) => _call(() async {
        final resp = await _dio.post('auth/facebook/', data: {'access_token': accessToken});
        return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<AuthResponse> snapchatAuth(String accessToken) => _call(() async {
        final resp = await _dio.post('auth/snapchat/', data: {'access_token': accessToken});
        return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<AuthResponse> instagramAuth(String accessToken) => _call(() async {
        final resp = await _dio.post('auth/instagram/', data: {'access_token': accessToken});
        return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<void> registerFcmToken(String token) => _call(() async {
        print('📱 FCM: Calling API to register token: $token');
        final response = await _dio.post('auth/me/fcm-token/', data: {'fcm_token': token});
        print('📱 FCM: API response status: ${response.statusCode}');
      });
}