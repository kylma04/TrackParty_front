import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/providers/ticket_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_skeleton.dart';
import 'my_tickets_screen.dart' show TicketTile;

class EventTicketsScreen extends ConsumerWidget {
  final String eventId;
  final String eventTitle;
  const EventTicketsScreen({super.key, required this.eventId, required this.eventTitle});

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
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: context.tpCard,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(eventTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: () => ref.refresh(myTicketsProvider.future),
              child: ticketsAsync.when(
                loading: () => SkList(count: 3, builder: (_) => const SkEventCard()),
                error: (_, _) => Center(
                  child: Text('Impossible de charger tes billets',
                      style: TextStyle(color: context.tpInkSub)),
                ),
                data: (tickets) {
                  final filtered = tickets.where((t) => t.eventId == eventId).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('Aucun billet pour cet événement.',
                          style: TextStyle(color: context.tpInkSub)),
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
            ),
          ),
        ]),
      ),
    );
  }
}