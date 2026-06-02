import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

final promoterServiceProvider = Provider<PromoterService>((ref) {
  return PromoterService(ref.read(dioProvider));
});

class PromoterService {
  final Dio _dio;
  PromoterService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<bool> isFollowing(String userId) => _call(() async {
        final res = await _dio.get('auth/promoters/$userId/');
        return (res.data['is_following'] as bool?) ?? false;
      });

  Future<void> follow(String userId) => _call(() async {
        await _dio.post('auth/promoters/$userId/follow/');
      });

  Future<void> unfollow(String userId) => _call(() async {
        await _dio.delete('auth/promoters/$userId/follow/');
      });
}
