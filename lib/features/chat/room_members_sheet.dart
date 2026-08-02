import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/chat_model.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/invitation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_toast.dart';

// ── Sheet membres d'une salle (communauté ou groupe événement) ────────────────

class RoomMembersSheet extends ConsumerStatefulWidget {
  final ChatRoomModel room;
  const RoomMembersSheet({super.key, required this.room});

  @override
  ConsumerState<RoomMembersSheet> createState() => _RoomMembersSheetState();
}

class _RoomMembersSheetState extends ConsumerState<RoomMembersSheet> {
  late Future<List<RoomMemberModel>> _future;
  final Set<String> _sentTo    = {};
  final Set<String> _sendingTo = {};

  @override
  void initState() {
    super.initState();
    _future = ref.read(chatServiceProvider).getRoomMembers(widget.room.id).then((members) {
      // Pré-remplir _sentTo avec les invitations déjà en attente côté serveur
      final alreadySent = members.where((m) => m.hasPendingInvitation).map((m) => m.id);
      if (mounted) setState(() => _sentTo.addAll(alreadySent));
      return members;
    });
  }

  Future<void> _sendRequest(RoomMemberModel member) async {
    setState(() => _sendingTo.add(member.id));
    try {
      await ref.read(invitationServiceProvider).sendInvitation(receiverId: member.id);
      if (mounted) setState(() { _sentTo.add(member.id); _sendingTo.remove(member.id); });
    } on ApiException {
      if (mounted) setState(() { _sentTo.add(member.id); _sendingTo.remove(member.id); });
    }
  }

  // ── Gestion admin (groupe personnalisé) ─────────────────────────────────────

  void _reload() {
    setState(() {
      _future = ref.read(chatServiceProvider).getRoomMembers(widget.room.id);
    });
  }

  Future<void> _toggleAdmin(RoomMemberModel member) async {
    final newRole = member.isAdmin ? 'member' : 'admin';
    try {
      await ref.read(chatServiceProvider).updateMemberRole(widget.room.id, member.id, newRole);
      _reload();
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } catch (_) {
      if (mounted) TpToast.error(context, 'Action impossible pour le moment');
    }
  }

  Future<void> _removeMember(RoomMemberModel member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: dCtx.tpCard,
        title: Text('Retirer ${member.displayName} ?',
            style: TextStyle(color: dCtx.tpInk, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Retirer', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(chatServiceProvider).removeGroupMember(widget.room.id, member.id);
      ref.read(chatRoomsProvider.notifier).refresh();
      _reload();
    } on ApiException catch (e) {
      if (mounted) TpToast.error(context, e.message);
    } catch (_) {
      if (mounted) TpToast.error(context, 'Action impossible pour le moment');
    }
  }

  void _showAdminActions(RoomMemberModel member) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.tpCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(
                color: sheetCtx.tpHair, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            ListTile(
              leading: Icon(
                member.isAdmin ? PhosphorIcons.shieldSlash() : PhosphorIcons.shieldCheck(),
                color: sheetCtx.tpInk, size: 22,
              ),
              title: Text(member.isAdmin ? 'Retirer les droits admin' : 'Promouvoir admin',
                  style: TextStyle(color: sheetCtx.tpInk, fontSize: 15, fontWeight: FontWeight.w700)),
              onTap: () { Navigator.pop(sheetCtx); _toggleAdmin(member); },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.userMinus, color: Color(0xFFEF4444), size: 22),
              title: const Text('Retirer du groupe',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 15, fontWeight: FontWeight.w700)),
              onTap: () { Navigator.pop(sheetCtx); _removeMember(member); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      margin: const EdgeInsets.fromLTRB(Sp.sm, 0, Sp.sm, Sp.sm),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.cardLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 12),
            child: Row(children: [
              Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.fill), color: kPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                '${widget.room.membersCount} membre${widget.room.membersCount > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk),
              ),
            ]),
          ),
          Divider(height: 1, color: context.tpHair),
          Flexible(
            child: FutureBuilder<List<RoomMemberModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
                  );
                }
                if (snap.hasError || !snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('Impossible de charger les membres',
                          style: TextStyle(color: context.tpInkSub)),
                    ),
                  );
                }
                final members = snap.data!;
                if (members.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('Aucun autre membre',
                          style: TextStyle(color: context.tpInkSub)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 68, color: context.tpHair),
                  itemBuilder: (_, i) => RoomMemberRow(
                    member:    members[i],
                    sent:      _sentTo.contains(members[i].id),
                    sending:   _sendingTo.contains(members[i].id),
                    canManage: widget.room.isGroup && widget.room.isAdmin,
                    onRequest: () => _sendRequest(members[i]),
                    onManage:  () => _showAdminActions(members[i]),
                    onMessage: () {
                      Navigator.pop(context);
                      context.push('/chat/new', extra: {
                        'userId':      members[i].id,
                        'displayName': members[i].displayName,
                        'avatarUrl':   members[i].avatarUrl,
                      });
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + Sp.sm),
        ],
      ),
    );
  }
}

// ── Ligne d'un membre ─────────────────────────────────────────────────────────

class RoomMemberRow extends StatelessWidget {
  final RoomMemberModel member;
  final bool sent;
  final bool sending;
  final bool canManage;
  final VoidCallback onRequest;
  final VoidCallback onMessage;
  final VoidCallback? onManage;

  const RoomMemberRow({
    super.key,
    required this.member,
    required this.sent,
    required this.sending,
    this.canManage = false,
    required this.onRequest,
    required this.onMessage,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
      child: Row(children: [
        TpAvatar(name: member.displayName, imageUrl: member.avatarUrl, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(member.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                ),
                if (member.isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: const Text('Admin',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ]),
              if (member.isPromoter)
                Text('Promoteur',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (member.hasDm)
          Semantics(
            button: true,
            label: 'Envoyer un message',
            child: GestureDetector(
              onTap: onMessage,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(PhosphorIcons.chatCircle(), color: kPrimary, size: 18),
              ),
            ),
          )
        else if (sent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.tag),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: kSuccess, size: 14),
              const SizedBox(width: 4),
              Text('Envoyé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSuccess)),
            ]),
          )
        else
          Semantics(
            button: true,
            label: 'Demander en ami',
            child: GestureDetector(
            onTap: sending ? null : onRequest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(Radii.tag),
                border: Border.all(color: context.tpHair),
              ),
              child: sending
                  ? SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.tpInkSub))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PhosphorIcons.userPlus(), color: context.tpInk, size: 14),
                      const SizedBox(width: 4),
                      Text('Demander',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInk)),
                    ]),
            ),
            ),
          ),
        if (canManage) ...[
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Gérer ${member.displayName}',
            child: GestureDetector(
              onTap: onManage,
              child: SizedBox(
                width: 36, height: 36,
                child: Icon(PhosphorIcons.dotsThreeVertical(), color: context.tpInkSub, size: 18),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
