import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/chat_model.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.read(dioProvider));
});

class ChatService {
  final Dio _dio;
  ChatService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ChatRoomModel>> getRooms() => _call(() async {
        final res = await _dio.get('chat/rooms/');
        final list = res.data as List<dynamic>;
        return list.map((e) => ChatRoomModel.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<ChatRoomModel> getOrCreatePrivateRoom(String userId) => _call(() async {
        final res = await _dio.post('chat/rooms/private/', data: {'user_id': userId});
        return ChatRoomModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<List<ChatMessage>> getMessages(String roomId, {int page = 1}) => _call(() async {
        final res = await _dio.get(
          'chat/rooms/$roomId/messages/',
          queryParameters: {'page': page},
        );
        // Réponse paginée ou liste directe
        final data = res.data;
        final List<dynamic> results =
            data is Map ? (data['results'] as List<dynamic>) : (data as List<dynamic>);
        return results
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<ChatMessage> sendMessage(
    String roomId,
    String content, {
    String messageType = 'text',
    String? eventInviteId,
  }) =>
      _call(() async {
        final res = await _dio.post('chat/rooms/$roomId/messages/send/', data: {
          'content': content,
          'message_type': messageType,
          'event_invite_id': eventInviteId,
        });
        return ChatMessage.fromJson(res.data as Map<String, dynamic>);
      });
}
