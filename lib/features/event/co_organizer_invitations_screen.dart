import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/co_organizer_provider.dart';
import '../../core/services/co_organizer_service.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class CoOrganizerInvitationsScreen extends ConsumerWidget {
  const CoOrganizerInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(coOrganizerInvitationsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 16),
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
              Text('Invitations co-organisateur',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: () => ref.refresh(coOrganizerInvitationsProvider.future),
              child: invitationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ListView(
                  children: [
                    SizedBox(
                      height: 300,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.warningCircle(), size: 40, color: context.tpInkMute),
                          const SizedBox(height: 12),
                          Text('Impossible de charger les invitations',
                              style: TextStyle(fontSize: 14, color: context.tpInkSub)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => ref.invalidate(coOrganizerInvitationsProvider),
                            child: const Text('Réessayer',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                data: (invitations) {
                  if (invitations.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(PhosphorIcons.envelope(), size: 52, color: context.tpInkMute),
                              const SizedBox(height: 16),
                              Text('Aucune invitation en attente',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
                              const SizedBox(height: 8),
                              Text('Tu n\'as pas encore été invité à co-organiser un événement.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: context.tpInkSub)),
                            ]),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        Sp.md, 0, Sp.md, MediaQuery.of(context).padding.bottom + 20),
                    itemCount: invitations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _InvitationCard(
                      invitation: invitations[i],
                      onAccept: () => _respond(context, ref, invitations[i], accept: true),
                      onDecline: () => _respond(context, ref, invitations[i], accept: false),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    CoOrganizerInvitationModel invitation, {
    required bool accept,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(coOrganizerInvitationsProvider.notifier)
          .respond(invitation.id, accept: accept);
      messenger.showSnackBar(SnackBar(
        content: Text(accept
            ? 'Tu co-organises maintenant « ${invitation.eventTitle} » !'
            : 'Invitation refusée'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: accept ? const Color(0xFF22A865) : context.tpCard,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Une erreur est survenue'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kError,
      ));
    }
  }
}

// ── Invitation card ───────────────────────────────────────────────────────────

class _InvitationCard extends StatelessWidget {
  final CoOrganizerInvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: Shadows.md,
        border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(PhosphorIcons.usersThree(), color: kPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invitation.eventTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk)),
              Text('Invité par ${invitation.invitedByName}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // Invitation label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8)),
          child: Text(
            '${invitation.invitedByName} t\'invite à co-organiser cet événement.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary),
          ),
        ),
        const SizedBox(height: 14),
        // Actions
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onDecline,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.tpHair)),
                child: Center(
                  child: Text('Refuser',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInkSub)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onAccept,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                  child: Text('Accepter',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
