import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/event_provider.dart';
import '../../core/services/event_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_toast.dart';

class EventWaitlistScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventWaitlistScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<EventWaitlistScreen> createState() => _EventWaitlistScreenState();
}

class _EventWaitlistScreenState extends ConsumerState<EventWaitlistScreen> {
  final Set<String> _processing = {};

  Future<void> _action(String participationId, {required bool accept}) async {
    setState(() => _processing.add(participationId));
    try {
      await ref.read(eventServiceProvider).waitlistAction(
        widget.eventId, participationId,
        accept: accept,
      );
      ref.invalidate(eventWaitlistProvider(widget.eventId));
      ref.invalidate(eventStatsProvider(widget.eventId));
      if (mounted) {
        accept
            ? TpToast.success(context, 'Participant accepté !')
            : TpToast.info(context, 'Participant rejeté.');
      }
    } catch (e) {
      if (mounted) {
        TpToast.error(context, 'Erreur : $e');
      }
    } finally {
      if (mounted) setState(() => _processing.remove(participationId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(eventWaitlistProvider(widget.eventId));

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: Semantics(
          button: true, label: 'Retour',
          child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(Radii.tag)),
            child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
          ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Liste d\'attente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
            Text(widget.eventTitle,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIcons.warning(), color: kError, size: 40),
            const SizedBox(height: 12),
            Text('Erreur de chargement', style: TextStyle(color: context.tpInkSub)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(eventWaitlistProvider(widget.eventId)),
              child: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (participants) {
          if (participants.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('✅', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text('Liste d\'attente vide',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
                const SizedBox(height: 6),
                Text('Personne en attente pour le moment.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkSub)),
              ]),
            );
          }
          return RefreshIndicator(
            color: kPrimary,
            onRefresh: () => ref.refresh(eventWaitlistProvider(widget.eventId).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 100),
              itemCount: participants.length,
              addAutomaticKeepAlives: false,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = participants[i];
                final isProcessing = _processing.contains(p.id);
                final dt = DateFormat('d MMM à HH:mm', 'fr_FR')
                    .format(DateTime.tryParse(p.registeredAt) ?? DateTime.now());
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    // Position badge
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(Radii.sm)),
                      alignment: Alignment.center,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimary)),
                    ),
                    const SizedBox(width: 10),
                    TpAvatar(name: p.userName, imageUrl: p.userAvatarUrl, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.userName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                        Text('En attente depuis $dt',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    if (isProcessing)
                      const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                    else
                      Row(children: [
                        // Reject
                        Semantics(
                          button: true, label: 'Refuser la demande',
                          child: GestureDetector(
                          onTap: () => _action(p.id, accept: false),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                                color: kError.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(Radii.tag)),
                            child: Icon(PhosphorIcons.x(), color: kError, size: 18),
                          ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Accept
                        Semantics(
                          button: true, label: 'Accepter la demande',
                          child: GestureDetector(
                          onTap: () => _action(p.id, accept: true),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                                color: kSuccess.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(Radii.tag)),
                            child: Icon(PhosphorIcons.check(), color: kSuccess, size: 18),
                          ),
                          ),
                        ),
                      ]),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
