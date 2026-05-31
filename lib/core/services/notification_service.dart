import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(dioProvider));
});

class NotificationService {
  final Dio _dio;
  NotificationService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<NotificationModel>> getNotifications() => _call(() async {
        final res = await _dio.get('notifications/');
        final data = res.data;
        final List<dynamic> list =
            data is Map ? (data['results'] as List<dynamic>) : (data as List<dynamic>);
        return list.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<int> getUnreadCount() => _call(() async {
        final res = await _dio.get('notifications/unread-count/');
        return (res.data['unread_count'] as int?) ?? 0;
      });

  Future<void> markAllRead() => _call(() async {
        await _dio.patch('notifications/mark-all-read/');
      });

  Future<void> markRead(String id) => _call(() async {
        await _dio.patch('notifications/$id/read/');
      });
}
