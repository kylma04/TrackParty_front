import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import '../models/chat_model.dart';
import 'token_storage.dart';

final chatWebSocketServiceProvider = Provider.autoDispose
    .family<ChatWebSocketService, String>((ref, roomId) {
  final service = ChatWebSocketService(roomId);
  ref.onDispose(service.disconnect);
  return service;
});

class ChatWebSocketService {
  final String roomId;

  WebSocketChannel? _channel;
  final _controller = StreamController<ChatMessage>.broadcast();
  bool _connected = false;

  ChatWebSocketService(this.roomId);

  Stream<ChatMessage> get messages => _controller.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      final uri = Uri.parse('${Env.wsBaseUrl}/chat/$roomId/?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;

      _channel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            if (data['type'] == 'message') {
              _controller.add(ChatMessage.fromWsEvent(data));
            }
          } catch (_) {}
        },
        onDone: () => _connected = false,
        onError: (_) => _connected = false,
        cancelOnError: false,
      );
    } catch (_) {
      _connected = false;
    }
  }

  void send(String content, {String messageType = 'text', String? eventInviteId}) {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': messageType,
      'content': content,
      'event_invite_id': eventInviteId,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
    if (!_controller.isClosed) _controller.close();
  }
}
