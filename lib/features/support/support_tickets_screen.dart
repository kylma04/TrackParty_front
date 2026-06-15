import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/support_model.dart';
import '../../core/services/support_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Garde la liste à jour pendant qu'elle est ouverte (aperçu + non-lus).
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        ref.invalidate(supportTicketsProvider);
        ref.invalidate(supportUnreadProvider);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(supportTicketsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Mes demandes',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/new'),
        backgroundColor: kPrimary,
        icon: Icon(PhosphorIcons.plus(), color: Colors.white, size: 18),
        label: const Text('Nouvelle demande',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: tickets.when(
        skipLoadingOnRefresh: true,
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (_, _) =>
            _ErrorView(onRetry: () => ref.invalidate(supportTicketsProvider)),
        data: (list) {
          if (list.isEmpty) return const _EmptyView();
          return RefreshIndicator(
            color: kPrimary,
            onRefresh: () async => ref.invalidate(supportTicketsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 90),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TicketCard(ticket: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, fg, bg) = supportStatusStyle(ticket.status);
    return GestureDetector(
      onTap: () => context.push('/support/${ticket.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(ticket.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.tpInk)),
              ),
              if (ticket.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 10,
                  height: 10,
                  decoration:
                      const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _Chip(label: supportCategoryLabel(ticket.category)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
              ),
              const Spacer(),
              Text(supportDateShort(ticket.lastMessageAt),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkMute)),
            ]),
            if (ticket.lastPreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ticket.lastPreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkSub)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: kPrimary)),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                    gradient: trackpartyGradient, shape: BoxShape.circle),
                child: Icon(PhosphorIcons.chatsCircle(),
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text('Aucune demande',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk)),
              const SizedBox(height: 6),
              Text(
                  'Une question ou un souci ? Ouvre une demande, '
                  'l’équipe TrackParty te répond directement ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkSub)),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.cloudSlash(), color: context.tpInkMute, size: 48),
              const SizedBox(height: 16),
              Text('Impossible de charger tes demandes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkSub)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('Réessayer',
                    style:
                        TextStyle(color: kPrimary, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
}
