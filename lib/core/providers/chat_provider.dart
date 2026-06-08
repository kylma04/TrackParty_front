import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/invitation_service.dart';
import '../services/user_channel_service.dart';
import '../services/chat_websocket_service.dart' show chatWebSocketServiceProvider, ReactionEvent, ReadReceiptEvent;

// ── Dernier "lu" du partenaire dans un DM (roomId → DateTime?) ───────────────

final chatPartnerReadAtProvider =
    StateProvider.family<DateTime?, String>((ref, roomId) => null);

// ── Salle communautaire d'un promoteur ───────────────────────────────────────

final communityRoomProvider = FutureProvider.family<ChatRoomModel, String>((ref, promoterId) {
  return ref.read(chatServiceProvider).getOrCreateCommunityRoom(promoterId);
});

// ── Mise à jour du mode groupe ────────────────────────────────────────────────

final groupModeUpdateProvider = Provider<Future<void> Function(String, String)>((ref) {
  return (roomId, mode) => ref.read(chatServiceProvider).updateGroupMode(roomId, mode);
});

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
  Future<List<ChatRoomModel>> build() async {
    final rooms = await _load();

    // Écouter le canal personnel pour les mises à jour en temps réel
    final userChannel = UserChannelService();
    final roomsSub = userChannel.roomsUpdated.listen((_) => _silentRefresh());
    final msgSub   = userChannel.newMessages.listen((_) => _silentRefresh());
    ref.onDispose(() {
      roomsSub.cancel();
      msgSub.cancel();
    });

    return rooms;
  }

  Future<List<ChatRoomModel>> _load() =>
      ref.read(chatServiceProvider).getRooms();

  Future<void> _silentRefresh() async {
    final updated = await AsyncValue.guard(_load);
    state = updated;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

// ── Thread d'un room (messages + WebSocket) ───────────────────────────────────

final chatThreadProvider = AsyncNotifierProvider.autoDispose
    .family<ChatThreadNotifier, List<ChatMessage>, String>(ChatThreadNotifier.new);

class ChatThreadNotifier extends AutoDisposeFamilyAsyncNotifier<List<ChatMessage>, String> {
  StreamSubscription<ChatMessage>? _wsSub;
  StreamSubscription<ReactionEvent>? _reactionSub;
  StreamSubscription<ReadReceiptEvent>? _readReceiptSub;

  bool _hasMoreOlder = true;
  bool _loadingOlder = false;
  int  _loadedPages  = 1;

  String get roomId => arg;
  bool get hasMoreOlder => _hasMoreOlder;
  bool get loadingOlder => _loadingOlder;

  @override
  Future<List<ChatMessage>> build(String arg) async {
    _hasMoreOlder = true;
    _loadedPages  = 1;

    unawaited(ref.read(chatServiceProvider).markRoomAsRead(arg).catchError((_) {}));

    final messages = await ref.read(chatServiceProvider).getMessages(arg);
    // L'API renvoie les messages les plus récents en premier (page 1 = newest)
    // On inverse pour afficher du plus ancien au plus récent
    final sorted = messages.reversed.toList();
    // Si la page retourne moins de 20 résultats, pas d'historique supplémentaire
    if (messages.length < 20) _hasMoreOlder = false;

    final ws = ref.watch(chatWebSocketServiceProvider(arg));
    await ws.connect();
    _wsSub?.cancel();
    _reactionSub?.cancel();
    _readReceiptSub?.cancel();
    _wsSub = ws.messages.listen(_onWsMessage);
    _reactionSub = ws.reactions.listen(_onWsReaction);
    _readReceiptSub = ws.readReceipts.listen(_onReadReceipt);

    ref.onDispose(() {
      _wsSub?.cancel();
      _reactionSub?.cancel();
      _readReceiptSub?.cancel();
    });

    return sorted;
  }

  void _onWsMessage(ChatMessage msg) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([...current, msg]);
  }

  void _onReadReceipt(ReadReceiptEvent event) {
    final current = ref.read(chatPartnerReadAtProvider(roomId));
    if (current == null || event.readAt.isAfter(current)) {
      ref.read(chatPartnerReadAtProvider(roomId).notifier).state = event.readAt;
    }
  }

  void _onWsReaction(ReactionEvent event) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((m) {
      if (m.id == event.messageId) return m.copyWith(reactions: event.reactions);
      return m;
    }).toList());
  }

  Future<void> loadOlderMessages() async {
    if (!_hasMoreOlder || _loadingOlder) return;
    _loadingOlder = true;
    try {
      final nextPage = _loadedPages + 1;
      final older = await ref.read(chatServiceProvider).getMessages(arg, page: nextPage);
      if (older.length < 20) _hasMoreOlder = false;
      if (older.isEmpty) return;
      _loadedPages = nextPage;
      final current = state.valueOrNull ?? [];
      // older: newest-first → reversed = oldest-first → préfixer à la liste actuelle
      final olderSorted = older.reversed.toList();
      // Éviter les doublons (les WS peuvent avoir déjà ajouté des messages)
      final existingIds = current.map((m) => m.id).toSet();
      final deduped = olderSorted.where((m) => !existingIds.contains(m.id)).toList();
      state = AsyncData([...deduped, ...current]);
    } catch (_) {
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> sendTextMessage(String content, {bool attachEvent = true}) async {
    if (content.trim().isEmpty) return;
    final ws = ref.read(chatWebSocketServiceProvider(roomId));
    if (ws.isConnected) {
      ws.sendText(content.trim(), attachEvent: attachEvent);
    } else {
      try {
        final msg = await ref.read(chatServiceProvider).sendMessage(
          roomId, content.trim(), attachEvent: attachEvent);
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

  Future<void> sendImageMessage(XFile image, {bool attachEvent = true}) async {
    try {
      final msg = await ref.read(chatServiceProvider)
          .sendImageMessage(roomId, image, attachEvent: attachEvent);
      _addMessage(msg);
    } catch (_) {}
  }

  Future<void> sendVoiceMessage(String filePath, int durationSeconds, {bool attachEvent = true}) async {
    try {
      final msg = await ref.read(chatServiceProvider).sendVoiceMessage(
        roomId, filePath, durationSeconds, attachEvent: attachEvent);
      _addMessage(msg);
    } catch (_) {}
  }

  void _addMessage(ChatMessage msg) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([...current, msg]);
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      final reactions = await ref.read(chatServiceProvider).reactToMessage(roomId, messageId, emoji);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.map((m) {
        if (m.id == messageId) return m.copyWith(reactions: reactions);
        return m;
      }).toList());
    } catch (_) {}
  }

  void updateInvitationStatus(String invitationId, String newStatus) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((m) {
      if (m.invitationId == invitationId) return m.copyWith(invitationStatus: newStatus);
      return m;
    }).toList());
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

  Future<void> respondToInvitation(
    String invitationId,
    String action, {
    String? contributionItemId,
    int quantity = 1,
  }) async {
    // Retrait optimiste : l'invitation disparaît immédiatement
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((inv) => inv.id != invitationId).toList());

    try {
      await ref.read(invitationServiceProvider).respondToInvitation(
        invitationId,
        action,
        contributionItemId: contributionItemId,
        quantity: quantity,
      );
    } catch (_) {
      // En cas d'erreur, recharger la liste
      refresh();
      rethrow;
    }
  }
}
