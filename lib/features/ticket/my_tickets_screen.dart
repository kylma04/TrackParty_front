import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/ticket_model.dart';
import '../../core/providers/ticket_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_skeleton.dart';

class MyTicketsScreen extends ConsumerWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
            child: Row(children: [
              Semantics(
                button: true,
                label: 'Retour',
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(Radii.md),
                        boxShadow: Shadows.sm),
                    child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Mes billets',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: () => ref.refresh(myTicketsProvider.future),
              child: ticketsAsync.when(
                loading: () => SkList(count: 4, builder: (_) => const SkEventCard()),
                error: (_, _) => ListView(
                  children: [
                    SizedBox(
                      height: 300,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.ticket(), size: 48, color: context.tpInkMute),
                          const SizedBox(height: 12),
                          Text('Impossible de charger tes billets',
                              style: TextStyle(fontSize: 14, color: context.tpInkSub)),
                          const SizedBox(height: 12),
                          Semantics(
                            button: true,
                            label: 'Réessayer',
                            child: GestureDetector(
                              onTap: () => ref.invalidate(myTicketsProvider),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                    gradient: trackpartyGradient,
                                    borderRadius: BorderRadius.circular(Radii.md)),
                                child: const Text('Réessayer',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(PhosphorIcons.ticket(), size: 56, color: context.tpInkMute),
                              const SizedBox(height: 16),
                              Text('Aucun billet pour l\'instant',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
                              const SizedBox(height: 8),
                              Text('Participe à un événement pour obtenir ton billet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: context.tpInkSub)),
                            ]),
                          ),
                        ),
                      ],
                    );
                  }

                  final upcoming = tickets.where((t) => t.isValid && !t.checkedIn).toList();
                  final past     = tickets.where((t) => !t.isValid || t.checkedIn).toList();

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                        Sp.md, 4, Sp.md, MediaQuery.of(context).padding.bottom + 20),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _SectionLabel(label: 'À venir', count: upcoming.length),
                        ...upcoming.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TicketTile(ticket: t),
                            )),
                      ],
                      if (past.isNotEmpty) ...[
                        _SectionLabel(label: 'Passés', count: past.length),
                        ...past.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TicketTile(ticket: t),
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInkSub)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: context.tpHair, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Text('$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
        ),
      ]),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final TicketModel ticket;
  const _TicketTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("EEE d MMM · HH'h'mm", 'fr_FR').format(ticket.eventStart.toLocal());
    final expired  = !ticket.isValid;
    final checked  = ticket.checkedIn;

    return Semantics(
      button: true,
      label: ticket.eventTitle,
      child: GestureDetector(
      onTap: () => context.push('/ticket/${ticket.eventId}'),
      child: Container(
        decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.card),
            boxShadow: Shadows.md),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          // Cover
          SizedBox(
            width: 90, height: 90,
            child: ticket.eventCover != null
                ? CachedNetworkImage(
                    imageUrl: ticket.eventCover!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _CoverPlaceholder(),
                  )
                : _CoverPlaceholder(),
          ),
          // Infos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticket.eventTitle,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                const SizedBox(height: 4),
                Text(dateStr,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                const SizedBox(height: 6),
                _StatusChip(expired: expired, checked: checked),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(PhosphorIcons.caretRight(), color: context.tpInkMute, size: 16),
          ),
        ]),
      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool expired;
  final bool checked;
  const _StatusChip({required this.expired, required this.checked});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;
    if (expired) {
      bg = kError.withValues(alpha: 0.12);
      label = 'Expiré';
    } else if (checked) {
      bg = kSuccess.withValues(alpha: 0.12);
      label = 'Utilisé ✓';
    } else {
      bg = kPrimary.withValues(alpha: 0.10);
      label = 'Valide';
    }
    final Color fg = expired ? kError : checked ? kSuccess : kPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg)),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: kPrimary.withValues(alpha: 0.12),
      child: Center(
          child: Icon(PhosphorIcons.ticket(PhosphorIconsStyle.fill),
              color: kPrimary.withValues(alpha: 0.4), size: 32)),
    );
  }
}
