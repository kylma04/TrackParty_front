import 'dart:async';

import 'package:flutter/foundation.dart' show unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/invitation_service.dart';
import '../services/chat_websocket_service.dart';

// ── Room par ID ───────────────────────────────────────────────────────────────

final chatRoomByIdProvider = Provider.family<ChatRoomModel?, String>((ref, roomId) {
  final rooms = ref.watch(chatRoomsProvider).valueOrNull ?? [];
  for (final r in rooms) {
    if (r.id == roomId) return r;
  }
  return null;
});

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
    // Marque comme lu côté REST dès l'ouverture (le WS fait de même)
    unawaited(ref.read(chatServiceProvider).markRoomAsRead(arg).catchError((_) {}));

    final messages = await ref.read(chatServiceProvider).getMessages(arg);
    final sorted = messages.reversed.toList();

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
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([...current, msg]);
  }

  Future<void> sendTextMessage(String content) async {
    if (content.trim().isEmpty) return;
    final ws = ref.read(chatWebSocketServiceProvider(roomId));
    if (ws.isConnected) {
      ws.sendText(content.trim());
    } else {
      try {
        final msg = await ref.read(chatServiceProvider).sendMessage(roomId, content.trim());
        _addMessage(msg);
      } catch (_) {}
    }
  }

  Future<void> sendEventInvite(String eventId) async {
    final ws = ref.read(chatWebSocketServiceProvider(roomId));
    if (ws.isConnected) {
      ws.sendEventInvite(eventId);
    } else {
      try {
        final msg = await ref.read(chatServiceProvider).sendMessage(
          roomId,
          '',
          messageType: 'event_invite',
          eventInviteId: eventId,
        );
        _addMessage(msg);
      } catch (_) {}
    }
  }

  Future<void> sendImageMessage(XFile image) async {
    try {
      final msg = await ref.read(chatServiceProvider).sendImageMessage(roomId, image);
      _addMessage(msg);
    } catch (_) {}
  }

  Future<void> sendVoiceMessage(String filePath, int durationSeconds) async {
    try {
      final msg = await ref.read(chatServiceProvider).sendVoiceMessage(
        roomId,
        filePath,
        durationSeconds,
      );
      _addMessage(msg);
    } catch (_) {}
  }

  void _addMessage(ChatMessage msg) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([...current, msg]);
  }
}

// ── Invitations reçues ───────────────────────────────────────────────────────

final invitationsProvider =
    AsyncNotifierProvider<InvitationsNotifier, List<InvitationModel>>(
        InvitationsNotifier.new);

class InvitationsNotifier extends AsyncNotifier<List<InvitationModel>> {
  @override
  Future<List<InvitationModel>> build() =>
      ref.read(invitationServiceProvider).getInvitations();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(invitationServiceProvider).getInvitations(),
    );
  }

  Future<void> respondToInvitation(String invitationId, String action) async {
    final updated = await ref
        .read(invitationServiceProvider)
        .respondToInvitation(invitationId, action);

    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((inv) => inv.id == invitationId ? updated : inv).toList(),
    );
  }
}
