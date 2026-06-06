import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/ticket_model.dart';

final ticketServiceProvider = Provider<TicketService>((ref) {
  return TicketService(ref.read(dioProvider));
});

class TicketService {
  final Dio _dio;
  TicketService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TicketModel> getMyTicket(String eventId) => _call(() async {
        final res = await _dio.get('events/$eventId/my-ticket/');
        return TicketModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<List<TicketModel>> getMyTickets() => _call(() async {
        final res = await _dio.get('events/my-tickets/');
        return (res.data as List<dynamic>)
            .map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<CheckinResult> checkin(String eventId, String token) => _call(() async {
        final res = await _dio.post(
          'events/$eventId/checkin/',
          data: {'token': token},
        );
        return CheckinResult.fromJson(res.data as Map<String, dynamic>);
      });

  Future<List<TicketModel>> getCheckins(String eventId) => _call(() async {
        final res = await _dio.get('events/$eventId/checkins/');
        return (res.data as List<dynamic>)
            .map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<List<EventStaffModel>> getStaff(String eventId) => _call(() async {
        final res = await _dio.get('events/$eventId/staff/');
        return (res.data as List<dynamic>)
            .map((e) => EventStaffModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<EventStaffModel> addStaff(String eventId, String userId) => _call(() async {
        final res = await _dio.post('events/$eventId/staff/', data: {'user_id': userId});
        return EventStaffModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<void> removeStaff(String eventId, String userId) => _call(() async {
        await _dio.delete('events/$eventId/staff/$userId/');
      });
}
