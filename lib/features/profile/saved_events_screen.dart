import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/event_model.dart';
import '../../core/providers/event_provider.dart';
import '../../core/services/event_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_photo.dart';

class SavedEventsScreen extends ConsumerWidget {
  const SavedEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedEventsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
          ),
        ),
        title: Text('Mes favoris',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
        error: (_, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIcons.warning(), color: kError, size: 40),
            const SizedBox(height: 12),
            Text('Erreur de chargement', style: TextStyle(color: context.tpInkSub)),
          ]),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🤍', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text('Aucun favori pour l\'instant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
                const SizedBox(height: 6),
                Text('Appuie sur ❤️ dans un événement pour le sauvegarder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkSub)),
              ]),
            );
          }
          return RefreshIndicator(
            color: kPrimary,
            onRefresh: () => ref.refresh(savedEventsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 100),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _SavedEventCard(event: events[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SavedEventCard extends ConsumerWidget {
  final EventModel event;
  const _SavedEventCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('EEE d MMM', 'fr_FR').format(event.startAt);
    final time = DateFormat('HH:mm').format(event.startAt);

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          // Cover
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 90, height: 90,
              child: event.coverImageUrl != null
                  ? Image.network(event.coverImageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const TpPhoto())
                  : const TpPhoto(),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(PhosphorIcons.calendarBlank(), color: kPrimary, size: 13),
                  const SizedBox(width: 4),
                  Text('$date · $time',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(PhosphorIcons.mapPin(), color: const Color(0xFFEC4899), size: 13),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(event.addressLabel.isNotEmpty ? event.addressLabel : event.city,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                  ),
                ]),
              ]),
            ),
          ),
          // Unsave button
          GestureDetector(
            onTap: () async {
              await ref.read(eventServiceProvider).unsaveEvent(event.id);
              ref.invalidate(savedEventsProvider);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill),
                  color: const Color(0xFFEC4899), size: 22),
            ),
          ),
        ]),
      ),
    );
  }
}
