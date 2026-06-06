import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/promoter_model.dart';
import '../../core/providers/promoter_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import 'trust_score_sheet.dart';
import 'report_sheet.dart';

class PromoterProfileScreen extends ConsumerStatefulWidget {
  final String id;
  const PromoterProfileScreen({super.key, required this.id});
  @override
  ConsumerState<PromoterProfileScreen> createState() => _PromoterProfileScreenState();
}

class _PromoterProfileScreenState extends ConsumerState<PromoterProfileScreen> {
  int _tab = 0;
  bool _followLoading = false;

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      await ref.read(promoterProfileProvider(widget.id).notifier).toggleFollow();
    } catch (_) {} finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(promoterProfileProvider(widget.id));

    return Scaffold(
      backgroundColor: context.tpBg,
      body: profileAsync.when(
        loading: () => const _LoadingBody(),
        error: (_, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Impossible de charger ce profil',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            const SizedBox(height: 12),
            Semantics(
              button: true, label: 'Réessayer',
              child: GestureDetector(
              onTap: () => ref.invalidate(promoterProfileProvider(widget.id)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
                child: const Text('Réessayer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              ),
            ),
          ]),
        ),
        data: (promoter) => SingleChildScrollView(
          child: Column(children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildHeader(context, promoter),
                Positioned(
                  left: 0, right: 0, bottom: -32,
                  child: _buildStatsCard(context, promoter),
                ),
              ],
            ),
            const SizedBox(height: 48), // espace pour la stats card qui dépasse du header
            _buildCtas(context, promoter),
            if ((promoter.bio ?? '').isNotEmpty) _buildBio(context, promoter.bio!),
            _buildTabs(context, promoter),
            _buildContent(context, promoter),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PromoterData promoter) {
    return SizedBox(
      height: 360,
      child: Stack(children: [
        Container(
          height: 360,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [kPrimary, kSecondary, kTertiary]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
          ),
          child: Stack(children: [
            Positioned(top: -60, right: -40,
              child: Container(width: 200, height: 200, decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent])))),
            Positioned(bottom: -40, left: -40,
              child: Container(width: 220, height: 220, decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [kAccent.withValues(alpha: 0.32), Colors.transparent])))),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(button: true, label: 'Retour',
                  child: _GlassBtn(icon: PhosphorIcons.caretLeft(), onTap: () => context.pop())),
                Semantics(button: true, label: 'Signaler ce profil',
                  child: _GlassBtn(
                    icon: PhosphorIcons.dotsThreeVertical(),
                    onTap: () => ReportSheet.show(context,
                      targetType: 'user', targetId: widget.id, blockUserId: widget.id,
                      targetName: promoter.displayName),
                  )),
              ],
            ),
          ),
        ),
        Positioned(
          top: 110, left: 0, right: 0,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.3)),
              child: TpAvatar(
                name: promoter.displayName, imageUrl: promoter.avatarUrl,
                size: 104, ringColor: Colors.white),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(promoter.displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(gradient: coralGradient, borderRadius: BorderRadius.circular(6)),
                child: Text(promoter.starLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 8),
            Semantics(button: true, label: 'Voir le score de confiance',
              child: GestureDetector(
                onTap: () => TrustScoreSheet.show(context, userId: widget.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ...List.generate(
                      promoter.avgRating.floor(),
                      (_) => Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: kWarning, size: 12)),
                    if (promoter.avgRating < 5)
                      Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: Colors.white38, size: 12),
                    const SizedBox(width: 6),
                    Text(promoter.avgRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 4),
                    Text('· ${promoter.badgeLabel}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85))),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStatsCard(BuildContext context, PromoterData p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: context.tpCard, borderRadius: BorderRadius.circular(22), boxShadow: Shadows.lg),
        child: Row(children: [
          _Stat(n: '${p.totalEvents}', l: 'Événements'),
          Container(width: 1, height: 40, color: context.tpHair),
          _Stat(n: p.participantsLabel, l: 'Participants'),
          Container(width: 1, height: 40, color: context.tpHair),
          _Stat(n: '${p.followerCount}', l: 'Abonnés'),
        ]),
      ),
    );
  }

  Widget _buildCtas(BuildContext context, PromoterData p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 8),
      child: Column(children: [
        // Suivre — pleine largeur, CTA principal
        Semantics(
          button: true,
          label: p.isFollowing ? 'Se désabonner de ${p.displayName}' : 'Suivre ${p.displayName}',
          child: GestureDetector(
            onTap: _followLoading ? null : _toggleFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              decoration: BoxDecoration(
                gradient: p.isFollowing ? null : trackpartyGradient,
                color: p.isFollowing ? context.tpCard : null,
                borderRadius: BorderRadius.circular(Radii.button),
                border: p.isFollowing ? Border.all(color: context.tpHair) : null,
                boxShadow: p.isFollowing ? null : Shadows.brand,
              ),
              child: _followLoading
                  ? const Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(p.isFollowing ? PhosphorIcons.check() : PhosphorIcons.plus(),
                        color: p.isFollowing ? kPrimary : Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(p.isFollowing ? 'Abonné ✓' : 'Suivre',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                            color: p.isFollowing ? kPrimary : Colors.white)),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Message + Communauté — actions secondaires
        Row(children: [
          Expanded(
            child: Semantics(
              button: true, label: 'Envoyer un message à ${p.displayName}',
              child: GestureDetector(
                onTap: () => context.push('/chat/new', extra: {
                'userId':      p.id,
                'displayName': p.displayName,
                'avatarUrl':   p.avatarUrl,
              }),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.tpCard, borderRadius: BorderRadius.circular(Radii.button),
                    border: Border.all(color: kPrimary, width: 2),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(PhosphorIcons.chatCircle(), color: kPrimary, size: 18),
                    const SizedBox(width: 6),
                    const Text('Message',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true, label: 'Rejoindre la communauté de ${p.displayName}',
              child: GestureDetector(
                onTap: () => context.push('/community/${p.id}'),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.tpCard, borderRadius: BorderRadius.circular(Radii.button),
                    border: Border.all(color: context.tpHair),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(PhosphorIcons.megaphone(), color: context.tpInk, size: 18),
                    const SizedBox(width: 6),
                    Text('Communauté',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildBio(BuildContext context, String bio) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, 16),
      child: Text(bio,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkSub, height: 1.45)),
    );
  }

  Widget _buildTabs(BuildContext context, PromoterData p) {
    final tabs = [
      ('À venir', null),
      ('Passés', null),
      ('Avis', p.ratingsCount),
    ];
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.tpHair))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = i == _tab;
            return Expanded(
              child: Semantics(
                label: tabs[i].$1, selected: active, button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: active ? kPrimary : Colors.transparent, width: 3))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(tabs[i].$1,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                            color: active ? kPrimary : context.tpInkSub)),
                      if (tabs[i].$2 != null) ...[
                        const SizedBox(width: 4),
                        Text('${tabs[i].$2}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: context.tpInkMute)),
                      ],
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PromoterData promoter) {
    if (_tab == 2) {
      return Semantics(
        button: true, label: 'Voir tous les avis de ${promoter.displayName}',
        child: GestureDetector(
          onTap: () => context.push('/promoter/${widget.id}/reviews'),
          child: Padding(
            padding: const EdgeInsets.all(Sp.md),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: gradientSoft, borderRadius: BorderRadius.circular(Radii.button),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: const Text('Voir tous les avis →',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary)),
            ),
          ),
        ),
      );
    }

    final eventsAsync = ref.watch(promoterEventsProvider(
      (userId: widget.id, type: _tab == 0 ? 'upcoming' : 'past')));

    return eventsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Sp.md),
        child: Center(child: SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5))),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(Sp.md),
        child: Center(child: Text('Impossible de charger les événements',
          style: TextStyle(fontSize: 13, color: context.tpInkSub))),
      ),
      data: (events) {
        if (events.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 32, Sp.md, 32),
            child: Center(
              child: Text(
                _tab == 0 ? 'Aucun événement à venir' : 'Aucun événement passé',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(Sp.md),
          child: Column(
            children: events.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MiniEventRow(event: e),
            )).toList(),
          ),
        );
      },
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(Radii.md)),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String n, l;
  const _Stat({required this.n, required this.l});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
          color: context.tpInk, letterSpacing: -0.6)),
      const SizedBox(height: 1),
      Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
    ]),
  );
}

class _MiniEventRow extends StatelessWidget {
  final PromoterEventItem event;
  const _MiniEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.categoryColor;
    final emoji = event.categoryEmoji;
    final dateStr = DateFormat("EEE d MMM · HH'h'", 'fr_FR').format(event.startAt.toLocal());

    return Semantics(
      button: true, label: event.title,
      child: GestureDetector(
        onTap: () => context.push('/event/${event.id}'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.tpCard, borderRadius: BorderRadius.circular(18), boxShadow: Shadows.sm),
          child: Row(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(Radii.button)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                      color: context.tpInk, letterSpacing: -0.3)),
                const SizedBox(height: 3),
                Text('$dateStr · ${event.participantsCount} viennent',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
              ]),
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(PhosphorIcons.caretRight(), color: kPrimary, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}
