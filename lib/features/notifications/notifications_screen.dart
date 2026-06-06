import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/models/notification_model.dart';
import '../../core/providers/notification_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _filter = 0;
  static const _filters = ['Tout', 'Events', 'Messages', 'Social'];
  static const _filterKeys = ['all', 'events', 'messages', 'social'];

  @override
  void initState() {
    super.initState();
    // Always fetch fresh data when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).refresh();
    });
  }

  List<NotificationModel> _filtered(List<NotificationModel> all) {
    if (_filter == 0) return all;
    return all.where((n) => n.category == _filterKeys[_filter]).toList();
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, notifsAsync),
            _buildFilters(context),
            Expanded(
              child: notifsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
                error: (error, stack) => _buildError(context),
                data: (all) {
                  final notifs = _filtered(all);
                  if (notifs.isEmpty) return _buildEmpty(context);

                  final today   = notifs.where((n) => _isToday(n.createdAt)).toList();
                  final earlier = notifs.where((n) => !_isToday(n.createdAt)).toList();

                  return RefreshIndicator(
                    color: kPrimary,
                    onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
                    child: ListView(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
                      children: [
                        if (today.isNotEmpty)   _buildSection(context, "Aujourd'hui", today),
                        if (earlier.isNotEmpty) _buildSection(context, 'Plus tôt', earlier),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<List<NotificationModel>> notifsAsync) {
    final unread = notifsAsync.valueOrNull?.where((n) => !n.isRead).length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: context.tpInk, letterSpacing: -0.8)),
              const SizedBox(height: 2),
              Text(
                unread > 0 ? '$unread nouvelle${unread > 1 ? 's' : ''}' : 'Tout est lu',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub),
              ),
            ],
          ),
          const Spacer(),
          if (unread > 0)
            Semantics(
              button: true,
              label: 'Tout marquer comme lu',
              child: GestureDetector(
                onTap: () => ref.read(notificationsProvider.notifier).markAllRead(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: context.tpCard,
                      borderRadius: BorderRadius.circular(Radii.tag),
                      boxShadow: Shadows.sm),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.check(), color: kPrimary, size: 12),
                      const SizedBox(width: 5),
                      Text('Tout lu',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, 12),
      child: Row(
        children: List.generate(_filters.length, (i) {
          final active = i == _filter;
          return Semantics(
            button: true,
            label: _filters[i],
            selected: active,
            child: GestureDetector(
              onTap: () => setState(() => _filter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i < _filters.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: active ? trackpartyGradient : null,
                  color: active ? null : context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.tag),
                  border: active ? null : Border.all(color: context.tpHair),
                  boxShadow: active
                      ? [const BoxShadow(color: Color(0x407C3AED), blurRadius: 10, offset: Offset(0, 4))]
                      : null,
                ),
                child: Text(_filters[i],
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: active ? Colors.white : context.tpInk)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<NotificationModel> notifs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 8),
          child: Text(title.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                color: context.tpInkSub, letterSpacing: 0.5)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: notifs.map((n) => _NotifRow(
              notif: n,
              onMarkRead: () => ref.read(notificationsProvider.notifier).markRead(n.id),
            )).toList(),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Aucune notification',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 4),
          Text('Tu seras notifié des événements et messages ici.',
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
          Text('Impossible de charger les notifications',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInk)),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Réessayer',
            child: GestureDetector(
              onTap: () => ref.read(notificationsProvider.notifier).refresh(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
                child: const Text('Réessayer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row de notification ───────────────────────────────────────────────────────

String _fmtTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'maintenant';
  if (diff.inHours < 1)   return '${diff.inMinutes} min';
  if (diff.inDays < 1)    return DateFormat('HH:mm').format(dt);
  if (diff.inDays == 1)   return 'Hier';
  if (diff.inDays < 7)    return DateFormat('EEE', 'fr_FR').format(dt);
  return DateFormat('d MMM', 'fr_FR').format(dt);
}

class _NotifRow extends StatefulWidget {
  final NotificationModel notif;
  final VoidCallback onMarkRead;

  const _NotifRow({required this.notif, required this.onMarkRead});

  @override
  State<_NotifRow> createState() => _NotifRowState();
}

class _NotifRowState extends State<_NotifRow> {
  bool _responded = false;

  bool get _isGroup =>
      widget.notif.notificationType == 'new_message' &&
      widget.notif.payload.containsKey('room_id');

  @override
  Widget build(BuildContext context) {
    final notif = widget.notif;
    return Semantics(
      button: !notif.isRead,
      label: notif.isRead ? null : 'Marquer comme lu',
      child: GestureDetector(
      onTap: notif.isRead ? null : widget.onMarkRead,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.transparent : kPrimary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + emoji badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                _isGroup
                    ? Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            gradient: trackpartyGradient,
                            borderRadius: BorderRadius.circular(Radii.button)),
                        child: Icon(PhosphorIcons.users(), color: Colors.white, size: 22))
                    : TpAvatar(name: notif.title, size: 44),
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: context.tpCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.tpBg, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(notif.icon, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: context.tpInk, height: 1.35),
                      children: [
                        TextSpan(text: notif.title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                        if (notif.body.isNotEmpty)
                          TextSpan(text: ' ${notif.body}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(_fmtTime(notif.createdAt),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: context.tpInkMute)),
                  if (notif.isInvitation && !_responded && notif.invitationId != null) ...[
                    const SizedBox(height: 8),
                    _InvitationActions(
                      invitationId: notif.invitationId!,
                      onResponded: () {
                        setState(() => _responded = true);
                        widget.onMarkRead();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Unread dot
            if (!notif.isRead)
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Actions invitation ────────────────────────────────────────────────────────

class _InvitationActions extends ConsumerStatefulWidget {
  final String invitationId;
  final VoidCallback onResponded;

  const _InvitationActions({required this.invitationId, required this.onResponded});

  @override
  ConsumerState<_InvitationActions> createState() => _InvitationActionsState();
}

class _InvitationActionsState extends ConsumerState<_InvitationActions> {
  bool _loading = false;

  Future<void> _respond(String action) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        'chat/invitations/${widget.invitationId}/respond/',
        data: {'action': action},
      );
      widget.onResponded();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la réponse à l\'invitation.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 28,
          child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)));
    }
    return Row(children: [
      Semantics(
        button: true,
        label: 'Accepter l\'invitation',
        child: GestureDetector(
          onTap: () => _respond('accept'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.tag),
            ),
            child: const Text('Accepter',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Semantics(
        button: true,
        label: 'Refuser l\'invitation',
        child: GestureDetector(
          onTap: () => _respond('refuse'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(Radii.tag),
              border: Border.all(color: context.tpHair),
            ),
            child: Text('Refuser',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
          ),
        ),
      ),
    ]);
  }
}
