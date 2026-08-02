import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/chat_model.dart';
import '../../core/providers/auth_provider.dart' show authNotifierProvider, AuthAuthenticated;
import '../../core/providers/call_history_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/invitation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_skeleton.dart';
import '../../widgets/tp_toast.dart';
import 'contact_picker_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  int _tab = 0;
  final _pageCtrl = PageController();
  final _searchCtrl = TextEditingController();
  String _query = '';

  // null = pas de filtre par type (onglet "Toutes")
  static const _tabLabels = ['Toutes', 'DM', 'Groupes', 'Événements', 'Communautés'];
  static const _tabTypes  = <String?>[null, 'private', 'group', 'event', 'community'];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Change d'onglet en animant le PageView (utilisé par le tap sur un onglet).
  void _goToTab(int i) {
    if (_pageCtrl.hasClients) {
      _pageCtrl.animateToPage(i,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    } else {
      setState(() => _tab = i);
    }
  }

  void _showNewConversationSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NewConversationSheet(onCreateGroup: () => _createGroup(ctx)),
    );
  }

  // ── Créer un groupe ─────────────────────────────────────────────────────────

  Future<void> _createGroup(BuildContext context) async {
    final memberIds = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => const ContactPickerScreen(
          title: 'Nouveau groupe',
          confirmLabel: 'Suivant',
        ),
      ),
    );
    if (memberIds == null || memberIds.isEmpty || !context.mounted) return;

    final name = await _showGroupNameSheet(context);
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    try {
      final room = await ref.read(chatServiceProvider).createGroup(name.trim(), memberIds);
      ref.read(chatRoomsProvider.notifier).refresh();
      if (context.mounted) context.push('/chat/${room.id}');
    } catch (_) {
      if (context.mounted) TpToast.error(context, 'Impossible de créer le groupe');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      floatingActionButton: _buildFab(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchField(context),
            if (_query.isEmpty) _buildTabs(context, roomsAsync),
            Expanded(
              child: roomsAsync.when(
                loading: () => SkList(count: 8, builder: (_) => const SkRowItem()),
                error: (e, _) => _buildError(context),
                data: (rooms) => _query.isNotEmpty
                    ? _buildSearchResults(context, rooms)
                    : PageView.builder(
                        controller: _pageCtrl,
                        // Swipe horizontal → change d'onglet (met à jour l'indicateur).
                        onPageChanged: (i) => setState(() => _tab = i),
                        itemCount: _tabTypes.length,
                        itemBuilder: (_, i) {
                          final type = _tabTypes[i];
                          final filtered = rooms
                              .where((r) => type == null || r.roomType == type)
                              .toList();
                          if (filtered.isEmpty) return _buildEmpty(context, i);
                          return _buildList(context, filtered);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recherche ─────────────────────────────────────────────────────────────
  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: context.tpHair),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
              decoration: InputDecoration(
                hintText: 'Rechercher une discussion…',
                hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          if (_query.isNotEmpty)
            Semantics(
              button: true, label: 'Effacer la recherche',
              child: IconButton(
                icon: Icon(PhosphorIcons.x(), size: 16),
                color: context.tpInkMute,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; }),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, List<ChatRoomModel> rooms) {
    final q = _query.toLowerCase();
    final filtered = rooms.where((r) => r.displayName.toLowerCase().contains(q)).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIcons.magnifyingGlass(), size: 40, color: context.tpInkMute),
            const SizedBox(height: 12),
            Text('Aucune discussion trouvée',
                style: TextStyle(color: context.tpInkSub, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    return _buildList(context, filtered);
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
          _buildCallHistoryButton(context),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Voir mes invitations',
            child: GestureDetector(
              onTap: () => context.push('/invitations'),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.sm),
                child: Icon(PhosphorIcons.envelope(), color: kAccent, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton flottant « nouvelle conversation » (façon WhatsApp) ─────────────
  Widget _buildFab(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nouvelle conversation',
      child: GestureDetector(
        onTap: () => _showNewConversationSheet(context),
        child: Container(
          width: 58, height: 58,
          decoration: const BoxDecoration(
            gradient: trackpartyGradient,
            shape: BoxShape.circle,
            boxShadow: Shadows.brand,
          ),
          child: Icon(PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill), color: Colors.white, size: 26),
        ),
      ),
    );
  }

  // Icône Historique d'appels + pastille "appels manqués non vus".
  Widget _buildCallHistoryButton(BuildContext context) {
    final missed = ref.watch(missedCallsBadgeProvider).valueOrNull ?? 0;
    return Semantics(
      button: true,
      label: missed > 0 ? "Historique d'appels, $missed manqués" : "Historique d'appels",
      child: GestureDetector(
        onTap: () => context.push('/calls/history'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.sm),
              child: Icon(PhosphorIcons.phone(), color: kPrimary, size: 18),
            ),
            if (missed > 0)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: kError,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: context.tpBg, width: 2),
                  ),
                  child: Center(
                    child: Text(missed > 9 ? '9+' : '$missed',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────
  Widget _buildTabs(BuildContext context, AsyncValue<List<ChatRoomModel>> roomsAsync) {
    final rooms = roomsAsync.valueOrNull ?? [];
    final counts = [
      rooms.length,
      rooms.where((r) => r.isPrivate).length,
      rooms.where((r) => r.isGroup).length,
      rooms.where((r) => r.isEvent).length,
      rooms.where((r) => r.isCommunity).length,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabTypes.length, (i) {
            final active = i == _tab;
            return Padding(
              padding: EdgeInsets.only(right: i < _tabTypes.length - 1 ? 8 : 0),
              child: Semantics(
                label: '${_tabLabels[i]}, ${counts[i]} conversations',
                selected: active,
                button: true,
                child: GestureDetector(
                  onTap: () => _goToTab(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? kPrimary : context.tpCard,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: active ? null : Border.all(color: context.tpHair),
                    ),
                    child: Text(_tabLabels[i],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: active ? Colors.white : context.tpInk)),
                  ),
                ),
              ),
            );
          }),
        ),
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
        addAutomaticKeepAlives: false,
        itemBuilder: (_, i) {
          final room = rooms[i];
          final dest = room.isCommunity && room.promoterId != null
              ? '/community/${room.promoterId}'
              : '/chat/${room.id}';
          return _ChatRow(room: room, onTap: () => context.push(dest));
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, int tab) {
    final labels = ['conversation', 'DM', 'groupe', 'groupe événement', 'communauté'];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Aucun ${labels[tab]}',
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
          Semantics(
            button: true,
            label: 'Réessayer',
            child: GestureDetector(
              onTap: () => ref.read(chatRoomsProvider.notifier).refresh(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
                child: const Text('Réessayer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nouvelle conversation ─────────────────────────────────────────────────────

class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet({required this.onCreateGroup});

  final VoidCallback onCreateGroup;

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
        f.onError((_, _) => []);

    final results = await Future.wait([
      safe(service.getInvitations(direction: 'sent',     status: 'accepted')),
      safe(service.getInvitations(direction: 'received', status: 'accepted')),
      safe(service.getInvitations(direction: 'sent',     status: 'pending')),
      safe(service.getInvitations(direction: 'received', status: 'pending')),
    ]);
    final [sentAccepted, receivedAccepted, sentPending, receivedPending] = results;

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
      if (mounted) TpToast.error(context, 'Impossible d\'ouvrir la conversation');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ));
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
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

            // Nouveau groupe
            Semantics(
              button: true,
              label: 'Créer un nouveau groupe',
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () {
                  Navigator.pop(context);
                  widget.onCreateGroup();
                },
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.fill), color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Nouveau groupe',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: context.tpHair, height: 1),
            const SizedBox(height: 14),

            // Champ de recherche
            Container(
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(Radii.button),
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
      'pending'  => ('⏳ En attente', context.tpInkSub),
      _          => ('', context.tpInkSub),
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
      return Semantics(
        button: true,
        label: 'Envoyer un message',
        child: GestureDetector(
        onTap: onMessage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(Radii.tag),
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
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.tpHair,
          borderRadius: BorderRadius.circular(Radii.tag),
        ),
        child: Text('En attente',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInkSub)),
      );
    }

    // Pas de connexion → bouton Inviter
    return Semantics(
      button: true,
      label: 'Inviter',
      child: GestureDetector(
      onTap: onInvite,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: trackpartyGradient,
          borderRadius: BorderRadius.circular(Radii.tag),
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
      ),
    );
  }
}

// ── Avatar groupe ─────────────────────────────────────────────────────────────

class _GroupAvatar extends StatelessWidget {
  final ChatRoomModel room;
  const _GroupAvatar({required this.room});

  @override
  Widget build(BuildContext context) {
    final url = room.roomAvatarUrl;

    if (url != null && url.isNotEmpty) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 52, height: 52,
          memCacheWidth: (52 * dpr).round(), memCacheHeight: (52 * dpr).round(),
          fit: BoxFit.cover,
          errorWidget: (ctx, url, err) => _fallback(ctx),
          placeholder: (ctx, url) => _fallback(ctx),
        ),
      );
    }

    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final icon = room.isEvent
        ? PhosphorIcons.confetti()
        : room.isGroup
            ? PhosphorIcons.usersThree()
            : PhosphorIcons.users();
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

// ── Chat row ──────────────────────────────────────────────────────────────────

// Aperçu du dernier message (façon WhatsApp) :
//  • message de moi   → coche(s) de statut + message (pas de nom)
//  • reçu en DM       → message seul
//  • reçu en groupe   → « Prénom: message » (utile pour savoir qui a parlé)
Widget _buildPreview(BuildContext context, ChatRoomModel room) {
  final lm = room.lastMessage;
  final style = TextStyle(
    fontSize: 13,
    fontWeight: room.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
    color: room.unreadCount > 0 ? context.tpInk : context.tpInkSub,
  );
  if (lm == null) {
    return Text('Aucun message',
        maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  }

  var text = lm.content;
  if (!lm.isMine && !room.isPrivate) {
    text = '${lm.senderName.split(' ').first}: ${lm.content}';
  }

  final icon = lm.isMine ? _statusPreviewIcon(context, lm.status) : null;
  if (icon == null) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  }
  return Row(
    children: [
      icon,
      const SizedBox(width: 4),
      Expanded(
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    ],
  );
}

// Coche(s) de statut : envoyé = 1 coche ; livré/lu = 2 coches ; lu = bleu.
Widget? _statusPreviewIcon(BuildContext context, String? status) {
  if (status == null) return null;
  return Icon(
    status == 'sent' ? PhosphorIcons.check(PhosphorIconsStyle.bold) : PhosphorIcons.checks(PhosphorIconsStyle.bold),
    size: 15,
    color: status == 'read' ? kInfo : context.tpInkMute,
  );
}

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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.lg)),
            child: Row(
              children: [
                // Avatar
                isGroup
                    ? _GroupAvatar(room: room)
                    : TpAvatar(
                        name: otherMember?.displayName ?? room.displayName,
                        imageUrl: otherMember?.avatarUrl,
                        size: 52,
                      ),
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
                      _buildPreview(context, room),
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

// ── Bottom sheet nom du nouveau groupe ───────────────────────────────────────

Future<String?> _showGroupNameSheet(BuildContext context) {
  final ctrl = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom +
          MediaQuery.of(ctx).padding.bottom + 20;
      return Container(
        decoration: BoxDecoration(
          color: ctx.tpCard,
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
                  color: ctx.tpHair,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Nommer le groupe',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 80,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Nom du groupe',
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
                  child: const Text('Créer',
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
