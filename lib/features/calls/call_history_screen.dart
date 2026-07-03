import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/call_history_model.dart';
import '../../core/providers/call_history_provider.dart';
import '../../core/services/call_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_toast.dart';

const _kMissedRed = Color(0xFFEF4444);

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // À l'ouverture : marquer comme vu → la pastille "appels manqués" se vide.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CallHistorySeen.markSeenNow();
      if (mounted) ref.invalidate(missedCallsBadgeProvider);
    });
  }

  Future<void> _callBack(BuildContext ctx, CallHistoryEntry e) async {
    final name = e.otherUserName ?? 'Appel';
    try {
      await CallService().initiateCall(
        roomId: e.roomId,
        callType: e.callType,
        remoteUserName: name,
        remoteUserAvatarUrl: e.otherUserAvatarUrl,
      );
      if (ctx.mounted) {
        ctx.push('/call/outgoing', extra: {
          'callType': e.callType,
          'remoteUserName': name,
          'remoteUserAvatarUrl': e.otherUserAvatarUrl,
        });
      }
    } catch (err) {
      if (ctx.mounted) TpToast.error(ctx, "Impossible de lancer l'appel : $err");
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(callHistoryProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
                error: (_, _) => _buildError(context),
                data: (calls) {
                  if (calls.isEmpty) return _buildEmpty(context);
                  return RefreshIndicator(
                    color: kPrimary,
                    onRefresh: () async => ref.invalidate(callHistoryProvider),
                    child: ListView.separated(
                      padding: EdgeInsets.only(
                          top: Sp.sm,
                          bottom: MediaQuery.of(context).padding.bottom + 24),
                      itemCount: calls.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1, indent: 76, color: context.tpHair),
                      itemBuilder: (_, i) => _CallRow(
                        entry: calls[i],
                        onCallBack: () => _callBack(context, calls[i]),
                        onOpen: () => context.push('/chat/${calls[i].roomId}'),
                      ),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 12),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Retour',
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.sm),
                child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Appels',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: context.tpInk, letterSpacing: -0.8)),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(PhosphorIcons.phoneCall(), size: 48, color: context.tpInkMute),
        const SizedBox(height: 12),
        Text('Aucun appel pour le moment',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInkSub)),
      ]),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Erreur de chargement', style: TextStyle(color: context.tpInkSub)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => ref.invalidate(callHistoryProvider),
          child: const Text('Réessayer'),
        ),
      ]),
    );
  }
}

// ── Ligne d'appel ─────────────────────────────────────────────────────────────

class _CallRow extends StatelessWidget {
  final CallHistoryEntry entry;
  final VoidCallback onCallBack;
  final VoidCallback onOpen;

  const _CallRow({required this.entry, required this.onCallBack, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final name    = entry.otherUserName ?? 'Inconnu';
    final missed  = entry.isMissed;
    final labelColor = missed ? _kMissedRed : context.tpInkSub;

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
        child: Row(
          children: [
            _Avatar(name: name, url: entry.otherUserAvatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: missed ? _kMissedRed : context.tpInk)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(_dirIcon(), size: 14, color: labelColor),
                    const SizedBox(width: 5),
                    Icon(entry.isVideo ? PhosphorIcons.videoCamera() : PhosphorIcons.phone(),
                        size: 12, color: labelColor),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(_subtitle(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: labelColor)),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: entry.isVideo ? 'Rappeler en vidéo' : 'Rappeler',
              child: GestureDetector(
                onTap: onCallBack,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(Radii.md)),
                  child: Icon(
                      entry.isVideo ? PhosphorIcons.videoCamera() : PhosphorIcons.phone(),
                      size: 18, color: kPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _dirIcon() {
    if (entry.isIncoming) return PhosphorIcons.arrowDownLeft();
    return PhosphorIcons.arrowUpRight();
  }

  String _subtitle() {
    final when = _fmtWhen(entry.startedAt);
    if (entry.isMissed) return 'Manqué · $when';
    final d = entry.durationSeconds;
    if (entry.status == 'accepted' || entry.status == 'ended') {
      if (d != null && d > 0) return '${_fmtDur(d)} · $when';
    }
    if (entry.status == 'rejected') return 'Refusé · $when';
    return '${entry.isIncoming ? 'Entrant' : 'Sortant'} · $when';
  }
}

String _fmtDur(int secs) {
  final m = secs ~/ 60, s = secs % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _fmtWhen(DateTime dt) {
  final now = DateTime.now();
  final sameDay = now.year == dt.year && now.month == dt.month && now.day == dt.day;
  if (sameDay) return DateFormat('HH:mm').format(dt);
  final yesterday = now.subtract(const Duration(days: 1));
  if (yesterday.year == dt.year && yesterday.month == dt.month && yesterday.day == dt.day) {
    return 'Hier ${DateFormat('HH:mm').format(dt)}';
  }
  if (now.difference(dt).inDays < 7) return DateFormat('EEEE HH:mm', 'fr_FR').format(dt);
  return DateFormat('d MMM', 'fr_FR').format(dt);
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  const _Avatar({required this.name, this.url});

  String _initials() {
    final p = name.trim().split(' ');
    if (p.length >= 2 && p[0].isNotEmpty && p[1].isNotEmpty) {
      return '${p[0][0]}${p[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: trackpartyGradient),
      child: url != null
          ? ClipOval(child: CachedNetworkImage(
              imageUrl: url!, width: 52, height: 52, fit: BoxFit.cover))
          : Center(child: Text(_initials(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    );
  }
}
