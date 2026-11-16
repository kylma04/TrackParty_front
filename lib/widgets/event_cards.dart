import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/models/event_model.dart';
import '../core/providers/event_provider.dart';
import '../core/services/event_service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme_ext.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

final _fcfa = NumberFormat.decimalPattern('fr_FR');

/// Texte de prix d'une carte : « À partir de 5 000 F CFA », « Payant » ou « Gratuit ».
({String prefix, String amount, bool free}) eventPriceParts(EventModel e) {
  final from = e.priceFrom;
  if (from != null && from > 0) {
    return (
      prefix: 'À partir de ',
      amount: '${_fcfa.format(from)} F CFA',
      free: false,
    );
  }
  if (e.contributionType == 'monetaire') {
    final a = e.contributionAmount;
    if (a != null && a > 0) {
      return (
        prefix: 'À partir de ',
        amount: '${_fcfa.format(a)} F CFA',
        free: false,
      );
    }
    return (prefix: '', amount: 'Payant', free: false);
  }
  return (prefix: '', amount: 'Gratuit', free: true);
}

String eventShortDate(EventModel e) =>
    DateFormat('EEE d MMM', 'fr_FR').format(e.startAt.toLocal());

String eventPlaceLabel(EventModel e) {
  final parts = <String>[
    if (e.quartier.isNotEmpty) e.quartier,
    if (e.city.isNotEmpty && e.city != e.quartier) e.city,
  ];
  return parts.isEmpty ? e.addressLabel : parts.join(', ');
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.isDark ? kCardAltDark : const Color(0xFFEAE8DF),
    ),
    child: Center(
      child: Icon(
        PhosphorIcons.ticket(PhosphorIconsStyle.duotone),
        size: 30,
        color: context.tpInkMute,
      ),
    ),
  );
}

class _Cover extends StatelessWidget {
  final EventModel event;
  const _Cover({required this.event});

  @override
  Widget build(BuildContext context) {
    final url = event.coverImageUrl;
    if (url == null) return const _CoverPlaceholder();
    return ExcludeSemantics(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, _, _) => const _CoverPlaceholder(),
        placeholder: (_, _) => const _CoverPlaceholder(),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final EventModel event;
  final bool compact;
  const _PricePill({required this.event, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = eventPriceParts(event);
    final color = p.free ? kSuccess : kPrimary;
    final base = compact ? 11.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (p.prefix.isNotEmpty)
              TextSpan(
                text: p.prefix,
                style: TextStyle(
                  fontSize: base,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            TextSpan(
              text: p.amount,
              style: TextStyle(
                fontSize: base + 1,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Bouton cœur (favori) ──────────────────────────────────────────────────────

class EventHeartButton extends ConsumerStatefulWidget {
  final EventModel event;
  final double size;
  const EventHeartButton({super.key, required this.event, this.size = 26});

  @override
  ConsumerState<EventHeartButton> createState() => _EventHeartButtonState();
}

class _EventHeartButtonState extends ConsumerState<EventHeartButton> {
  late bool _saved = widget.event.isSaved;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant EventHeartButton old) {
    super.didUpdateWidget(old);
    if (old.event.id != widget.event.id) _saved = widget.event.isSaved;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_saved;
    setState(() {
      _saved = next;
      _busy = true;
    });
    try {
      final svc = ref.read(eventServiceProvider);
      if (next) {
        await svc.saveEvent(widget.event.id);
      } else {
        await svc.unsaveEvent(widget.event.id);
      }
      ref.invalidate(savedEventsProvider);
    } catch (_) {
      if (mounted) setState(() => _saved = !next); // rollback
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _saved ? 'Retirer des favoris' : 'Ajouter aux favoris',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            _saved
                ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                : PhosphorIcons.heart(),
            size: widget.size,
            color: _saved ? kPrimary : context.tpInkSub,
          ),
        ),
      ),
    );
  }
}

// ── Carte « liste » (résultats de recherche) ──────────────────────────────────

class EventListCard extends StatelessWidget {
  final EventModel event;
  const EventListCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final locked = event.visibility == 'private' && event.isLocked;
    return Semantics(
      button: true,
      label: 'Voir ${event.title}',
      child: GestureDetector(
        onTap: () => context.push('/event/${event.id}'),
        child: Container(
          margin: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm + 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: context.tpHair),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: SizedBox(
                    width: 112,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Cover(event: event),
                        if (event.isSponsored)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: _MiniTag(label: 'Hot 🔥'),
                          ),
                        if (locked)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Color(0x59000000),
                              child: Icon(
                                Icons.lock,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                color: context.tpInk,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          EventHeartButton(event: event),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.organizerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.tpInkSub,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _IconLine(
                        icon: PhosphorIcons.mapPin(),
                        text: eventPlaceLabel(event),
                      ),
                      const Spacer(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _IconLine(
                              icon: PhosphorIcons.calendarBlank(),
                              text: eventShortDate(event),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _PricePill(event: event, compact: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte « grille » (page Explorer tout / bloc surprise) ─────────────────────

class EventGridCard extends StatelessWidget {
  final EventModel event;
  const EventGridCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final locked = event.visibility == 'private' && event.isLocked;
    return Semantics(
      button: true,
      label: 'Voir ${event.title}',
      child: GestureDetector(
        onTap: () => context.push('/event/${event.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: context.tpHair),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(event: event),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.tpCard.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: EventHeartButton(event: event, size: 22),
                      ),
                    ),
                    if (event.isSponsored)
                      const Positioned(
                        left: 8,
                        bottom: 8,
                        child: _MiniTag(label: 'Hot 🔥'),
                      ),
                    if (locked)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x59000000),
                          child: Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    if (event.isFull)
                      const Positioned(
                        left: 8,
                        top: 8,
                        child: _MiniTag(label: 'Complet'),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: context.tpInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _IconLine(
                        icon: PhosphorIcons.calendarBlank(),
                        text: eventShortDate(event),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _PricePill(event: event, compact: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Petits éléments partagés ──────────────────────────────────────────────────

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.tpInkMute),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.tpInkSub,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: kPrimary,
      borderRadius: BorderRadius.circular(Radii.sm),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    ),
  );
}
