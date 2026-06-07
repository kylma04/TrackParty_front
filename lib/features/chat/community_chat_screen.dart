import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/models/chat_model.dart';
import '../../core/providers/auth_provider.dart' show authNotifierProvider, AuthAuthenticated;
import '../../core/providers/chat_provider.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/chat_websocket_service.dart';
import 'chat_thread_screen.dart' show EventModeBanner;
import 'room_members_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_toast.dart';

class CommunityChatScreen extends ConsumerStatefulWidget {
  final String promoterId;
  const CommunityChatScreen({super.key, required this.promoterId});

  @override
  ConsumerState<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _typingUserName;
  Timer?  _typingClearTimer;
  StreamSubscription<TypingEvent>? _typingSub;

  bool _attachEvent = true;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _typingClearTimer?.cancel();
    _typingSub?.cancel();
    super.dispose();
  }

  Timer? _typingTimer;

  void _listenTyping(String roomId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(chatWebSocketServiceProvider(roomId));
      _typingSub?.cancel();
      _typingSub = ws.typing.listen((e) {
        if (!mounted) return;
        setState(() => _typingUserName = e.userName);
        _typingClearTimer?.cancel();
        _typingClearTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _typingUserName = null);
        });
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _changeAvatar(ChatRoomModel room) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    try {
      await ref.read(chatServiceProvider).updateCommunityAvatar(room.id, file);
      ref.invalidate(communityRoomProvider(widget.promoterId));
    } catch (_) {
      if (mounted) {
        TpToast.error(context, 'Impossible de mettre à jour la photo');
      }
    }
  }

  Future<void> _renameCommunity(ChatRoomModel room) async {
    final newName = await _showRenameSheet(context, room.displayName);
    if (newName == null || !mounted) return;
    try {
      await ref.read(chatServiceProvider).updateCommunityName(room.id, newName);
      ref.invalidate(communityRoomProvider(widget.promoterId));
    } catch (_) {
      if (mounted) {
        TpToast.error(context, 'Impossible de renommer la communauté');
      }
    }
  }

  void _showMembers(BuildContext context, ChatRoomModel room) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RoomMembersSheet(room: room),
    );
  }

  Future<void> _sendPost(String roomId) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await ref.read(chatThreadProvider(roomId).notifier)
        .sendTextMessage(text, attachEvent: _attachEvent);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(communityRoomProvider(widget.promoterId));
    return roomAsync.when(
      loading: () => _loadingScaffold(context),
      error: (e, _)  => _errorScaffold(context),
      data:  (room)  => _buildScreen(context, room),
    );
  }

  // ── Écrans d'attente / erreur ─────────────────────────────────────────────

  Widget _loadingScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildHeader(context, null),
          const Expanded(child: Center(
            child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
          )),
        ],
      ),
    );
  }

  Widget _errorScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildHeader(context, null),
          Expanded(child: Center(
            child: Text('Impossible de charger la communauté',
              style: TextStyle(color: context.tpInkSub)),
          )),
        ],
      ),
    );
  }

  // ── Écran principal ───────────────────────────────────────────────────────

  Widget _buildScreen(BuildContext context, ChatRoomModel room) {
    // Abonner au typing WS une seule fois
    if (_typingSub == null) _listenTyping(room.id);

    final messagesAsync = ref.watch(chatThreadProvider(room.id));
    final canPost = room.isAdmin || !room.isBroadcast;

    ref.listen(chatThreadProvider(room.id), (_, next) {
      if (next is AsyncData) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildHeader(context, room),
          if (!canPost) _buildReadOnlyBanner(room),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Erreur de chargement',
                  style: TextStyle(color: context.tpInkSub))),
              data: (msgs) => _buildMessages(context, msgs, room, canPost),
            ),
          ),
          if (_typingUserName != null && canPost)
            _TypingBanner(userName: _typingUserName!),
          if (canPost) _buildComposer(context, room.id, room.isAdmin),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, ChatRoomModel? room) {
    final name    = room?.displayName ?? room?.promoterName ?? 'Communauté';
    final members = room?.membersCount ?? 0;

    return Container(
      decoration: const BoxDecoration(gradient: trackpartyGradient),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 12),
              child: Row(
                children: [
                  Semantics(
                    button: true, label: 'Retour',
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(PhosphorIcons.caretLeft(), color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: 'Changer l\'avatar de la communauté',
                    child: GestureDetector(
                    onTap: room?.isAdmin == true ? () => _changeAvatar(room!) : null,
                    child: Stack(
                      children: [
                        TpAvatar(
                          name: name,
                          imageUrl: room?.roomAvatarUrl ?? room?.promoterAvatarUrl,
                          size: 44,
                        ),
                        if (room?.isAdmin == true)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(
                                color: kPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Icon(PhosphorIcons.camera(PhosphorIconsStyle.fill),
                                  color: Colors.white, size: 8),
                            ),
                          ),
                      ],
                    ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.3)),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(Radii.xs),
                            ),
                            child: const Text('★',
                              style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)),
                          ),
                          if (room?.isAdmin == true) ...[
                            const SizedBox(width: 6),
                            Semantics(
                              button: true,
                              label: 'Renommer la communauté',
                              child: GestureDetector(
                                onTap: () => _renameCommunity(room!),
                                child: Container(
                                  width: 28, height: 28,
                                  alignment: Alignment.center,
                                  child: Icon(PhosphorIcons.pencilSimple(),
                                      color: Colors.white.withValues(alpha: 0.8), size: 14),
                                ),
                              ),
                            ),
                          ],
                        ]),
                        if (room != null)
                          Text(
                            '$members membre${members > 1 ? 's' : ''} · Communauté publique',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85)),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true, label: 'Voir les membres',
                    child: GestureDetector(
                      onTap: room == null ? null : () => _showMembers(context, room),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(PhosphorIcons.usersThree(), color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bannière lecture seule ────────────────────────────────────────────────

  Widget _buildReadOnlyBanner(ChatRoomModel room) {
    final name = room.promoterName ?? 'le promoteur';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 10, Sp.md, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kWarning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: kWarning.withValues(alpha: 0.33)),
        ),
        child: Row(
          children: [
            const Text('🔔', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lecture seule · Seul $name peut poster.',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: kWarning, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Liste de messages ─────────────────────────────────────────────────────

  Widget _buildMessages(BuildContext context, List<ChatMessage> messages, ChatRoomModel room, bool canPost) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final myId = authState is AuthAuthenticated ? authState.user.id : null;

    if (messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📢', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Aucune annonce pour l\'instant',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInkSub)),
          const SizedBox(height: 4),
          Text('Les annonces du promoteur apparaîtront ici',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkMute)),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg     = messages[i];
        final showDay = i == 0 || !_sameDay(messages[i - 1].createdAt, msg.createdAt);
        return Column(children: [
          if (showDay) _buildDaySeparator(context, msg.createdAt),
          if (msg.isAnnouncement)
            _CommunityPost(message: msg, roomId: room.id)
          else
            _CommunityComment(message: msg, isMe: msg.sender.id == myId, roomId: room.id),
          const SizedBox(height: 8),
        ]);
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDaySeparator(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    String label;
    if (_sameDay(dt, now)) {
      label = "Aujourd'hui";
    } else if (_sameDay(dt, now.subtract(const Duration(days: 1)))) {
      label = 'Hier';
    } else {
      label = DateFormat('d MMMM', 'fr_FR').format(dt);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
        ),
      ),
    );
  }

  // ── Composer (admins seulement) ───────────────────────────────────────────

  Widget _buildComposer(BuildContext context, String roomId, bool isAdmin) {
    final hasText  = _ctrl.text.isNotEmpty;
    final hintText = isAdmin
        ? (_attachEvent ? 'Poster une annonce…' : 'Écrire un message…')
        : 'Commenter…';

    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin)
            EventModeBanner(
              attachEvent: _attachEvent,
              onToggle: () => setState(() => _attachEvent = !_attachEvent),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
                10 + MediaQuery.of(context).padding.bottom),
            child: Row(
        children: [
          const TpAvatar(name: 'Moi', size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 4),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkMute),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _sendPost(roomId),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (hasText)
            Semantics(
              button: true,
              label: 'Envoyer le message',
              child: GestureDetector(
              onTap: () => _sendPost(roomId),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(Radii.button),
                  boxShadow: Shadows.brand,
                ),
                child: Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 20),
              ),
              ),
            )
          else
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(Radii.button),
                border: Border.all(color: context.tpHair),
              ),
              child: Icon(PhosphorIcons.image(), color: context.tpInkMute, size: 20),
            ),
          ],
        ),
        ),
        ],
      ),
    );
  }
}

// ── Post annonce (messages admin) ─────────────────────────────────────────────

class _CommunityPost extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;

  const _CommunityPost({required this.message, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('HH:mm', 'fr_FR').format(message.createdAt.toLocal());
    final data = message.eventInviteData;

    return Semantics(
      label: 'Message de ${message.sender.displayName}',
      child: GestureDetector(
      onLongPress: () => _showReactionPicker(context, ref, message.id, roomId),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: Shadows.md,
        border: Border.all(color: kPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auteur
          Row(
            children: [
              TpAvatar(
                name: message.sender.displayName,
                imageUrl: message.sender.avatarUrl,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(message.sender.displayName,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(Radii.xs)),
                        child: const Text('★',
                          style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.xs),
                        ),
                        child: const Text('Admin',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimary)),
                      ),
                    ]),
                    Text(time,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                  ],
                ),
              ),
            ],
          ),
          // Texte
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(message.content,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: context.tpInk, height: 1.45)),
          ],
          // Carte événement si attachée
          if (data != null) ...[
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: 'Voir l\'événement ${data.title}',
              child: GestureDetector(
              onTap: () => context.push('/event/${data.id}'),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary.withValues(alpha: 0.08), kAccent.withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Radii.button),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.title,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInk),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            DateFormat('EEE d MMM · HH\'h\'', 'fr_FR').format(data.startAt.toLocal()),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub),
                          ),
                        ],
                      ),
                    ),
                    Icon(PhosphorIcons.caretRight(), color: context.tpInkMute, size: 14),
                  ],
                ),
              ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _ReactionRow(message: message, roomId: roomId),
        ],
      ),
    ),
    ),
    );
  }

  static void _showReactionPicker(BuildContext context, WidgetRef ref, String messageId, String roomId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityReactionPicker(messageId: messageId, roomId: roomId),
    );
  }
}

// ── Commentaire membre ────────────────────────────────────────────────────────

class _CommunityComment extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;
  final String roomId;
  const _CommunityComment({required this.message, required this.isMe, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReactions = message.reactions.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TpAvatar(
            name: message.sender.displayName,
            imageUrl: message.sender.avatarUrl,
            size: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Message de ${message.sender.displayName}',
                  child: GestureDetector(
                  onLongPress: () => _showReactionPicker(context, ref, message.id, roomId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.tpCard,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      boxShadow: Shadows.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(message.sender.displayName,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: context.tpInk)),
                            Text(DateFormat('HH:mm').format(message.createdAt.toLocal()),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(message.content,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: context.tpInk, height: 1.4)),
                      ],
                    ),
                  ),
                ),
                ),
                if (hasReactions)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Wrap(
                      spacing: 4,
                      children: message.reactions.map((r) => Semantics(
                        button: true, label: 'Réaction ${r.emoji} · ${r.count}',
                        child: GestureDetector(
                          onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                              .reactToMessage(message.id, r.emoji),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(Radii.card),
                              border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(r.emoji, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 3),
                              Text('${r.count}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimary)),
                            ]),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showReactionPicker(BuildContext context, WidgetRef ref, String messageId, String roomId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityReactionPicker(messageId: messageId, roomId: roomId),
    );
  }
}

// ── Ligne de réactions ────────────────────────────────────────────────────────

class _ReactionRow extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;

  const _ReactionRow({required this.message, required this.roomId});

  static const _emojis = ['🔥', '❤️', '🎉'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final r in message.reactions)
          Semantics(
            button: true,
            label: 'Réagir avec ${r.emoji}',
            child: GestureDetector(
              onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                  .reactToMessage(message.id, r.emoji),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: context.tpHair),
                ),
                child: Text('${r.emoji} ${r.count}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInk)),
              ),
            ),
          ),
        const Spacer(),
        for (final emoji in _emojis)
          Semantics(
            button: true,
            label: 'Réagir avec $emoji',
            child: GestureDetector(
              onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                  .reactToMessage(message.id, emoji),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Picker de réactions (long-press) ─────────────────────────────────────────

class _CommunityReactionPicker extends ConsumerWidget {
  final String messageId;
  final String roomId;

  const _CommunityReactionPicker({required this.messageId, required this.roomId});

  static const _emojis = ['🔥', '❤️', '🎉', '😂', '👏', '😮', '😢', '👍'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, bottom + 12),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2)),
          ),
          Text('Réagir',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _emojis.map((emoji) => Semantics(
              button: true, label: 'Réagir avec $emoji',
              child: GestureDetector(
                onTap: () {
                  ref.read(chatThreadProvider(roomId).notifier).reactToMessage(messageId, emoji);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: context.tpHair),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet renommage communauté ────────────────────────────────────────

Future<String?> _showRenameSheet(BuildContext context, String initialName) {
  final ctrl = TextEditingController(text: initialName);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom +
          MediaQuery.of(ctx).padding.bottom + 20;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Renommer la communauté',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 80,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Nom de la communauté',
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.tag)),
                  ),
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ),
      );
    },
  );
}

// ── Indicateur de frappe ──────────────────────────────────────────────────────

class _TypingBanner extends StatelessWidget {
  final String userName;
  const _TypingBanner({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md + 34, 0, Sp.md, 4),
      child: Text(
        '$userName est en train d\'écrire…',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: context.tpInkMute, fontStyle: FontStyle.italic),
      ),
    );
  }
}
