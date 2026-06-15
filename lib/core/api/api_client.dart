import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../services/token_storage.dart';

// Incremented by the Dio interceptor when refresh fails.
// AuthNotifier listens to this to trigger an immediate logout without creating
// a circular dependency (dioProvider → authService → dioProvider).
final forceLogoutSignalProvider = StateProvider<int>((ref) => 0);

// Renseigné par l'intercepteur quand une requête renvoie {code: 'account_blocked'}.
// AuthNotifier l'écoute pour rediriger vers l'écran « compte bloqué ».
final accountBlockedProvider = StateProvider<String?>((ref) => null);

final dioProvider = Provider<Dio>((ref) => _buildDio(ref));

Dio _buildDio(Ref ref) {
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
        handler.next(options);
      },
      onError: (error, handler) async {
        // Compte bloqué par la modération (sur 401 OU 403) : on coupe tout,
        // surtout PAS de refresh (sinon boucle infinie).
        final data = error.response?.data;
        final code = data is Map ? data['code'] as String? : null;
        if (code == 'account_blocked') {
          await TokenStorage.clear();
          final msg =
              (data is Map ? data['detail'] as String? : null) ??
              'Ton compte a été bloqué.';
          ref.read(accountBlockedProvider.notifier).state = msg;
          return handler.next(error);
        }

        if (error.response?.statusCode != 401) {
          return handler.next(error);
        }

        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken == null) {
          ref.read(forceLogoutSignalProvider.notifier).update((n) => n + 1);
          return handler.next(error);
        }

        try {
          final refreshDio = Dio(BaseOptions(baseUrl: '${Env.apiBaseUrl}/'));
          final resp = await refreshDio.post(
            'auth/token/refresh/',
            data: {'refresh': refreshToken},
          );
          final newAccess = resp.data['access'] as String;
          final newRefresh = resp.data['refresh'] as String;
          await TokenStorage.save(access: newAccess, refresh: newRefresh);

          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final retried = await dio.fetch(opts);
          handler.resolve(retried);
        } catch (_) {
          await TokenStorage.clear();
          ref.read(forceLogoutSignalProvider.notifier).update((n) => n + 1);
          handler.next(error);
        }
      },
    ),
  );

  return dio;
}
