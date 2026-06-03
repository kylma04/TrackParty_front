import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../services/token_storage.dart';

final dioProvider = Provider<Dio>((ref) => _buildDio());

Dio _buildDio() {
  print('BASE URL: ${Env.apiBaseUrl}');
  final dio = Dio(
    BaseOptions(
      baseUrl: '${Env.apiBaseUrl}/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        print('REQUEST: ${options.method} ${options.baseUrl}${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('📥 RESPONSE: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) async {
        print('❌ERROR: ${error.type} | ${error.message} | ${error.requestOptions.uri}');
        if (error.response?.statusCode != 401) {
          return handler.next(error);
        }

        // Try silent token refresh
        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken == null) return handler.next(error);

        try {
          final refreshDio = Dio(BaseOptions(baseUrl: '${Env.apiBaseUrl}/'));
          final resp = await refreshDio.post(
            'auth/token/refresh/',
            data: {'refresh': refreshToken},
          );
          final newAccess = resp.data['access'] as String;
          final newRefresh = resp.data['refresh'] as String;
          await TokenStorage.save(access: newAccess, refresh: newRefresh);

          // Retry original request with new token
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final retried = await dio.fetch(opts);
          handler.resolve(retried);
        } catch (_) {
          // Refresh failed — clear tokens, let 401 propagate
          await TokenStorage.clear();
          handler.next(error);
        }
      },
    ),
  );

  return dio;
}
