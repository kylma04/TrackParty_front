import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/ticket_model.dart';
import '../../core/providers/ticket_provider.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class EventCheckinsScreen extends ConsumerWidget {
  final String eventId;
  final String eventTitle;
  const EventCheckinsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(eventCheckinsProvider(eventId));

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: context.tpCard,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: Shadows.sm),
                  child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Entrées',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
                  Text(eventTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ]),
              ),
              GestureDetector(
                onTap: () => ref.invalidate(eventCheckinsProvider(eventId)),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: context.tpCard,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: Shadows.sm),
                  child: Icon(PhosphorIcons.arrowClockwise(), color: context.tpInkSub, size: 16),
                ),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: () => ref.refresh(eventCheckinsProvider(eventId).future),
              child: checkinsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ListView(
                  children: [
                    SizedBox(
                      height: 300,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.warningCircle(), size: 40, color: context.tpInkMute),
                          const SizedBox(height: 12),
                          Text('Impossible de charger les entrées',
                              style: TextStyle(fontSize: 14, color: context.tpInkSub)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => ref.invalidate(eventCheckinsProvider(eventId)),
                            child: Text('Réessayer',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                data: (checkins) {
                  if (checkins.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(PhosphorIcons.scanSmiley(), size: 52, color: context.tpInkMute),
                              const SizedBox(height: 16),
                              Text('Aucune entrée pour l\'instant',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
                              const SizedBox(height: 6),
                              Text('Les entrées validées apparaîtront ici.',
                                  style: TextStyle(fontSize: 13, color: context.tpInkSub)),
                            ]),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(children: [
                    // Counter banner
                    Container(
                      margin: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: const Color(0xFF22A865).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF22A865).withValues(alpha: 0.25))),
                      child: Row(children: [
                        Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: const Color(0xFF22A865), size: 18),
                        const SizedBox(width: 10),
                        Text('${checkins.length} entrée${checkins.length > 1 ? 's' : ''} validée${checkins.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF22A865))),
                      ]),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            Sp.md, 0, Sp.md, MediaQuery.of(context).padding.bottom + 20),
                        itemCount: checkins.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _CheckinTile(ticket: checkins[i]),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CheckinTile extends StatelessWidget {
  final TicketModel ticket;
  const _CheckinTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final timeStr = ticket.checkedInAt != null
        ? DateFormat('HH\'h\'mm', 'fr_FR').format(ticket.checkedInAt!.toLocal())
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: Shadows.sm),
      child: Row(children: [
        TpAvatar(name: ticket.holderName, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ticket.holderName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
            Text('Entrée à $timeStr',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF22A865).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6)),
          child: const Text('✓',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF22A865))),
        ),
      ]),
    );
  }
}
