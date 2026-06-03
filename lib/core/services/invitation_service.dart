import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/chat_model.dart';

final invitationServiceProvider = Provider<InvitationService>((ref) {
  return InvitationService(ref.read(dioProvider));
});

class InvitationService {
  final Dio _dio;
  InvitationService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Liste des invitations.
  /// [direction] : 'received' (défaut) ou 'sent'
  /// [status]    : null = défaut backend, 'pending', 'accepted', 'refused'
  Future<List<InvitationModel>> getInvitations({
    String direction = 'received',
    String? status,
  }) =>
      _call(() async {
        final params = <String, dynamic>{'direction': direction};
        if (status != null) params['status'] = status;
        final res  = await _dio.get('chat/invitations/', queryParameters: params);
        final data = res.data;
        // Gère les réponses paginées {"results":[...]} ET les listes brutes [...]
        final list = data is Map ? (data['results'] as List<dynamic>) : (data as List<dynamic>);
        return list
            .map((e) => InvitationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Envoie une invitation.
  /// Sans [eventId] → invitation de type DM (demande de contact).
  Future<InvitationModel> sendInvitation({
    required String receiverId,
    String? eventId,
  }) =>
      _call(() async {
        final data = <String, dynamic>{
          'receiver_id':      receiverId,
          'invitation_type':  eventId != null ? 'event' : 'dm',
        };
        if (eventId != null) data['event_id'] = eventId;
        final res = await _dio.post('chat/invitations/', data: data);
        return InvitationModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<InvitationModel> respondToInvitation(
    String invitationId,
    String action, // 'accept' | 'refuse'
  ) =>
      _call(() async {
        final res = await _dio.patch(
          'chat/invitations/$invitationId/respond/',
          data: {'action': action},
        );
        return InvitationModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<List<UserSearchResult>> searchUsers(String query) =>
      _call(() async {
        if (query.trim().length < 2) return [];
        final res = await _dio.get(
          'auth/users/search/',
          queryParameters: {'q': query.trim()},
        );
        final list = res.data as List<dynamic>;
        return list
            .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      });
}
