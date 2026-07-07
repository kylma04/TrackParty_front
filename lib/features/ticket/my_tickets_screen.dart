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
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_skeleton.dart';

class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen> {
  String _filter = 'upcoming';

  static const _filters = <(String, String)>[
    ('upcoming', 'À venir'),
    ('scanned', 'Scanné'),
    ('expired', 'Expiré'),
    ('transferred', 'Transféré'),
  ];

  bool _matches(TicketModel t) => switch (_filter) {
        'scanned' => t.checkedIn,
        'expired' => (!t.isValid || t.eventStart.isBefore(DateTime.now())) && !t.checkedIn,
        _ => t.isValid && !t.checkedIn, // à venir
      };

  String get _emptyLabel => switch (_filter) {
        'scanned' => 'Aucun billet scanné.',
        'expired' => 'Aucun billet expiré.',
        _ => 'Aucun billet à venir.',
      };

  @override
  Widget build(BuildContext context) {
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

          // ── Filtres (À venir / Scanné / Expiré) ────────────────────────────
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
              children: [
                for (final f in _filters) ...[
                  _FilterChip(
                    label: f.$2,
                    selected: _filter == f.$1,
                    onTap: () => setState(() => _filter = f.$1),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          Expanded(
            child: _filter == 'transferred'
                ? _transferredBody(context)
                : _ticketsBody(context, ticketsAsync),
          ),
        ]),
      ),
    );
  }

  Widget _ticketsBody(
      BuildContext context, AsyncValue<List<TicketModel>> ticketsAsync) {
    return RefreshIndicator(
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
                  final filtered = tickets.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(PhosphorIcons.ticket(), size: 56, color: context.tpInkMute),
                              const SizedBox(height: 16),
                              Text(tickets.isEmpty
                                      ? 'Aucun billet pour l\'instant'
                                      : _emptyLabel,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
                              if (tickets.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Participe à un événement pour obtenir ton billet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: context.tpInkSub)),
                              ],
                            ]),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                        Sp.md, 4, Sp.md, MediaQuery.of(context).padding.bottom + 20),
                    children: filtered
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TicketTile(ticket: t),
                            ))
                        .toList(),
                  );
                },
              ),
            );
  }

  Widget _transferredBody(BuildContext context) {
    final async = ref.watch(myTransferredTicketsProvider);
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () => ref.refresh(myTransferredTicketsProvider.future),
      child: async.when(
        loading: () => SkList(count: 4, builder: (_) => const SkEventCard()),
        error: (_, _) => ListView(children: [
          SizedBox(
            height: 300,
            child: Center(
              child: Text('Impossible de charger les transferts.',
                  style: TextStyle(fontSize: 14, color: context.tpInkSub)),
            ),
          ),
        ]),
        data: (items) {
          if (items.isEmpty) {
            return ListView(children: [
              SizedBox(
                height: 300,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.paperPlaneTilt(),
                        size: 56, color: context.tpInkMute),
                    const SizedBox(height: 16),
                    Text('Aucun billet transféré.',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.tpInk)),
                  ]),
                ),
              ),
            ]);
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
                Sp.md, 4, Sp.md, MediaQuery.of(context).padding.bottom + 20),
            children: items
                .map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TransferTile(transfer: t),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kPrimary : context.tpCard,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
                color: selected ? kPrimary : context.tpHair, width: 1.4),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : context.tpInk)),
        ),
      );
}

class TicketTile extends StatelessWidget {
  final TicketModel ticket;
  const TicketTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("EEE d MMM · HH'h'mm", 'fr_FR').format(ticket.eventStart.toLocal());
    final expired = !ticket.isValid || ticket.eventStart.isBefore(DateTime.now());
    final checked  = ticket.checkedIn;

    return Semantics(
      button: true,
      label: ticket.eventTitle,
      child: GestureDetector(
      onTap: () => context.push('/ticket/${ticket.eventId}', extra: ticket),
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
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _StatusChip(expired: expired, checked: checked),
                  if (ticket.categoryName != null)
                    _CategoryChip(
                      name: ticket.categoryName!,
                      color: _hexColor(ticket.categoryColor),
                      inKind: ticket.isInKind,
                    ),
                ]),
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

class _TransferTile extends StatelessWidget {
  final SentTransferModel transfer;
  const _TransferTile({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("d MMM yyyy", 'fr_FR').format(transfer.transferredAt.toLocal());
    return Container(
      decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: Shadows.md),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        SizedBox(
          width: 90, height: 90,
          child: transfer.eventCover != null
              ? CachedNetworkImage(
                  imageUrl: transfer.eventCover!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _CoverPlaceholder(),
                )
              : _CoverPlaceholder(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(transfer.eventTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
              const SizedBox(height: 6),
              // Destinataire
              Row(children: [
                TpAvatar(
                  name: transfer.recipientName,
                  imageUrl: transfer.recipientAvatarUrl,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('Cédé à ${transfer.recipientName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: kViolet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('Le $dateStr',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kViolet)),
                ),
                if (transfer.checkedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: kSuccess.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('Utilisé ✓',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSuccess)),
                  ),
                if (transfer.categoryName != null)
                  _CategoryChip(
                    name: transfer.categoryName!,
                    color: kPrimary,
                    inKind: false,
                  ),
              ]),
            ]),
          ),
        ),
      ]),
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

Color? _hexColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class _CategoryChip extends StatelessWidget {
  final String name;
  final Color? color;
  final bool inKind;
  const _CategoryChip({required this.name, this.color, required this.inKind});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(inKind ? '$name · 🥗' : name,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
      ]),
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
