import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
        final res  = await _dio.get('chat/rooms/');
        final data = res.data;
        final list = data is Map ? (data['results'] as List<dynamic>) : (data as List<dynamic>);
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
        final data = res.data;
        final List<dynamic> results =
            data is Map ? (data['results'] as List<dynamic>) : (data as List<dynamic>);
        return results
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Marque tous les messages d'une room comme lus (le backend update last_read_at).
  Future<void> markRoomAsRead(String roomId) => _call(() async {
        await _dio.get('chat/rooms/$roomId/messages/', queryParameters: {'page': 1});
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

  Future<ChatMessage> sendImageMessage(String roomId, XFile image) => _call(() async {
        final formData = FormData.fromMap({
          'content': '',
          'message_type': 'image',
          'image': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        });
        final res = await _dio.post(
          'chat/rooms/$roomId/messages/send/',
          data: formData,
        );
        return ChatMessage.fromJson(res.data as Map<String, dynamic>);
      });

  Future<ChatMessage> sendVoiceMessage(
    String roomId,
    String filePath,
    int durationSeconds,
  ) =>
      _call(() async {
        final formData = FormData.fromMap({
          'content': '',
          'message_type': 'voice',
          'voice_duration': durationSeconds,
          'voice_file': await MultipartFile.fromFile(filePath),
        });
        final res = await _dio.post(
          'chat/rooms/$roomId/messages/send/',
          data: formData,
        );
        return ChatMessage.fromJson(res.data as Map<String, dynamic>);
      });
}
