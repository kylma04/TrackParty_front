import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import 'call_service.dart';
import 'token_storage.dart';

/// Canal WebSocket personnel de l'utilisateur.
/// Reçoit les appels entrants et les annulations d'appels.
class UserChannelService {
  static final UserChannelService _instance = UserChannelService._();
  factory UserChannelService() => _instance;
  UserChannelService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  Timer? _reconnectTimer;

  Future<void> connect() async {
    if (_connected) return;
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      final uri = Uri.parse('${Env.wsBaseUrl}/user/?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;

      _sub = _channel!.stream.listen(
        _onMessage,
        onDone:  _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: false,
      );
    } catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'call_invite') {
        CallService().notifyIncomingCall(
          callId:          data['call_id'] as String,
          callType:        data['call_type'] as String,
          roomId:          data['room_id'] as String,
          callerName:      data['caller_name'] as String?,
          callerAvatarUrl: data['caller_avatar'] as String?,
        );
      } else if (type == 'call_cancelled') {
        CallService().cancelIncomingCall(data['call_id'] as String);
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
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _connected = false;
  }
}
