import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

final coOrganizerServiceProvider = Provider<CoOrganizerService>((ref) {
  return CoOrganizerService(ref.read(dioProvider));
});

class CoOrganizerInvitationModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final String inviteeName;
  final String invitedByName;
  final String status;

  const CoOrganizerInvitationModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.inviteeName,
    required this.invitedByName,
    required this.status,
  });

  factory CoOrganizerInvitationModel.fromJson(Map<String, dynamic> j) {
    return CoOrganizerInvitationModel(
      id: j['id'] as String,
      eventId: j['event_id'] as String,
      eventTitle: j['event_title'] as String,
      inviteeName: (j['invitee'] as Map?)?['display_name'] as String? ?? '',
      invitedByName: (j['invited_by'] as Map?)?['display_name'] as String? ?? '',
      status: j['status'] as String,
    );
  }
}

class CoOrganizerService {
  final Dio _dio;
  CoOrganizerService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> invite(String eventId, String userId) =>
      _call(() => _dio.post('events/$eventId/co-organizers/invite/', data: {'user_id': userId}));

  Future<List<CoOrganizerInvitationModel>> myInvitations() =>
      _call(() async {
        final res = await _dio.get('events/co-organizer-invitations/');
        final list = res.data as List;
        return list.map((e) => CoOrganizerInvitationModel.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<CoOrganizerInvitationModel> respond(String invitationId, {required bool accept}) =>
      _call(() async {
        final res = await _dio.patch(
          'events/co-organizer-invitations/$invitationId/respond/',
          data: {'accept': accept},
        );
        return CoOrganizerInvitationModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<void> remove(String eventId, String userId) =>
      _call(() => _dio.delete('events/$eventId/co-organizers/$userId/'));
}
