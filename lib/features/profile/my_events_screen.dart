import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/event_model.dart';
import '../../core/providers/event_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_photo.dart';

const _tabs = <(String, String)>[
  ('participating', 'Je participe'),
  ('participated', "J'ai participé"),
  ('organizing', "J'organise"),
  ('organized', "J'ai organisé"),
];

class MyEventsScreen extends ConsumerStatefulWidget {
  final String initialTab;
  const MyEventsScreen({super.key, this.initialTab = 'participating'});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  late String _type;

  @override
  void initState() {
    super.initState();
    _type = _tabs.any((t) => t.$1 == widget.initialTab)
        ? widget.initialTab
        : 'participating';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myEventsProvider(_type));

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Mes événements',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Onglets ─────────────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 8),
              children: [
                for (final t in _tabs) ...[
                  _TabChip(
                    label: t.$2,
                    selected: _type == t.$1,
                    onTap: () => setState(() => _type = t.$1),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnRefresh: true,
              loading: () => const Center(
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
              error: (_, _) => _ErrorView(
                  onRetry: () => ref.invalidate(myEventsProvider(_type))),
              data: (events) {
                if (events.isEmpty) return _EmptyView(type: _type);
                return RefreshIndicator(
                  color: kPrimary,
                  onRefresh: () async => ref.invalidate(myEventsProvider(_type)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 100),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _MyEventCard(event: events[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

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
              color: selected ? kPrimary : context.tpHair,
              width: 1.4,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : context.tpInk)),
        ),
      );
}

class _MyEventCard extends StatelessWidget {
  final EventModel event;
  const _MyEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE d MMM', 'fr_FR').format(event.startAt);
    final time = DateFormat('HH:mm').format(event.startAt);
    final cancelled = event.status == 'cancelled';

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: const [
            BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(Radii.lg)),
            child: SizedBox(
              width: 90,
              height: 90,
              child: event.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: event.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const TpPhoto(),
                      placeholder: (_, _) => const TpPhoto(),
                    )
                  : const TpPhoto(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.tpInk)),
                    ),
                    if (cancelled)
                      Container(
                        margin: const EdgeInsets.only(left: 6, right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kError.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: const Text('Annulé',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: kError)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(PhosphorIcons.calendarBlank(), color: kPrimary, size: 13),
                    const SizedBox(width: 4),
                    Text('$date · $time',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.tpInkSub)),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(PhosphorIcons.mapPin(), color: kTertiary, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          event.addressLabel.isNotEmpty
                              ? event.addressLabel
                              : event.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.tpInkSub)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(PhosphorIcons.caretRight(),
                color: context.tpInkMute, size: 16),
          ),
        ]),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String type;
  const _EmptyView({required this.type});

  @override
  Widget build(BuildContext context) {
    final (emoji, msg) = switch (type) {
      'participating' => ('🎟️', 'Tu ne participes à aucun événement à venir.'),
      'participated' => ('📜', 'Tu n\'as encore participé à aucun événement.'),
      'organizing' => ('🎤', 'Tu n\'organises aucun événement à venir.'),
      _ => ('🗂️', 'Tu n\'as encore organisé aucun événement.'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.tpInkSub)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.cloudSlash(), color: context.tpInkMute, size: 44),
            const SizedBox(height: 14),
            Text('Impossible de charger.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.tpInkSub)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer',
                  style:
                      TextStyle(color: kPrimary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}
