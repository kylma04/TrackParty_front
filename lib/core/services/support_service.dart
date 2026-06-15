import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/support_model.dart';

final supportServiceProvider = Provider<SupportService>((ref) {
  return SupportService(ref.read(dioProvider));
});

class SupportService {
  final Dio _dio;
  SupportService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<SupportTicket>> getTickets() => _call(() async {
        final res = await _dio.get('support/tickets/');
        final list = res.data as List<dynamic>;
        return list
            .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<SupportTicket> getTicket(String id) => _call(() async {
        final res = await _dio.get('support/tickets/$id/');
        return SupportTicket.fromJson(res.data as Map<String, dynamic>);
      });

  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String message,
  }) =>
      _call(() async {
        final res = await _dio.post('support/tickets/', data: {
          'subject': subject,
          'category': category,
          'message': message,
        });
        return SupportTicket.fromJson(res.data as Map<String, dynamic>);
      });

  Future<SupportMessage> sendMessage(String ticketId, String body) =>
      _call(() async {
        final res = await _dio.post(
          'support/tickets/$ticketId/messages/',
          data: {'body': body},
        );
        return SupportMessage.fromJson(res.data as Map<String, dynamic>);
      });

  Future<int> unreadCount() => _call(() async {
        final res = await _dio.get('support/unread-count/');
        return (res.data['unread_count'] as int?) ?? 0;
      });
}

/// Liste de mes tickets.
final supportTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  return ref.read(supportServiceProvider).getTickets();
});

/// Détail d'un ticket (fil de messages).
final supportTicketProvider =
    FutureProvider.autoDispose.family<SupportTicket, String>((ref, id) {
  return ref.read(supportServiceProvider).getTicket(id);
});

/// Nombre de réponses support non lues (badge).
final supportUnreadProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.read(supportServiceProvider).unreadCount();
});
