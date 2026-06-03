import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/chat_model.dart';
import '../../core/providers/auth_provider.dart' show authNotifierProvider, AuthAuthenticated;
import '../../core/providers/chat_provider.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/invitation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  int _tab = 0;

  static const _tabLabels = ['DM', 'Événements', 'Communautés'];
  static const _tabTypes  = ['private', 'event', 'community'];

  void _showNewConversationSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _NewConversationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabs(context, roomsAsync),
            Expanded(
              child: roomsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
                ),
                error: (e, _) => _buildError(context),
                data: (rooms) {
                  final filtered = rooms
                      .where((r) => r.roomType == _tabTypes[_tab])
                      .toList();
                  if (filtered.isEmpty) return _buildEmpty(context);
                  return _buildList(context, filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 12),
      child: Row(
        children: [
          Text('Messages',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: context.tpInk, letterSpacing: -0.8)),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Voir mes invitations',
            child: GestureDetector(
              onTap: () => context.push('/invitations'),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: context.tpCard,
                    borderRadius: BorderRadius.circular(12), boxShadow: Shadows.sm),
                child: Icon(PhosphorIcons.envelope(), color: kAccent, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Nouvelle conversation',
            child: GestureDetector(
              onTap: () => _showNewConversationSheet(context),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(12)),
                child: Icon(PhosphorIcons.pencilSimple(), color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────
  Widget _buildTabs(BuildContext context, AsyncValue<List<ChatRoomModel>> roomsAsync) {
    final rooms = roomsAsync.valueOrNull ?? [];
    final counts = [
      rooms.where((r) => r.isPrivate).length,
      rooms.where((r) => r.isEvent).length,
      rooms.where((r) => r.isCommunity).length,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 8),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _tab;
          return Expanded(
            child: Semantics(
              label: '${_tabLabels[i]}, ${counts[i]} conversations',
              selected: active,
              button: true,
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  decoration: BoxDecoration(
                    gradient: active ? trackpartyGradient : null,
                    color: active ? null : context.tpCard,
                    borderRadius: BorderRadius.circular(12),
                    border: active ? null : Border.all(color: context.tpHair),
                    boxShadow: active
                        ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 12, offset: Offset(0, 4))]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_tabLabels[i],
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                            color: active ? Colors.white : context.tpInk)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.25)
                              : kPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${counts[i]}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                              color: active ? Colors.white : kPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Liste ─────────────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context, List<ChatRoomModel> rooms) {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () => ref.read(chatRoomsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
        itemCount: rooms.length,
        itemBuilder: (_, i) => _ChatRow(
          room: rooms[i],
          onTap: () => context.push('/chat/${rooms[i].id}'),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final labels = ['conversation', 'groupe événement', 'communauté'];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Aucun ${labels[_tab]}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 4),
          Text('Participe à un événement pour rejoindre son chat !',
            style: TextStyle(fontSize: 13, color: context.tpInkSub),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Impossible de charger les messages',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInk)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => ref.read(chatRoomsProvider.notifier).refresh(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(12)),
              child: const Text('Réessayer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nouvelle conversation ─────────────────────────────────────────────────────

class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet();

  @override
  ConsumerState<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<_NewConversationSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  // Statut des connexions : userId → 'accepted' | 'pending'
  final Map<String, String> _connections = {};
  bool _loadingConnections = true;

  // Recherche
  List<UserSearchResult> _results = [];
  bool _searching = false;

  // Actions en cours
  String? _acting;          // userId en cours de traitement
  final Set<String> _done = {}; // userIds venant d'être invités

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Chargement des connexions ───────────────────────────────────────────────

  Future<void> _loadConnections() async {
    final service = ref.read(invitationServiceProvider);

    // Chaque appel est indépendant : une erreur sur l'un n'empêche pas les autres
    Future<List<InvitationModel>> safe(Future<List<InvitationModel>> f) =>
        f.onError((_, __) => []);

    final sentAccepted     = await safe(service.getInvitations(direction: 'sent',     status: 'accepted'));
    final receivedAccepted = await safe(service.getInvitations(direction: 'received', status: 'accepted'));
    final sentPending      = await safe(service.getInvitations(direction: 'sent',     status: 'pending'));
    final receivedPending  = await safe(service.getInvitations(direction: 'received', status: 'pending'));

    final auth = ref.read(authNotifierProvider).valueOrNull;
    final myId = auth is AuthAuthenticated ? auth.user.id : '';
    final map  = <String, String>{};

    // Invitations acceptées dans les 2 sens → peut envoyer un message
    for (final inv in [...sentAccepted, ...receivedAccepted]) {
      final otherId = inv.sender.id == myId ? inv.receiver.id : inv.sender.id;
      if (otherId.isNotEmpty) map[otherId] = 'accepted';
    }

    // Invitations en attente dans les 2 sens → bouton désactivé
    for (final inv in [...sentPending, ...receivedPending]) {
      final otherId = inv.sender.id == myId ? inv.receiver.id : inv.sender.id;
      if (otherId.isNotEmpty && !map.containsKey(otherId)) {
        map[otherId] = 'pending';
      }
    }

    if (mounted) setState(() { _connections.addAll(map); _loadingConnections = false; });
  }

  // ── Recherche ───────────────────────────────────────────────────────────────

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ref.read(invitationServiceProvider).searchUsers(q.trim());
      if (mounted) setState(() { _results = results; _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _openDm(UserSearchResult user) async {
    if (_acting != null) return;
    setState(() => _acting = user.id);
    try {
      final room = await ref.read(chatServiceProvider).getOrCreatePrivateRoom(user.id);
      if (mounted) {
        Navigator.pop(context);
        context.push('/chat/${room.id}');
        ref.read(chatRoomsProvider.notifier).refresh();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _acting = null);
    }
  }

  Future<void> _invite(UserSearchResult user) async {
    if (_acting != null || _done.contains(user.id)) return;
    setState(() => _acting = user.id);
    try {
      await ref.read(invitationServiceProvider).sendInvitation(receiverId: user.id);
      if (mounted) {
        setState(() {
          _done.add(user.id);
          _connections[user.id] = 'pending';
          _acting = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invitation envoyée à ${user.displayName} ✉️'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = null);

      final msg = e is ApiException ? e.message : 'Erreur lors de l\'envoi de l\'invitation';

      // Si déjà connectés ou invitation existante, rafraîchir le statut
      if (e is ApiException) {
        if (msg.contains('connectés')) {
          setState(() => _connections[user.id] = 'accepted');
        } else if (msg.contains('attente')) {
          setState(() => _connections[user.id] = 'pending');
        } else {
          // Rafraîchir pour être sûr du vrai statut
          _loadConnections();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: kError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        Sp.md, 12, Sp.md,
        Sp.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 44, height: 5,
              decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 16),

            // Titre
            Row(
              children: [
                Text('Nouveau message',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: context.tpInk, letterSpacing: -0.5)),
                const Spacer(),
                if (_loadingConnections)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
                  ),
              ],
            ),

            const SizedBox(height: 4),
            Text(
              'Cherche un utilisateur. Tu peux lui écrire si une invitation est acceptée.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub),
            ),

            const SizedBox(height: 16),

            // Champ de recherche
            Container(
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.tpHair),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
                      decoration: InputDecoration(
                        hintText: 'Recherche par nom…',
                        hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: _onSearch,
                    ),
                  ),
                  if (_searching)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Résultats
            if (_results.isEmpty && !_searching && _ctrl.text.length >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucun utilisateur trouvé',
                  style: TextStyle(fontSize: 14, color: context.tpInkSub, fontWeight: FontWeight.w600)),
              )
            else if (_results.isEmpty && _ctrl.text.length < 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Commence à taper pour chercher…',
                  style: TextStyle(fontSize: 13, color: context.tpInkMute, fontWeight: FontWeight.w600)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _buildUserRow(_results[i]),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(UserSearchResult user) {
    final status  = _connections[user.id];
    final acting  = _acting == user.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          TpAvatar(name: user.displayName, imageUrl: user.avatarUrl, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.tpInk)),
                if (user.isPromoter)
                  Text('Promoteur', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary)),
                _StatusBadge(status: status),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ActionButton(
            status: status,
            acting: acting,
            onMessage: () => _openDm(user),
            onInvite:  () => _invite(user),
          ),
        ],
      ),
    );
  }
}

// ── Badge de statut ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    final (label, color) = switch (status!) {
      'accepted' => ('✓ Connecté', kSuccess),
      'pending'  => ('⏳ En attente', context.tpInkMute),
      _          => ('', context.tpInkMute),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Text(label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
  }
}

// ── Bouton d'action ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String? status;
  final bool acting;
  final VoidCallback onMessage;
  final VoidCallback onInvite;

  const _ActionButton({
    required this.status,
    required this.acting,
    required this.onMessage,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    if (acting) {
      return const SizedBox(
        width: 80, height: 36,
        child: Center(child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
        )),
      );
    }

    if (status == 'accepted') {
      return GestureDetector(
        onTap: onMessage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.chatCircle(), color: Colors.white, size: 14),
              const SizedBox(width: 5),
              const Text('Message',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.tpHair,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('En attente',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInkMute)),
      );
    }

    // Pas de connexion → bouton Inviter
    return GestureDetector(
      onTap: onInvite,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: trackpartyGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 14),
            const SizedBox(width: 5),
            const Text('Inviter',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Chat row ──────────────────────────────────────────────────────────────────

String _fmtTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'maintenant';
  if (diff.inHours < 1)   return '${diff.inMinutes} min';
  if (diff.inDays < 1)    return DateFormat('HH:mm').format(dt);
  if (diff.inDays == 1)   return 'Hier';
  if (diff.inDays < 7)    return DateFormat('EEE', 'fr_FR').format(dt);
  return DateFormat('d MMM', 'fr_FR').format(dt);
}

class _ChatRow extends StatelessWidget {
  final ChatRoomModel room;
  final VoidCallback onTap;

  const _ChatRow({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGroup = !room.isPrivate;
    final otherMember = room.membersPreview.isNotEmpty ? room.membersPreview.first : null;

    return Semantics(
      button: true,
      label: '${room.displayName}. ${room.lastMessage?.content ?? ''}. '
          '${room.unreadCount > 0 ? '${room.unreadCount} non lus.' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                // Avatar
                isGroup
                    ? Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: trackpartyGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(PhosphorIcons.users(), color: Colors.white, size: 24),
                      )
                    : TpAvatar(name: otherMember?.displayName ?? room.displayName, size: 52),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                            color: context.tpInk, letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Text(
                        room.lastMessage != null
                            ? '${room.lastMessage!.senderName.split(' ').first}: ${room.lastMessage!.content}'
                            : 'Aucun message',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: room.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                          color: room.unreadCount > 0 ? context.tpInk : context.tpInkSub,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right — time + badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (room.lastMessage != null)
                      Text(
                        _fmtTime(room.lastMessage!.createdAt),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: room.unreadCount > 0 ? kPrimary : context.tpInkMute),
                      ),
                    const SizedBox(height: 4),
                    if (room.unreadCount > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(11)),
                        alignment: Alignment.center,
                        child: Text('${room.unreadCount}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
