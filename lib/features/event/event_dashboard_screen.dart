import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/event_model.dart';
import '../../core/providers/event_provider.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class EventDashboardScreen extends ConsumerWidget {
  final String eventId;
  final String eventTitle;

  const EventDashboardScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(eventStatsProvider(eventId));

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // App bar
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dashboard',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
                  Text(eventTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ]),
              ),
              Semantics(
                button: true,
                label: 'Actualiser',
                child: GestureDetector(
                  onTap: () => ref.invalidate(eventStatsProvider(eventId)),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(Radii.tag),
                        boxShadow: Shadows.sm),
                    child: Icon(PhosphorIcons.arrowClockwise(), color: context.tpInkSub, size: 16),
                  ),
                ),
              ),
            ]),
          ),

          // Content
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.warningCircle(), size: 40, color: context.tpInkMute),
                  const SizedBox(height: 12),
                  Text('Impossible de charger les statistiques',
                      style: TextStyle(fontSize: 14, color: context.tpInkSub)),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Réessayer',
                    child: GestureDetector(
                      onTap: () => ref.invalidate(eventStatsProvider(eventId)),
                      child: const Text('Réessayer',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
                    ),
                  ),
                ]),
              ),
              data: (stats) => _DashboardBody(
                stats: stats,
                eventId: eventId,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Dashboard body ────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final EventStats stats;
  final String eventId;

  const _DashboardBody({required this.stats, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, MediaQuery.of(context).padding.bottom + 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Statut badge
        _StatusBadge(status: stats.status),
        const SizedBox(height: Sp.md),

        // Taux de remplissage (si max défini)
        if (stats.maxParticipants != null) ...[
          _FillRateCard(stats: stats),
          const SizedBox(height: Sp.md),
        ],

        // KPI grid
        Text('Chiffres clés',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.3)),
        const SizedBox(height: 10),
        _KpiGrid(stats: stats),
        const SizedBox(height: Sp.lg),

        // Taux de présence
        if (stats.participantsCount > 0) ...[
          _CheckinRateCard(stats: stats),
          const SizedBox(height: Sp.lg),
        ],

        // Actions rapides
        Text('Actions rapides',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.3)),
        const SizedBox(height: 10),
        _QuickActions(eventId: eventId, eventTitle: stats.title, stats: stats),
      ]),
    );
  }
}

// ── Statut badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'published'  => ('✅ Publié', kSuccess),
      'draft'      => ('📝 Brouillon', kAccent),
      'cancelled'  => ('❌ Annulé', kError),
      'past'       => ('🏁 Terminé', context.tpInkSub),
      _            => (status, context.tpInkSub),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ── Fill rate card ────────────────────────────────────────────────────────────

class _FillRateCard extends StatelessWidget {
  final EventStats stats;
  const _FillRateCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = (stats.fillRate * 100).round();
    final color = pct >= 90 ? kError : pct >= 60 ? kAccent : kPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Shadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(PhosphorIcons.users(), size: 18, color: color),
          const SizedBox(width: 8),
          Text('Remplissage',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
          const Spacer(),
          Text('$pct%',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xs),
          child: LinearProgressIndicator(
            value: stats.fillRate.clamp(0.0, 1.0),
            backgroundColor: context.tpHair,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text('${stats.participantsCount} / ${stats.maxParticipants} places',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
      ]),
    );
  }
}

// ── Checkin rate card ─────────────────────────────────────────────────────────

class _CheckinRateCard extends StatelessWidget {
  final EventStats stats;
  const _CheckinRateCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = (stats.checkinRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Shadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              size: 18, color: kSuccess),
          const SizedBox(width: 8),
          Text('Taux de présence',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
          const Spacer(),
          Text('$pct%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kSuccess)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xs),
          child: LinearProgressIndicator(
            value: stats.checkinRate.clamp(0.0, 1.0),
            backgroundColor: context.tpHair,
            valueColor: const AlwaysStoppedAnimation(kSuccess),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text('${stats.checkinsCount} présents sur ${stats.participantsCount} inscrits',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
      ]),
    );
  }
}

// ── KPI grid 2×3 ─────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final EventStats stats;
  const _KpiGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem(icon: PhosphorIcons.users(), label: 'Inscrits',
          value: '${stats.participantsCount}', color: kPrimary),
      _KpiItem(icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), label: 'Présents',
          value: '${stats.checkinsCount}', color: kSuccess),
      _KpiItem(icon: PhosphorIcons.clock(), label: 'Attente',
          value: '${stats.waitlistCount}', color: kAccent),
      _KpiItem(icon: PhosphorIcons.identificationBadge(), label: 'Staff',
          value: '${stats.staffCount}', color: kAccent),
      _KpiItem(icon: PhosphorIcons.usersThree(), label: 'Co-orgas',
          value: '${stats.coOrganizersCount}', color: kViolet),
      _KpiItem(
        icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
        label: 'Note (${stats.reviewsCount} avis)',
        value: stats.avgRating > 0 ? stats.avgRating.toStringAsFixed(1) : '—',
        color: kWarning,
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      children: items.map((item) => _KpiCard(item: item)).toList(),
    );
  }
}

class _KpiItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _KpiItem({required this.icon, required this.label, required this.value, required this.color});
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: Shadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(item.icon, color: item.color, size: 16),
        ),
        const Spacer(),
        Text(item.value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(item.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkSub),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  final EventStats stats;

  const _QuickActions({required this.eventId, required this.eventTitle, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ActionRow(
        icon: PhosphorIcons.listChecks(),
        iconColor: kSuccess,
        label: 'Voir les check-ins',
        subtitle: '${stats.checkinsCount} entrées validées',
        onTap: () => context.push('/event/$eventId/checkins', extra: {'title': eventTitle}),
      ),
      const SizedBox(height: 10),
      _ActionRow(
        icon: PhosphorIcons.identificationBadge(),
        iconColor: kAccent,
        label: 'Gérer le staff',
        subtitle: '${stats.staffCount} scanner${stats.staffCount > 1 ? 's' : ''} actif${stats.staffCount > 1 ? 's' : ''}',
        onTap: () => context.push('/event/$eventId/staff', extra: {'title': eventTitle}),
      ),
      const SizedBox(height: 10),
      _ActionRow(
        icon: PhosphorIcons.usersThree(),
        iconColor: kViolet,
        label: 'Co-organisateurs',
        subtitle: '${stats.coOrganizersCount} co-orga${stats.coOrganizersCount > 1 ? 's' : ''}',
        onTap: () => context.push('/event/$eventId/co-organizers', extra: {'title': eventTitle}),
      ),
      if (stats.waitlistCount > 0) ...[
        const SizedBox(height: 10),
        _ActionRow(
          icon: PhosphorIcons.clock(),
          iconColor: kAccent,
          label: 'Liste d\'attente',
          subtitle: '${stats.waitlistCount} personne${stats.waitlistCount > 1 ? 's' : ''} en attente',
          onTap: () => context.push('/event/$eventId/waitlist', extra: {'title': eventTitle}),
        ),
      ],
    ]);
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.button),
            boxShadow: Shadows.sm),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Radii.md)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub)),
            ]),
          ),
          Icon(PhosphorIcons.caretRight(), color: context.tpInkMute, size: 16),
        ]),
      ),
      ),
    );
  }
}
