import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/chat_model.dart';
import '../../core/models/event_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/event_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/event_service.dart';
import '../../core/services/invitation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/event_share_sheet.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_badge.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_photo.dart';
import '../../widgets/tp_skeleton.dart';
import '../../widgets/tp_toast.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.id));

    return eventAsync.when(
      loading: () =>
          const Scaffold(body: SingleChildScrollView(child: SkEventDetail())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Impossible de charger l\'événement',
                style: TextStyle(color: context.tpInkSub),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.read(eventDetailProvider(widget.id).notifier).refresh(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (event) => _EventDetailContent(
        event: event,
        expanded: _expanded,
        onToggleExpand: () => setState(() => _expanded = !_expanded),
        onParticipate: (itemId, qty) => ref
            .read(eventDetailProvider(widget.id).notifier)
            .participate(contributionItemId: itemId, quantity: qty),
        onCancelParticipation: () => ref
            .read(eventDetailProvider(widget.id).notifier)
            .cancelParticipation(),
        onJoinWaitlist: () =>
            ref.read(eventDetailProvider(widget.id).notifier).participate(),
      ),
    );
  }
}

class _EventDetailContent extends ConsumerStatefulWidget {
  final EventModel event;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final Future<void> Function(String? itemId, int quantity) onParticipate;
  final Future<void> Function() onCancelParticipation;
  final Future<void> Function() onJoinWaitlist;

  const _EventDetailContent({
    required this.event,
    required this.expanded,
    required this.onToggleExpand,
    required this.onParticipate,
    required this.onCancelParticipation,
    required this.onJoinWaitlist,
  });

  @override
  ConsumerState<_EventDetailContent> createState() =>
      _EventDetailContentState();
}

class _EventDetailContentState extends ConsumerState<_EventDetailContent> {
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = widget.event.organizerIsFollowing;
  }

  @override
  void didUpdateWidget(_EventDetailContent old) {
    super.didUpdateWidget(old);
    if (old.event.organizerIsFollowing != widget.event.organizerIsFollowing) {
      _following = widget.event.organizerIsFollowing;
    }
  }

  EventModel get event => widget.event;

  @override
  Widget build(BuildContext context) {
    final heroH = (MediaQuery.of(context).size.height * 0.42).clamp(
      260.0,
      420.0,
    );
    return Scaffold(
      backgroundColor: context.tpBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: heroH, child: _buildHero(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TpBadge.category(event.category),
                              const SizedBox(width: Sp.sm),
                              if (event.contributionType != 'free')
                                TpBadge.contrib(_contribLabel(event.contributionType)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${event.title}${event.quartier.isNotEmpty ? ' · ${event.quartier}' : ''}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: context.tpInk,
                              letterSpacing: -0.8,
                              height: 1.05,
                              shadows: const [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                      child: _buildOrganizerCard(context),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                _buildInfoGrid(context),
                _buildOrganizerTools(context),
                _buildDescription(context),
                if (event.contributionItems.isNotEmpty)
                  _buildContributions(context),
                _buildMinimap(context),
                _buildParticipantActions(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomCta(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'event_cover_${event.id}',
            child: event.coverImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: event.coverImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (ctx, url, err) => const TpPhoto(),
                    placeholder: (ctx, url) => const TpPhoto(),
                  )
                : const TpPhoto(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0x11000000), // subtle overlay
                  Colors.transparent,
                  Colors.transparent,
                  context.tpBg,
                ],
                stops: const [0.0, 0.12, 0.88, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.md,
                vertical: Sp.sm,
              ),
              child: Builder(
                builder: (context) {
                  final authState = ref.read(authNotifierProvider).valueOrNull;
                  final userId = authState is AuthAuthenticated
                      ? authState.user.id
                      : null;
                  final isOrganizer =
                      userId != null && event.organizerId == userId;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /*
                      _HeroBtn(
                        icon: PhosphorIcons.caretLeft(),
                        semanticLabel: 'Retour',
                        // Bouton commenté temporairement — peut être réutilisé plus tard
                        onTap: () => context.pop(),
                      ),
                      */
                      const SizedBox(width: 44),
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            if (isOrganizer) ...[
                              _HeroBtn(
                                icon: PhosphorIcons.pencilSimple(),
                                semanticLabel: 'Modifier l\'événement',
                                backgroundColor: Colors.grey.shade700
                                    .withValues(alpha: 0.9),
                                onTap: () => context.push(
                                  '/event/${event.id}/edit',
                                  extra: event,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _HeroBtn(
                                icon: PhosphorIcons.copySimple(),
                                semanticLabel: 'Dupliquer l\'événement',
                                backgroundColor: Colors.grey.shade700
                                    .withValues(alpha: 0.9),
                                onTap: () => context.push(
                                  '/event/${event.id}/clone',
                                  extra: event,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _HeroBtn(
                              icon: event.isSaved
                                  ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                                  : PhosphorIcons.heart(),
                              semanticLabel: event.isSaved
                                  ? 'Retirer des favoris'
                                  : 'Sauvegarder',
                              activeColor: kTertiary,
                              active: event.isSaved,
                              backgroundColor: event.isSaved
                                  ? null
                                  : Colors.grey.shade700.withValues(alpha: 0.9),
                              onTap: () async {
                                final svc = ref.read(eventServiceProvider);
                                if (event.isSaved) {
                                  await svc.unsaveEvent(event.id);
                                } else {
                                  await svc.saveEvent(event.id);
                                }
                                ref.invalidate(eventDetailProvider(event.id));
                                ref.invalidate(savedEventsProvider);
                              },
                            ),
                            const SizedBox(height: 8),
                            _HeroBtn(
                              icon: PhosphorIcons.shareNetwork(),
                              semanticLabel: 'Partager',
                              backgroundColor: Colors.grey.shade700.withValues(
                                alpha: 0.9,
                              ),
                              onTap: () => showEventShareSheet(
                                context,
                                eventId: event.id,
                                eventTitle: event.title,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // badges and title moved out of the hero to avoid duplication
        ],
      ),
    );
  }

  Widget _buildOrganizerCard(BuildContext context) {
    final org = event.organizer;
    final name = org?.displayName ?? event.organizerName;
    final avatarUrl = org?.avatarUrl ?? event.organizerAvatarUrl;
    final rating = org?.promoterProfile?.avgRating ?? event.avgRating;

    final authState = ref.read(authNotifierProvider).valueOrNull;
    final myId = authState is AuthAuthenticated ? authState.user.id : null;
    final isMyEvent = myId != null && event.organizerId == myId;

    return Semantics(
      button: event.organizerId.isNotEmpty,
      label: 'Voir le profil de $name',
      child: GestureDetector(
        onTap: event.organizerId.isNotEmpty
            ? () => context.push('/promoter/${event.organizerId}')
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.card),
            boxShadow: Shadows.md,
          ),
          child: Row(
            children: [
              TpAvatar(
                name: name,
                imageUrl: avatarUrl,
                size: 52,
                ringColor: kAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: context.tpInk,
                            ),
                          ),
                        ),
                        if (event.organizerIsPromoter) ...[
                          const SizedBox(width: Sp.sm),
                          TpBadge.promoter(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          rating.round().clamp(0, 5),
                          (_) => Icon(
                            PhosphorIcons.star(PhosphorIconsStyle.fill),
                            color: kWarning,
                            size: 14,
                          ),
                        ),
                        ...List.generate(
                          (5 - rating.round()).clamp(0, 5),
                          (_) => Icon(
                            PhosphorIcons.star(),
                            color: kWarning,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.tpInkSub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isMyEvent && event.organizerId.isNotEmpty) ...[
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: _following
                      ? 'Se désabonner'
                      : 'Suivre ${event.organizerName}',
                  child: GestureDetector(
                    onTap: () async {
                      final wasFollowing = _following;
                      setState(() => _following = !_following);
                      try {
                        if (wasFollowing) {
                          await ref
                              .read(authServiceProvider)
                              .unfollowPromoter(event.organizerId);
                        } else {
                          await ref
                              .read(authServiceProvider)
                              .followPromoter(event.organizerId);
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(() => _following = wasFollowing);
                          TpToast.error(
                            context,
                            wasFollowing
                                ? 'Impossible de se désabonner'
                                : 'Impossible de suivre ce promoteur',
                          );
                        }
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _following ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.tag),
                        border: Border.all(color: kPrimary, width: 1.5),
                      ),
                      child: Text(
                        _following ? 'Abonné ✓' : 'Suivre',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _following ? Colors.white : kPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    final startFormatted = DateFormat(
      'EEE d MMM · HH\'h\'mm',
      'fr_FR',
    ).format(event.startAt.toLocal());
    final location = [
      event.quartier,
      event.city,
    ].where((s) => s.isNotEmpty).join(', ');
    final participantLabel = event.maxParticipants != null
        ? '${event.participantsCount} / ${event.maxParticipants}'
        : '${event.participantsCount} participants';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: PhosphorIcons.calendar(),
                  iconColor: kPrimary,
                  title: startFormatted,
                  subtitle: _relativeDate(event.startAt),
                ),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: _InfoCard(
                  icon: PhosphorIcons.mapPin(),
                  iconColor: kError,
                  title: location.isNotEmpty ? location : event.addressLabel,
                  subtitle: event.addressLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Voir les participants',
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/event/${event.id}/participants'),
                    child: _InfoCard(
                      icon: PhosphorIcons.users(),
                      iconColor: kSuccess,
                      title: participantLabel,
                      subtitle: 'Voir participants →',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: _InfoCard(
                  icon: PhosphorIcons.gift(),
                  iconColor: kWarning,
                  title: _contribLabel(event.contributionType),
                  subtitle: event.contributionType == 'nature'
                      ? '${event.contributionItems.length} items'
                      : event.contributionAmount != null
                      ? '${event.contributionAmount!.toStringAsFixed(0)} FCFA'
                      : 'Entrée libre',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizerTools(BuildContext context) {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    final isOrganizer = userId != null && event.organizerId == userId;
    if (!isOrganizer) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Semantics(
        button: true,
        label: 'Tableau de bord de l\'événement',
        child: GestureDetector(
          onTap: () => context.push(
            '/event/${event.id}/dashboard',
            extra: {'title': event.title},
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x284F46E5),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(
                    PhosphorIcons.chartBar(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Entrées · Staff · Co-orgas →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight(),
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final desc = event.description ?? '';
    if (desc.isEmpty) return const SizedBox.shrink();
    final short = desc.length > 120 ? '${desc.substring(0, 120)}…' : desc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À propos',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.tpInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: Sp.sm),
          Text(
            widget.expanded ? desc : short,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.tpInkSub,
              height: 1.5,
            ),
          ),
          if (desc.length > 120)
            Semantics(
              button: true,
              label: widget.expanded ? 'Voir moins' : 'Voir plus',
              child: GestureDetector(
                onTap: widget.onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.expanded ? 'Voir moins' : 'Voir plus',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContributions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contributions attendues',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.tpInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: Sp.sm),
          ...event.contributionItems.map((item) => _ContribRow(item: item)),
        ],
      ),
    );
  }

  Widget _buildMinimap(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Localisation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.tpInk,
                  letterSpacing: -0.3,
                ),
              ),
              Semantics(
                button: true,
                label: 'Voir sur la carte',
                child: GestureDetector(
                  onTap: () => context.go(
                    '/map?eventLat=${event.latitude ?? ''}&eventLng=${event.longitude ?? ''}&eventTitle=${Uri.encodeComponent(event.title)}&eventId=${event.id}',
                  ),
                  child: const Text(
                    'Itinéraire →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'Carte de localisation — ${event.addressLabel}',
            button: true,
            child: GestureDetector(
              onTap: () => context.go(
                '/map?eventLat=${event.latitude ?? ''}&eventLng=${event.longitude ?? ''}&eventTitle=${Uri.encodeComponent(event.title)}&eventId=${event.id}',
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: SizedBox(
                  height: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _MinimapPainter()),
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, -28),
                          child: _MinimapPin(
                            emoji: _categoryEmoji(event.category),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xBB000000), Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('📍 ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  event.addressLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Text(
                                'Voir →',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantActions(BuildContext context) {
    final participating = event.isParticipating;
    final canScan = event.canScan;
    if (!participating && !canScan) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Column(
        children: [
          if (participating) ...[
            Semantics(
              button: true,
              label: 'Mon billet',
              child: GestureDetector(
                onTap: () => context.push('/ticket/${event.id}'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: kSuccess.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kSuccess.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(
                          PhosphorIcons.ticket(PhosphorIconsStyle.fill),
                          color: kSuccess,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mon billet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: context.tpInk,
                              ),
                            ),
                            Text(
                              'Voir mon QR code d\'entrée',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.tpInkSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        PhosphorIcons.caretRight(),
                        color: context.tpInkMute,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (canScan) ...[
            if (participating) const SizedBox(height: 10),
            Semantics(
              button: true,
              label: 'Scanner les entrées',
              child: GestureDetector(
                onTap: () => context.push('/event/${event.id}/scan'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: kPrimary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(
                          PhosphorIcons.qrCode(),
                          color: kPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scanner les entrées',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: context.tpInk,
                              ),
                            ),
                            Text(
                              'Scanner le QR code d\'un billet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.tpInkSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        PhosphorIcons.caretRight(),
                        color: context.tpInkMute,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomCta(BuildContext context) {
    final participating = event.isParticipating;
    final waitlisted = event.isWaitlisted;
    final past = event.isPast;
    final cancelled = event.status == 'cancelled';
    final fullNoSlot = event.isFull && !participating && !waitlisted;

    final iconData = participating
        ? PhosphorIcons.xCircle()
        : waitlisted
        ? PhosphorIcons.clockCountdown()
        : fullNoSlot
        ? PhosphorIcons.listPlus()
        : PhosphorIcons.checkCircle();

    String label;
    if (cancelled) {
      label = 'Événement annulé';
    } else if (past) {
      label = 'Événement terminé';
    } else if (participating) {
      label = 'Annuler ma participation';
    } else if (waitlisted) {
      final pos = event.waitlistPosition;
      label = pos != null
          ? 'En attente — #$pos · Quitter'
          : 'En liste d\'attente · Quitter';
    } else if (fullNoSlot) {
      label = 'Rejoindre la liste d\'attente';
    } else {
      final count = event.maxParticipants != null
          ? '${event.participantsCount} / ${event.maxParticipants}'
          : '${event.participantsCount}';
      label = 'Je participe — $count';
    }

    final isDisabled = cancelled || past;

    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1B1A2E),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.md),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Ouvrir le chat de l\'événement',
                child: GestureDetector(
                  onTap: () => context.push('/chat/${event.id}'),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: context.tpHair),
                    ),
                    child: Icon(
                      PhosphorIcons.chatCircle(),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Sp.md),
              Semantics(
                button: true,
                label: 'Inviter un ami',
                child: GestureDetector(
                  onTap: () => _showInviteSheet(context),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: context.tpHair),
                    ),
                    child: Icon(
                      PhosphorIcons.userPlus(),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: TpButton(
                  label: label,
                  icon: iconData,
                  fullWidth: true,
                  state: isDisabled
                      ? TpButtonState.disabled
                      : TpButtonState.idle,
                  onPressed: isDisabled
                      ? null
                      : () {
                          if (participating || waitlisted) {
                            widget.onCancelParticipation();
                          } else if (fullNoSlot) {
                            widget.onJoinWaitlist();
                          } else if (event.contributionType == 'nature' &&
                              event.contributionItems.isNotEmpty) {
                            _showContribSheet(context);
                          } else {
                            widget.onParticipate(null, 1);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContribSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContribSelectionSheet(
        items: event.contributionItems,
        onConfirm: (itemId, qty) {
          Navigator.pop(context);
          widget.onParticipate(itemId, qty);
        },
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(eventId: event.id, eventTitle: event.title),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Terminé';
    if (diff.inDays == 0) return 'Ce soir';
    if (diff.inDays == 1) return 'Demain';
    return 'Dans ${diff.inDays} jours';
  }
}

String _contribLabel(String type) => switch (type) {
  'nature' => 'En nature',
  'money' => 'Payant',
  _ => 'Gratuit',
};

String _categoryEmoji(String category) => switch (category) {
  'soiree' => '🎉',
  'concert' => '🎵',
  'sport' => '⚽',
  'art' => '🎨',
  'plage' => '🏖',
  _ => '✨',
};

// ── Hero button ───────────────────────────────────────────────────────────────

class _HeroBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool active;
  final Color? activeColor;
  final Color? backgroundColor;

  const _HeroBtn({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.active = false,
    this.activeColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor != null
                ? backgroundColor
                : (active && activeColor != null
                      ? activeColor!.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: context.tpHair),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.tag),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.tpInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.tpInkSub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contribution row ──────────────────────────────────────────────────────────

class _ContribRow extends StatelessWidget {
  final ContributionItemModel item;
  const _ContribRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final ratio = item.quantityTotal > 0
        ? item.quantityTaken / item.quantityTotal
        : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: context.tpHair),
        ),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.tpInk,
                        ),
                      ),
                      Text(
                        '${item.quantityRemaining} restant${item.quantityRemaining > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: item.isAvailable ? kSuccess : kError,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xs),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: context.tpHair,
                      valueColor: AlwaysStoppedAnimation(
                        item.isAvailable ? kPrimary : kError,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantityTaken} / ${item.quantityTotal} pris',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkSub,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contribution selection sheet ──────────────────────────────────────────────

class _ContribSelectionSheet extends StatefulWidget {
  final List<ContributionItemModel> items;
  final void Function(String itemId, int quantity) onConfirm;
  const _ContribSelectionSheet({required this.items, required this.onConfirm});

  @override
  State<_ContribSelectionSheet> createState() => _ContribSelectionSheetState();
}

class _ContribSelectionSheetState extends State<_ContribSelectionSheet> {
  String? _selectedId;
  int _qty = 1;

  ContributionItemModel? get _selectedItem => _selectedId == null
      ? null
      : widget.items.where((i) => i.id == _selectedId).firstOrNull;

  void _selectItem(String id) {
    setState(() {
      _selectedId = id;
      _qty = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    final maxQty = selected?.quantityRemaining ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: context.tpHair,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: Sp.md),
            Text(
              'Que vas-tu apporter ?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.tpInk,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choisis un item et la quantité',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
              ),
            ),
            const SizedBox(height: Sp.md),

            // Item list
            ...widget.items.map((item) {
              final isSelected = _selectedId == item.id;
              return Semantics(
                button: true,
                enabled: item.isAvailable,
                selected: isSelected,
                label: '${item.name}${item.isAvailable ? '' : ' — complet'}',
                child: GestureDetector(
                  onTap: item.isAvailable ? () => _selectItem(item.id) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: Sp.sm),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: !item.isAvailable
                          ? context.tpHair
                          : isSelected
                          ? kPrimary.withValues(alpha: 0.08)
                          : context.tpCard,
                      borderRadius: BorderRadius.circular(Radii.button),
                      border: Border.all(
                        color: isSelected ? kPrimary : context.tpHair,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          item.emoji,
                          style: TextStyle(
                            fontSize: 22,
                            color: item.isAvailable ? null : context.tpInkMute,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: item.isAvailable
                                      ? context.tpInk
                                      : context.tpInkMute,
                                ),
                              ),
                              Text(
                                item.isAvailable
                                    ? '${item.quantityRemaining} restant${item.quantityRemaining > 1 ? 's' : ''}'
                                    : 'Complet',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: item.isAvailable
                                      ? context.tpInkSub
                                      : kError,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!item.isAvailable)
                          const Text(
                            'Complet',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kError,
                            ),
                          )
                        else if (isSelected)
                          Icon(
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: kPrimary,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Quantité (visible seulement après sélection d'un item)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: selected == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: Sp.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(Radii.button),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quantité',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.tpInk,
                              ),
                            ),
                            Row(
                              children: [
                                Semantics(
                                  button: true,
                                  label: 'Diminuer',
                                  child: GestureDetector(
                                    onTap: _qty > 1
                                        ? () => setState(() => _qty--)
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 100,
                                      ),
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _qty > 1
                                            ? kPrimary
                                            : context.tpHair,
                                        borderRadius: BorderRadius.circular(
                                          Radii.tag,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '−',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: _qty > 1
                                              ? Colors.white
                                              : context.tpInkMute,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    '$_qty',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: context.tpInk,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                Semantics(
                                  button: true,
                                  label: 'Augmenter',
                                  child: GestureDetector(
                                    onTap: _qty < maxQty
                                        ? () => setState(() => _qty++)
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 100,
                                      ),
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _qty < maxQty
                                            ? kPrimary
                                            : context.tpHair,
                                        borderRadius: BorderRadius.circular(
                                          Radii.tag,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '+',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: _qty < maxQty
                                              ? Colors.white
                                              : context.tpInkMute,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            TpButton(
              label: _selectedId == null
                  ? 'Choisir un item'
                  : 'Confirmer — $_qty ${_qty > 1 ? '${selected!.emoji} apporté(s)' : '${selected!.emoji} apporté'}',
              fullWidth: true,
              state: _selectedId == null
                  ? TpButtonState.disabled
                  : TpButtonState.idle,
              onPressed: _selectedId == null
                  ? null
                  : () => widget.onConfirm(_selectedId!, _qty),
            ),
            const SizedBox(height: Sp.lg),
          ],
        ),
      ),
    );
  }
}

// ── Minimap ───────────────────────────────────────────────────────────────────

// ── Invite sheet ──────────────────────────────────────────────────────────────

class _InviteSheet extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;
  const _InviteSheet({required this.eventId, required this.eventTitle});

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _searchCtrl = TextEditingController();
  List<UserSearchResult> _results = [];
  bool _searching = false;
  String? _sending; // userId being invited
  final Set<String> _done = {};
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(invitationServiceProvider)
          .searchUsers(q.trim());
      if (mounted)
        setState(() {
          _results = results;
          _searching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _invite(UserSearchResult user) {
    if (_done.contains(user.id)) return;
    setState(() => _done.add(user.id));
    unawaited(_sendInviteAsync(user));
  }

  Future<void> _sendInviteAsync(UserSearchResult user) async {
    try {
      await ref
          .read(invitationServiceProvider)
          .sendInvitation(receiverId: user.id, eventId: widget.eventId);
    } catch (_) {
      if (mounted) setState(() => _done.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.cardLg),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        Sp.md,
        12,
        Sp.md,
        Sp.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: context.tpHair,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Inviter un ami',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.tpInk,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.eventTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Search field
            Container(
              decoration: BoxDecoration(
                color: context.tpBg,
                borderRadius: BorderRadius.circular(Radii.button),
                border: Border.all(color: context.tpHair),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.magnifyingGlass(),
                    color: context.tpInkMute,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.tpInk,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Recherche par nom…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: context.tpInkMute,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      onChanged: _onSearch,
                    ),
                  ),
                  if (_searching)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Results
            if (_results.isEmpty && !_searching && _searchCtrl.text.length >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Aucun utilisateur trouvé',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.tpInkSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final user = _results[i];
                    final invited = _done.contains(user.id);
                    final sending = _sending == user.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          TpAvatar(
                            name: user.displayName,
                            imageUrl: user.avatarUrl,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: context.tpInk,
                                  ),
                                ),
                                if (user.isPromoter)
                                  Text(
                                    'Promoteur',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: invited
                                ? 'Déjà invité'
                                : 'Inviter ${user.displayName}',
                            child: GestureDetector(
                              onTap: invited || sending
                                  ? null
                                  : () => _invite(user),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: invited ? null : trackpartyGradient,
                                  color: invited ? context.tpHair : null,
                                  borderRadius: BorderRadius.circular(
                                    Radii.tag,
                                  ),
                                ),
                                child: sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        invited ? '✓ Invité' : 'Inviter',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: invited
                                              ? context.tpInkMute
                                              : Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Minimap ───────────────────────────────────────────────────────────────────

class _MinimapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFE8E4DC),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.30, h * 0.40),
        width: w * 0.7,
        height: h * 1.0,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0xFFC9D9C2), Colors.transparent],
            ).createShader(
              Rect.fromCenter(
                center: Offset(w * 0.30, h * 0.40),
                width: w * 0.7,
                height: h * 1.0,
              ),
            ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.70, h * 0.60),
        width: w * 0.7,
        height: h * 0.9,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0xFFA8D5E5), Colors.transparent],
            ).createShader(
              Rect.fromCenter(
                center: Offset(w * 0.70, h * 0.60),
                width: w * 0.7,
                height: h * 0.9,
              ),
            ),
    );
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sx = w / 380, sy = h / 140;
    canvas.drawPath(
      Path()
        ..moveTo(-20 * sx, 60 * sy)
        ..quadraticBezierTo(150 * sx, 80 * sy, 380 * sx, 100 * sy),
      roadPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(120 * sx, -20 * sy)
        ..quadraticBezierTo(140 * sx, 80 * sy, 130 * sx, 160 * sy),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MinimapPin extends StatelessWidget {
  final String emoji;
  const _MinimapPin({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: trackpartyGradient,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}
