import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/chat_model.dart';
import '../../core/providers/chat_provider.dart';
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
            label: 'Rechercher une conversation',
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: context.tpCard,
                  borderRadius: BorderRadius.circular(12), boxShadow: Shadows.sm),
              child: Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInk, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Nouvelle conversation',
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(12)),
              child: Icon(PhosphorIcons.pencilSimple(), color: Colors.white, size: 18),
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
