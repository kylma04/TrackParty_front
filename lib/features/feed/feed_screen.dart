import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/models/event_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/event_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/event_cards.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_icons.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _isSearching => _searchQuery.isNotEmpty;

  List<EventModel> _runSearch(
    List<EventModel> nearby,
    List<EventModel> trending,
  ) {
    final q = _searchQuery.toLowerCase().trim();
    final seen = <String>{};
    return [...nearby, ...trending]
        .where((e) => seen.add(e.id))
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.city.toLowerCase().contains(q) ||
              e.quartier.toLowerCase().contains(q) ||
              e.organizerName.toLowerCase().contains(q) ||
              e.displayCategoryName.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final displayName = authState is AuthAuthenticated
        ? authState.user.displayName.split(' ').first
        : '';
    final avatarUrl = authState is AuthAuthenticated
        ? authState.user.avatarUrl
        : null;

    final nearbyAsync = ref.watch(nearbyEventsFeedProvider);
    final trendingAsync = ref.watch(trendingEventsFeedProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: () async {
          await Future.wait([
            ref.read(nearbyEventsFeedProvider.notifier).refresh(),
            ref.read(trendingEventsFeedProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TpAvatar(
                            name: displayName,
                            imageUrl: avatarUrl,
                            size: 44,
                          ),
                          const SizedBox(width: Sp.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bonjour',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.tpInkSub,
                                  ),
                                ),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: context.tpInk,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const _BellButton(),
                        ],
                      ),
                      const SizedBox(height: Sp.md),
                      // Barre de recherche + bouton filtre
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: context.tpCard,
                                borderRadius: BorderRadius.circular(
                                  Radii.button,
                                ),
                                border: Border.all(
                                  color: _searchFocus.hasFocus
                                      ? kPrimary.withValues(alpha: 0.5)
                                      : context.tpHair,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sp.md,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    PhosphorIcons.magnifyingGlass(),
                                    color: _isSearching
                                        ? kPrimary
                                        : context.tpInkMute,
                                    size: 20,
                                  ),
                                  const SizedBox(width: Sp.sm),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      focusNode: _searchFocus,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.tpInk,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Recherche un event…',
                                        hintStyle: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: context.tpInkMute,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _searchQuery = v),
                                      textInputAction: TextInputAction.search,
                                    ),
                                  ),
                                  if (_isSearching)
                                    Semantics(
                                      button: true,
                                      label: 'Effacer la recherche',
                                      child: GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          _searchFocus.unfocus();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: Icon(
                                          PhosphorIcons.x(),
                                          color: context.tpInkMute,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.md),
                    ],
                  ),
                ),
              ),
            ),

            // ── MODE RECHERCHE ───────────────────────────────────────────────
            if (_isSearching)
              nearbyAsync.when(
                loading: () =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, _) =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (nearbyPage) => trendingAsync.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, _) =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  data: (trendingPage) {
                    final results = _runSearch(
                      nearbyPage.items,
                      trendingPage.items,
                    );
                    if (results.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.magnifyingGlass(),
                                size: 44,
                                color: context.tpInkMute,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun résultat pour « $_searchQuery »',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.tpInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Essaie un autre nom, quartier ou catégorie.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.tpInkSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => EventListCard(event: results[i]),
                        childCount: results.length,
                      ),
                    );
                  },
                ),
              ),

            // ── MODE NORMAL ──────────────────────────────────────────────────
            if (!_isSearching) ...[
              const SliverToBoxAdapter(child: SizedBox(height: Sp.sm)),
              // ── Près de toi : 3 événements (hors boostés) ─────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Près de toi & Hot',
                  icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                  onSeeAll: () => context.push('/events'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: Sp.sm)),
              SliverToBoxAdapter(
                child: _HorizontalEvents(
                  async: nearbyAsync,
                  maxItems: 3,
                  includeHot: true,
                  emptyLabel: 'Aucun événement pour le moment',
                  onRetry: () =>
                      ref.read(nearbyEventsFeedProvider.notifier).refresh(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: Sp.lg)),
              // ── Tendances : 10 événements max, défilement horizontal ──────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Tendances',
                  icon: PhosphorIcons.flame(PhosphorIconsStyle.fill),
                  onSeeAll: () => context.push('/events'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: Sp.sm)),
              SliverToBoxAdapter(
                child: _HorizontalEvents(
                  async: trendingAsync,
                  maxItems: 10,
                  emptyLabel: 'Aucun événement tendance pour l\'instant',
                  onRetry: () =>
                      ref.read(trendingEventsFeedProvider.notifier).refresh(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: Sp.lg)),
              // ── Univers TrackParty + Explorer tout ────────────────────────
              SliverToBoxAdapter(
                child: _SurpriseGrid(
                  events: [
                    ...?trendingAsync.valueOrNull?.items,
                    ...?nearbyAsync.valueOrNull?.items,
                  ],
                  onExplore: () => context.push('/events'),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Event card (horizontal scroll) ───────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final startFormatted = DateFormat(
      'EEE d MMM · HH\'h\'mm',
      'fr_FR',
    ).format(event.startAt.toLocal());
    final isPaid = event.contributionType == 'monetaire';
    final catMeta = tpCategoryMeta(
      event.category,
      customLabel: event.customCategoryLabel,
    );
    final customEmoji =
        event.category == 'autre' &&
            hasCustomUserEmoji(event.customCategoryEmoji)
        ? event.customCategoryEmoji
        : null;
    final locked = event.visibility == 'private' && event.isLocked;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: Sp.sm),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B1A2E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Radii.card),
            ),
            child: SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'event_cover_${event.id}',
                    child: event.coverImageUrl != null
                        ? ExcludeSemantics(
                            child: CachedNetworkImage(
                              imageUrl: event.coverImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorWidget: (ctx, url, err) =>
                                  _GradientPlaceholder(),
                              placeholder: (ctx, url) => _GradientPlaceholder(),
                            ),
                          )
                        : _GradientPlaceholder(),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _OverlayPill(
                      label: catMeta.label,
                      icon: customEmoji == null ? catMeta.icon : null,
                      emoji: customEmoji,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _OverlayPill(
                      label: isPaid ? 'Payant' : 'Gratuit',
                      icon: isPaid
                          ? PhosphorIcons.coins(PhosphorIconsStyle.fill)
                          : PhosphorIcons.ticket(PhosphorIconsStyle.fill),
                    ),
                  ),
                  if (event.isSponsored)
                    const Positioned(
                      bottom: 10,
                      left: 10,
                      child: _SponsoredPill(),
                    ),
                  if (locked)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  if (event.isFull)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: const Center(
                          child: Text(
                            'COMPLET',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title, //locked ? 'Événement privé' : event.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.tpInk,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.calendar(),
                      size: 12,
                      color: context.tpInkSub,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        startFormatted,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.tpInkSub,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.mapPin(),
                      size: 12,
                      color: context.tpInkSub,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event
                            .quartier, //event.city.isNotEmpty ? event.city : event.addressLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.tpInkSub,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (event.maxParticipants != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: event.maxParticipants! > 0
                          ? event.participantsCount / event.maxParticipants!
                          : 0,
                      backgroundColor: context.tpHair,
                      valueColor: const AlwaysStoppedAnimation(kPrimary),
                      minHeight: 4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: 'Voir le profil de ${event.organizerName}',
                  child: GestureDetector(
                    onTap: () => context.push('/promoter/${event.organizerId}'),
                    child: Row(
                      children: [
                        TpAvatar(
                          name: event.organizerName,
                          imageUrl: event.organizerAvatarUrl,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event
                                .organizerName, //locked ? 'Organisateur masqué' : event.organizerName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── En-tête de section + petit bouton « Voir tout » ──────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback onSeeAll;
  const _SectionHeader({
    required this.title,
    this.icon,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: kPrimary),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          Semantics(
            button: true,
            label: 'Voir tous les événements',
            child: GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Voir tout',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(PhosphorIcons.arrowRight(), size: 12, color: kPrimary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Liste horizontale de cartes (hors événements boostés) ─────────────────────

class _HorizontalEvents extends StatelessWidget {
  final AsyncValue<FeedPage> async;
  final int maxItems;
  // true : les événements mis en avant (Hot) s'ajoutent en tête, avant les `maxItems` autres.
  final bool includeHot;
  final String emptyLabel;
  final VoidCallback onRetry;
  const _HorizontalEvents({
    required this.async,
    required this.maxItems,
    this.includeHot = false,
    required this.emptyLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: async.when(
        loading: () => _HorizontalSkeleton(),
        error: (_, _) => _ErrorHint(onRetry: onRetry),
        data: (page) {
          // Les événements boostés ont leur propre mise en avant : on ne les compte pas ici.
          final items = page.items
              .where((e) => !e.isSponsored)
              .take(maxItems)
              .toList();
          if (items.isEmpty) {
            return Center(
              child: Text(
                emptyLabel,
                style: TextStyle(
                  color: context.tpInkSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            itemCount: items.length,
            addAutomaticKeepAlives: false,
            itemBuilder: (context, i) => Semantics(
              button: true,
              label: 'Voir ${items[i].title}',
              child: GestureDetector(
                onTap: () => context.push('/event/${items[i].id}'),
                child: _EventCard(event: items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Grille « L'univers TrackParty » + bouton Explorer tout ────────────────────

class _SurpriseGrid extends StatelessWidget {
  final List<EventModel> events;
  final VoidCallback onExplore;
  const _SurpriseGrid({required this.events, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final covers = events
        .where((e) => e.coverImageUrl != null && seen.add(e.id))
        .take(3)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'L\'univers TrackParty vous réserve d\'autres surprises',
            style: TextStyle(
              fontSize: 19,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: context.tpInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: Sp.sm + 4),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: Sp.sm,
            crossAxisSpacing: Sp.sm,
            childAspectRatio: 1.25,
            children: [
              for (var i = 0; i < 3; i++)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: i < covers.length
                      ? GestureDetector(
                          onTap: () => context.push('/event/${covers[i].id}'),
                          child: ExcludeSemantics(
                            child: CachedNetworkImage(
                              imageUrl: covers[i].coverImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _GradientPlaceholder(),
                              placeholder: (_, _) => _GradientPlaceholder(),
                            ),
                          ),
                        )
                      : _GradientPlaceholder(),
                ),
              GestureDetector(
                onTap: onExplore,
                child: Container(
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Et bien plus encore…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Explorer tout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _GradientPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
}

class _SponsoredPill extends StatelessWidget {
  const _SponsoredPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: kTertiary,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E0B1118),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: Colors.white,
          ),
          SizedBox(width: 3),
          Text(
            'Hot',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? emoji;
  const _OverlayPill({required this.label, this.icon, this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ] else if (emoji != null && emoji!.isNotEmpty) ...[
            Text(emoji!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer skeletons ─────────────────────────────────────────────────────────

class _HorizontalSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = context.isDark ? kCardDark : kHairLight;
    final highlight = context.isDark ? kCardAltDark : kBgLight;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        itemCount: 3,
        itemBuilder: (_, _) => Container(
          width: 220,
          margin: const EdgeInsets.only(right: Sp.sm),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
        ),
      ),
    );
  }
}

class _ErrorHint extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorHint({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Impossible de charger les events',
            style: TextStyle(fontSize: 13, color: context.tpInkSub),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Réessayer', style: TextStyle(color: kPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Bell button with unread badge ─────────────────────────────────────────────

class _BellButton extends ConsumerWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotifCountProvider);
    return Semantics(
      label: unread > 0 ? '$unread notifications non lues' : 'Notifications',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/notifications'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(Radii.button),
                border: Border.all(color: context.tpHair),
              ),
              child: Icon(PhosphorIcons.bell(), color: context.tpInk, size: 22),
            ),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: context.tpBg, width: 1.5),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
