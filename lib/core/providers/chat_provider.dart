import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';

// ── Liste des rooms ───────────────────────────────────────────────────────────

final chatRoomsProvider =
    AsyncNotifierProvider<ChatRoomsNotifier, List<ChatRoomModel>>(
        ChatRoomsNotifier.new);

class ChatRoomsNotifier extends AsyncNotifier<List<ChatRoomModel>> {
  @override
  Future<List<ChatRoomModel>> build() => _load();

  Future<List<ChatRoomModel>> _load() =>
      ref.read(chatServiceProvider).getRooms();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

// ── Thread d'un room (messages + WebSocket) ───────────────────────────────────

final chatThreadProvider = AsyncNotifierProvider.family<ChatThreadNotifier,
    List<ChatMessage>, String>(ChatThreadNotifier.new);

class ChatThreadNotifier extends FamilyAsyncNotifier<List<ChatMessage>, String> {
  StreamSubscription<ChatMessage>? _wsSub;

  String get roomId => arg;

  @override
  Future<List<ChatMessage>> build(String arg) async {
    final messages = await ref.read(chatServiceProvider).getMessages(arg);
    // Les messages sont renvoyés du plus récent au plus ancien — on inverse
    final sorted = messages.reversed.toList();

    // Connecter WebSocket
    final ws = ref.watch(chatWebSocketServiceProvider(arg));
    await ws.connect();
    _wsSub?.cancel();
    _wsSub = ws.messages.listen(_onWsMessage);

    ref.onDispose(() {
      _wsSub?.cancel();
    });

    return sorted;
  }

  void _onWsMessage(ChatMessage msg) {
    final current = state.valueOrNull ?? [];
    // Éviter les doublons (le WS peut renvoyer notre propre message)
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([...current, msg]);
  }

  // Envoi via WS avec fallback REST
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    final ws = ref.read(chatWebSocketServiceProvider(roomId));
    if (ws.isConnected) {
      ws.send(content.trim());
    } else {
      // Fallback REST
      try {
        final msg = await ref
            .read(chatServiceProvider)
            .sendMessage(roomId, content.trim());
        final current = state.valueOrNull ?? [];
        state = AsyncData([...current, msg]);
      } catch (_) {}
    }
  }
}
