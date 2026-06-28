import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
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

/// WebSocket d'une salle de chat.
///
/// Robustesse mobile : la connexion est **reconnectée automatiquement** quand
/// elle tombe (réseau instable, app mise en arrière-plan par l'OS, timeout du
/// proxy…), avec un backoff exponentiel. Au retour au premier plan
/// (`AppLifecycleState.resumed`), on force une reconnexion immédiate. À chaque
/// reconnexion réussie, on émet sur [reconnected] pour que le provider
/// re-synchronise via REST les messages reçus pendant la coupure (le WS ne
/// rejoue pas l'historique).
class ChatWebSocketService with WidgetsBindingObserver {
  final String roomId;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _messageCtrl       = StreamController<ChatMessage>.broadcast();
  final _typingCtrl        = StreamController<TypingEvent>.broadcast();
  final _reactionCtrl      = StreamController<ReactionEvent>.broadcast();
  final _readReceiptCtrl   = StreamController<ReadReceiptEvent>.broadcast();
  final _reconnectedCtrl   = StreamController<void>.broadcast();

  bool _connected = false;
  bool _everConnected = false;
  bool _manualClose = false;
  int _retryCount = 0;
  Timer? _reconnectTimer;

  // Paliers de backoff (secondes) entre deux tentatives de reconnexion.
  static const _backoff = [1, 2, 4, 8, 15, 30];

  ChatWebSocketService(this.roomId) {
    WidgetsBinding.instance.addObserver(this);
  }

  Stream<ChatMessage>      get messages     => _messageCtrl.stream;
  Stream<TypingEvent>      get typing       => _typingCtrl.stream;
  Stream<ReactionEvent>    get reactions    => _reactionCtrl.stream;
  Stream<ReadReceiptEvent> get readReceipts => _readReceiptCtrl.stream;

  /// Émet à chaque reconnexion réussie (après une coupure). Le provider doit
  /// alors recharger les messages via REST pour rattraper ceux manqués.
  Stream<void> get reconnected => _reconnectedCtrl.stream;

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected || _manualClose) return;
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      final uri = Uri.parse('${Env.wsBaseUrl}/chat/$roomId/?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;

      _sub?.cancel();
      _sub = _channel!.stream.listen(
        _onData,
        onDone:  _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: false,
      );

      // Reconnexion réussie : prévenir le provider pour qu'il rattrape les
      // messages reçus pendant la coupure. (Au tout premier connect, rien à
      // rattraper.)
      if (_everConnected && !_reconnectedCtrl.isClosed) {
        _reconnectedCtrl.add(null);
      }
      _everConnected = true;
    } catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    // Première frame reçue après (re)connexion : la liaison est vivante, on
    // remet le backoff à zéro.
    _retryCount = 0;
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
  }

  void _onDisconnected() {
    _connected = false;
    _sub?.cancel();
    _sub = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualClose) return;
    _reconnectTimer?.cancel();
    final delay = _backoff[_retryCount.clamp(0, _backoff.length - 1)];
    if (_retryCount < _backoff.length - 1) _retryCount++;
    _reconnectTimer = Timer(Duration(seconds: delay), connect);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour au premier plan : l'OS a probablement tué le socket en arrière-plan.
    // On reconnecte tout de suite plutôt que d'attendre le backoff.
    if (state == AppLifecycleState.resumed && !_manualClose && !_connected) {
      _reconnectTimer?.cancel();
      _retryCount = 0;
      connect();
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
    _manualClose = true;
    _reconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _connected = false;
    if (!_messageCtrl.isClosed)      _messageCtrl.close();
    if (!_typingCtrl.isClosed)       _typingCtrl.close();
    if (!_reactionCtrl.isClosed)     _reactionCtrl.close();
    if (!_readReceiptCtrl.isClosed)  _readReceiptCtrl.close();
    if (!_reconnectedCtrl.isClosed)  _reconnectedCtrl.close();
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
