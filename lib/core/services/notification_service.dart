import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(dioProvider));
});

/// Une page de notifications renvoyée par l'API paginée.
class PaginatedNotifications {
  final List<NotificationModel> results;
  final bool hasMore;
  const PaginatedNotifications({required this.results, required this.hasMore});
}

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

  Future<PaginatedNotifications> getNotifications({int page = 1}) => _call(() async {
        final res = await _dio.get('notifications/', queryParameters: {'page': page});
        final data = res.data;
        if (data is Map) {
          final list = (data['results'] as List<dynamic>);
          return PaginatedNotifications(
            results: list
                .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
                .toList(),
            hasMore: data['next'] != null,
          );
        }
        final list = data as List<dynamic>;
        return PaginatedNotifications(
          results: list
              .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          hasMore: false,
        );
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

  Future<void> deleteNotification(String id) => _call(() async {
        await _dio.delete('notifications/$id/');
      });

  Future<void> clearAll() => _call(() async {
        await _dio.delete('notifications/clear-all/');
      });
}
