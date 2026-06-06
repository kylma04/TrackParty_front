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
  final _messageCtrl       = StreamController<ChatMessage>.broadcast();
  final _typingCtrl        = StreamController<TypingEvent>.broadcast();
  final _reactionCtrl      = StreamController<ReactionEvent>.broadcast();
  final _readReceiptCtrl   = StreamController<ReadReceiptEvent>.broadcast();
  bool _connected = false;

  ChatWebSocketService(this.roomId);

  Stream<ChatMessage>      get messages     => _messageCtrl.stream;
  Stream<TypingEvent>      get typing       => _typingCtrl.stream;
  Stream<ReactionEvent>    get reactions    => _reactionCtrl.stream;
  Stream<ReadReceiptEvent> get readReceipts => _readReceiptCtrl.stream;
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
            final type = data['type'] as String?;
            if (type == 'message') {
              _messageCtrl.add(ChatMessage.fromWsEvent(data));
            } else if (type == 'typing') {
              _typingCtrl.add(TypingEvent(
                userId:   data['user_id'] as String,
                userName: data['user_name'] as String,
              ));
            } else if (type == 'reaction') {
              final rawReactions = data['reactions'] as List<dynamic>;
              _reactionCtrl.add(ReactionEvent(
                messageId: data['message_id'] as String,
                reactions: rawReactions
                    .map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
                    .toList(),
              ));
            } else if (type == 'read_receipt') {
              final readAtStr = data['read_at'] as String?;
              if (readAtStr != null) {
                _readReceiptCtrl.add(ReadReceiptEvent(
                  userId: data['user_id'] as String,
                  readAt: DateTime.parse(readAtStr),
                ));
              }
            }
          } catch (_) {}
        },
        onDone:  () => _connected = false,
        onError: (_) => _connected = false,
        cancelOnError: false,
      );
    } catch (_) {
      _connected = false;
    }
  }

  void sendText(String content, {bool attachEvent = true}) {
    _send({'type': 'text', 'content': content, 'attach_event': attachEvent});
  }

  void sendEventInvite(String eventId) {
    _send({'type': 'event_invite', 'content': '', 'event_invite_id': eventId});
  }

  void sendTyping() {
    _send({'type': 'typing'});
  }

  void _send(Map<String, dynamic> payload) {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode(payload));
  }

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
    if (!_messageCtrl.isClosed)      _messageCtrl.close();
    if (!_typingCtrl.isClosed)       _typingCtrl.close();
    if (!_reactionCtrl.isClosed)     _reactionCtrl.close();
    if (!_readReceiptCtrl.isClosed)  _readReceiptCtrl.close();
  }
}

class TypingEvent {
  final String userId;
  final String userName;
  const TypingEvent({required this.userId, required this.userName});
}

class ReactionEvent {
  final String messageId;
  final List<MessageReaction> reactions;
  const ReactionEvent({required this.messageId, required this.reactions});
}

class ReadReceiptEvent {
  final String userId;
  final DateTime readAt;
  const ReadReceiptEvent({required this.userId, required this.readAt});
}
