import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService(ref.read(dioProvider));
});

class ModerationService {
  final Dio _dio;
  ModerationService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String description = '',
  }) =>
      _call(() async {
        await _dio.post('moderation/reports/', data: {
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          'description': description,
        });
      });

  Future<void> block(String userId) => _call(() async {
        await _dio.post('moderation/blocks/', data: {'user_id': userId});
      });

  Future<void> unblock(String userId) => _call(() async {
        await _dio.delete('moderation/blocks/$userId/');
      });
}
