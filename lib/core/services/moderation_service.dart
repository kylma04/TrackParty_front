import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/blocked_user_model.dart';

final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService(ref.read(dioProvider));
});

/// Liste des utilisateurs bloqués par l'utilisateur courant.
final blockedUsersProvider =
    FutureProvider.autoDispose<List<BlockedUser>>((ref) {
  return ref.read(moderationServiceProvider).getBlockedUsers();
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

  Future<List<BlockedUser>> getBlockedUsers() => _call(() async {
        final res = await _dio.get('moderation/blocks/');
        final list = res.data as List<dynamic>;
        return list
            .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<void> block(String userId) => _call(() async {
        await _dio.post('moderation/blocks/', data: {'user_id': userId});
      });

  Future<void> unblock(String userId) => _call(() async {
        await _dio.delete('moderation/blocks/$userId/');
      });
}
