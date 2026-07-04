import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
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
import '../../widgets/tp_pro_badge.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_confirm_sheet.dart';
import '../../widgets/tp_photo.dart';
import '../../widgets/tp_skeleton.dart';
import '../../widgets/tp_toast.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String id;
  // Code d'invitation issu d'un lien partagé (deeplink ?invite=CODE).
  final String? inviteCode;
  const EventDetailScreen({super.key, required this.id, this.inviteCode});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with WidgetsBindingObserver {
      bool _expanded = false;
      Timer? _pollTimer;

      @override
      void initState() {
        super.initState();
        WidgetsBinding.instance.addObserver(this);
        final code = widget.inviteCode;
        if (code != null && code.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _redeemInvite(code));
        }
        _startPollingIfPending();
      }

      @override
      void dispose() {
        WidgetsBinding.instance.removeObserver(this);
        _pollTimer?.cancel();
        super.dispose();
      }

      @override
      void didChangeAppLifecycleState(AppLifecycleState state) {
        if (state == AppLifecycleState.resumed) {
          ref.read(eventDetailProvider(widget.id).notifier).refresh();
        }
      }

      void _startPollingIfPending() {
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          final event = ref.read(eventDetailProvider(widget.id)).valueOrNull;
          if (event == null) return;
          if (event.myJoinRequestStatus == 'pending') {
            ref.read(eventDetailProvider(widget.id).notifier).refresh();
          } else {
            _pollTimer?.cancel();
          }
        });
      }

  Future<void> _redeemInvite(String code) async {
    try {
      final res =
          await ref.read(invitationServiceProvider).joinByLink(widget.id, code);
      if (!mounted) return;
      TpToast.success(
        context,
        res.requiresPurchase
            ? '🎟️ Accès débloqué — choisis ta place'
            : '🎉 Tu as rejoint l\'événement !',
      );
      ref.read(eventDetailProvider(widget.id).notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      TpToast.error(
        context,
        e is ApiException ? e.message : 'Lien d\'invitation invalide.',
      );
    }
  }

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
  double? _distanceKm; // distance user → event (km), si la position est connue

  @override
  void initState() {
    super.initState();
    _following = widget.event.organizerIsFollowing;
    _loadDistanceToEvent();
  }

  /// Calcule la distance jusqu'à l'événement à partir de la position GPS — mais
  /// seulement si la permission est DÉJÀ accordée (on n'ouvre aucune popup à
  /// l'ouverture du détail). Sert au marqueur « Moi » et au badge de distance.
  Future<void> _loadDistanceToEvent() async {
    final lat = widget.event.latitude, lng = widget.event.longitude;
    if (lat == null || lng == null) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final meters =
          Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
      if (mounted) setState(() => _distanceKm = meters / 1000);
    } catch (_) {}
  }

  String _fmtKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  @override
  void didUpdateWidget(_EventDetailContent old) {
    super.didUpdateWidget(old);
    if (old.event.organizerIsFollowing != widget.event.organizerIsFollowing) {
      _following = widget.event.organizerIsFollowing;
    }
  }

  EventModel get event => widget.event;
  bool get _locked {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;

    final isOrganizer = userId != null && event.organizerId == userId;
    final isCoOrganizer = event.isCoOrganizer;

    return event.isLocked && !isOrganizer && !isCoOrganizer;
  }

  Future<void> _confirmDeleteEvent() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await TpConfirmSheet.show(
      context,
      title: 'Supprimer cet événement ?',
      body: 'Cette action est irréversible. L\'événement « ${event.title} » et '
          'ses billets seront définitivement supprimés. Les participants '
          'confirmés seront prévenus.',
      confirmLabel: 'Supprimer',
      icon: PhosphorIcons.trash(),
    );
    if (!confirmed) return;
    try {
      await ref.read(eventServiceProvider).deleteEvent(event.id);
      // Rafraîchir les feeds pour que l'événement disparaisse immédiatement.
      ref.invalidate(nearbyEventsFeedProvider);
      ref.invalidate(trendingEventsFeedProvider);
      ref.invalidate(myEventStatsProvider);
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Événement supprimé.')),
      );
    } catch (e) {
      if (mounted) TpToast.error(context, 'Échec de la suppression.');
    }
  }

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
                              TpBadge.eventCategory(
                                category: event.category,
                                label: event.displayCategoryName,
                                emoji: event.displayEmoji,
                              ),

                              const SizedBox(width: Sp.sm),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: event.visibility == 'private'
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  event.visibility == 'private'
                                      ? '🔒 Privé'
                                      : '🌍 Public',
                                ),
                              ),

                              const SizedBox(width: Sp.sm),

                              if (event.contributionType != 'gratuit')
                                TpBadge.contrib(
                                  _contribLabel(event.contributionType),
                                ),
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
                if (_locked) _buildPrivateLockedNotice(context),
                _buildDescription(context),
                if (event.ticketCategories.isNotEmpty)
                  _buildTicketCategories(context),
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

  Widget _buildPrivateLockedNotice(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWarning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: kWarning.withValues(alpha: 0.35)),
        ),
        child: const Text(
          'Cet événement est privé. Pour participer, envoyez une demande à l’organisateur.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                              _HeroBtn(
                                icon: PhosphorIcons.trash(),
                                semanticLabel: 'Supprimer l\'événement',
                                backgroundColor:
                                    kError.withValues(alpha: 0.9),
                                onTap: _confirmDeleteEvent,
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
                        if (event.organizerIsPro) ...[
                          const SizedBox(width: 6),
                          const TpProBadge(),
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
    final participantLabel = !event.showTicketCounts
        ? 'Participants'
        : event.maxParticipants != null
            ? '${event.participantsCount} / ${event.maxParticipants}'
            : '${event.participantsCount} participants';

    // Seuls l'organisateur et les co-organisateurs peuvent ouvrir la liste des
    // participants. Pour les autres, on retire le bouton de navigation : on garde
    // une carte d'info (non cliquable) si les compteurs sont publics, sinon on
    // laisse la carte « contribution » occuper toute la largeur.
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    final isOrganizer = userId != null && event.organizerId == userId;
    final canSeeParticipants = isOrganizer || event.isCoOrganizer;
    final showParticipantsInfo = !canSeeParticipants && event.showTicketCounts;

    final contribCard = _InfoCard(
      icon: PhosphorIcons.gift(),
      iconColor: kWarning,
      title: _contribLabel(event.contributionType),
      subtitle: event.contributionType != 'monetaire'
          ? 'Entrée libre'
          : [
              // Prix de départ basé sur les catégories (à jour),
              // sinon prix unique legacy.
              if (event.priceFrom != null)
                'Dès ${event.priceFrom} FCFA'
              else if (event.contributionAmount != null)
                '${event.contributionAmount!.toStringAsFixed(0)} FCFA',
              if (event.contributionItems.isNotEmpty)
                '${event.contributionItems.length} en nature',
            ].join(' · '),
    );

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
          if (canSeeParticipants)
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
                Expanded(child: contribCard),
              ],
            )
          else if (showParticipantsInfo)
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    icon: PhosphorIcons.users(),
                    iconColor: kSuccess,
                    title: participantLabel,
                    subtitle: 'Inscrits',
                  ),
                ),
                const SizedBox(width: Sp.sm),
                Expanded(child: contribCard),
              ],
            )
          else
            contribCard,
        ],
      ),
    );
  }

  Widget _buildOrganizerTools(BuildContext context) {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    final isOrganizer = userId != null && event.organizerId == userId;
    // Les co-organisateurs accèdent aussi au tableau de bord (participants,
    // entrées, staff…). Le backend les autorise déjà sur ces endpoints.
    final canManage = isOrganizer || event.isCoOrganizer;
    if (!canManage) return const SizedBox.shrink();

    // Le boost (promo payante) reste réservé à l'organisateur principal.
    final canBoost = isOrganizer &&
        event.status == 'published' &&
        (event.visibility == 'public' || event.showPrivateEventPublicly);

    return Column(
      children: [
        _buildDashboardEntry(context),
        if (canBoost) _buildBoostEntry(context),
      ],
    );
  }

  Widget _buildDashboardEntry(BuildContext context) {
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

  Widget _buildBoostEntry(BuildContext context) {
    final sponsored = event.isSponsored;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Semantics(
        button: true,
        label: 'Booster cet événement',
        child: GestureDetector(
          onTap: () => context.push(
            '/event/${event.id}/boost',
            extra: {'title': event.title},
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.tpCard,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sponsored ? 'Boost actif 🚀' : 'Booster mon événement',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: context.tpInk,
                        ),
                      ),
                      Text(
                        sponsored
                            ? 'En avant dans le fil et sur la carte'
                            : 'Plus de visibilité dans le fil et la carte →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tpInkSub,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIcons.caretRight(), color: context.tpInkSub, size: 18),
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
            'Contributions attendues équivalent à un ticket payé',
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

  Widget _buildTicketCategories(BuildContext context) {
    final cats = [...event.ticketCategories]
      ..sort((a, b) => a.order.compareTo(b.order));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billets',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.tpInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: Sp.sm),
          // Les cartes de billets sont purement informatives (aucune action au tap).
          ...cats.map((c) => _CategoryCard(
                category: c,
                showCounts: event.showTicketCounts,
              )),
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
                          child: _MinimapPin(emoji: event.displayEmoji),
                        ),
                      ),
                      // Marqueur « ma position » (visible si le GPS est connu)
                      if (_distanceKm != null)
                        const Positioned(
                          left: 22,
                          bottom: 42,
                          child: _MinimapMeMarker(),
                        ),
                      // Badge de distance réelle
                      if (_distanceKm != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xE61B1A2E),
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.personSimpleWalk(),
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'à ${_fmtKm(_distanceKm!)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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
              label: event.myTicketsCount > 1 ? 'Mes billets' : 'Mon billet',
              child: GestureDetector(
                onTap: () => context.push(
                    event.myTicketsCount > 1 ? '/my-tickets' : '/ticket/${event.id}'),
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
                              event.myTicketsCount > 1
                                  ? 'Mes billets (${event.myTicketsCount})'
                                  : 'Mon billet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: context.tpInk,
                              ),
                            ),
                            Text(
                              event.myTicketsCount > 1
                                  ? 'Voir tes QR codes d\'entrée'
                                  : 'Voir mon QR code d\'entrée',
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

    // Event payant : acquisition de billets via le panier (jamais d'annulation
    // au niveau de l'event ; les billets payants ne s'annulent pas).
    final isPaid = event.contributionType == 'monetaire';
    final maxT = event.maxTicketsPerUserPerEvent;
    final atLimit = isPaid && maxT != null && event.myTicketsCount >= maxT;
    final hasTickets = event.myTicketsCount > 0;

    // Event payant par catégorie « complet » : plus aucune catégorie en vente
    // NI option en nature disponible. (max_participants est null dans ce mode,
    // donc event.isFull ne le détecte pas — on regarde le stock réel.)
    final usesCategories = event.ticketCategories.isNotEmpty;
    final paidSoldOut = isPaid && usesCategories &&
        !event.ticketCategories.any((c) => c.price > 0 && c.onSale && !c.isSoldOut) &&
        !event.contributionItems.any((i) => i.isAvailable);

    final IconData? iconData = isPaid
        ? ((atLimit || paidSoldOut) ? null : PhosphorIcons.ticket()) // pas d'icône → texte centré
        : participating
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
    } else if (isPaid) {
      if (paidSoldOut) {
        label = 'Événement complet';
      } else if (atLimit) {
        label = 'Déjà $maxT billets (max)';
      } else if (hasTickets) {
        label = 'Acheter d\'autres billets';
      } else {
        label = 'Je participe';
      }
    } else if (participating) {
      label = 'Annuler ma participation';
    } else if (waitlisted) {
      final pos = event.waitlistPosition;
      label = pos != null
          ? 'En attente — #$pos · Quitter'
          : 'En liste d\'attente · Quitter';
    } else if (fullNoSlot) {
      label = 'Rejoindre la liste d\'attente';
    } else if (event.showTicketCounts) {
      final count = event.maxParticipants != null
          ? '${event.participantsCount} / ${event.maxParticipants}'
          : '${event.participantsCount}';
      label = 'Je participe — $count';
    } else {
      label = 'Je participe';
    }

    final isDisabled = cancelled || past || atLimit || paidSoldOut;

    if (_locked) {
      final status = event.myJoinRequestStatus;

      final String ctaLabel;
      final IconData ctaIcon;
      final bool ctaDisabled;

      if (status == 'pending') {
        ctaLabel = 'Demande envoyée — en attente';
        ctaIcon = PhosphorIcons.clockCountdown();
        ctaDisabled = true;
      } else if (status == 'rejected') {
        ctaLabel = 'Demande refusée — Renvoyer';
        ctaIcon = PhosphorIcons.arrowCounterClockwise();
        ctaDisabled = false;
      } else {
        ctaLabel = 'Envoyer une demande de participation';
        ctaIcon = PhosphorIcons.paperPlaneTilt();
        ctaDisabled = false;
      }

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
            child: TpButton(
              label: ctaLabel,
              icon: ctaIcon,
              fullWidth: true,
              state: ctaDisabled ? TpButtonState.disabled : TpButtonState.idle,
              onPressed: ctaDisabled
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(eventServiceProvider)
                            .requestPrivateJoin(event.id);
                        if (!context.mounted) return;
                        TpToast.success(
                          context,
                          'Demande envoyée à l\'organisateur.',
                        );
                        // Rafraîchir l'événement pour mettre à jour le statut
                        ref.invalidate(eventDetailProvider(event.id));
                      } catch (_) {
                        if (!context.mounted) return;
                        TpToast.error(
                          context,
                          'Impossible d\'envoyer la demande.',
                        );
                      }
                    },
            ),
          ),
        ),
      );
    }

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
                          if (isPaid) {
                            // Event payant : on acquiert des billets (panier).
                            if (event.ticketCategories.isNotEmpty) {
                              context.push('/event/${event.id}/participate',
                                  extra: event);
                            } else {
                              _showContribSheet(context); // legacy prix unique ± nature
                            }
                          } else if (participating || waitlisted) {
                            widget.onCancelParticipation(); // gratuit : annuler/quitter
                          } else if (fullNoSlot) {
                            widget.onJoinWaitlist();
                          } else {
                            widget.onParticipate(null, 1); // gratuit : participer
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
        amount: event.contributionAmount?.toInt(),
        onConfirm: (itemId, qty) {
          Navigator.pop(context);
          widget.onParticipate(itemId, qty);
        },
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    // Organisateur / co-org d'un événement privé → écran d'invitation complet
    // (sélection par listes + « tout sélectionner » + lien partageable). Sinon,
    // sheet simple d'invitation par recherche (un destinataire à la fois).
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    final isOrganizer = userId != null && event.organizerId == userId;
    final canBulk = (isOrganizer || event.isCoOrganizer) &&
        event.visibility == 'private';
    if (canBulk) {
      context.push('/event/${event.id}/invite', extra: {'title': event.title});
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(eventId: event.id, eventTitle: event.title),
    );
  }

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.isBefore(now)) return 'Terminé';

    // Comparaison en jours CALENDAIRES (pas en tranches de 24 h).
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dt.year, dt.month, dt.day);
    final days = eventDay.difference(today).inDays;

    if (days == 0) return dt.hour >= 18 ? 'Ce soir' : "Aujourd'hui";
    if (days == 1) return 'Demain';
    if (days < 7) return 'Dans $days jours';
    if (days < 14) return 'Dans une semaine';
    return 'Dans ${days ~/ 7} semaines';
  }
}

String _contribLabel(String type) => switch (type) {
  'monetaire' => 'Payant',
  _ => 'Gratuit',
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

// ── Carte catégorie de billet ─────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final TicketCategoryModel category;
  final bool showCounts;
  const _CategoryCard({required this.category, this.showCounts = false});

  Color get _accent {
    final c = category.color;
    if (c.length == 7 && c.startsWith('#')) {
      final v = int.tryParse(c.substring(1), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    // Catégorie épuisée → carte grisée (avec le badge « Complet » conservé).
    return Opacity(
      opacity: category.isSoldOut ? 0.5 : 1,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.tpHair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(category.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk)),
            ),
            Text('${category.price} FCFA',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: _accent)),
          ]),
          if (category.advantages.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...category.advantages.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                              color: _accent, shape: BoxShape.circle),
                        ),
                      ),
                      Expanded(
                        child: Text(a,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: context.tpInkSub)),
                      ),
                    ],
                  ),
                )),
          ],
          if (_stockLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _stockColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(_stockLabel!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _stockColor)),
            ),
          ],
        ],
      ),
      ),
    );
  }

  String? get _stockLabel {
    // « Complet » est toujours montré (info d'achat essentielle) ; les compteurs
    // de places ne sont révélés que si le promoteur l'a activé.
    if (category.isSoldOut) return 'Complet';
    if (!showCounts) return null;
    if (category.isLowStock) return 'Dernières places';
    if (category.remaining != null) return '${category.remaining} billets restants';
    return null;
  }

  Color get _stockColor {
    if (category.isSoldOut) return kError;
    if (category.isLowStock) return kAccent;
    return kSuccess;
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
      child: Opacity(
      opacity: item.isAvailable ? 1 : 0.5,
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
                        item.isAvailable
                            ? '${item.quantityRemaining} restant${item.quantityRemaining > 1 ? 's' : ''}'
                            : 'Épuisé',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: item.isAvailable ? kSuccess : kError,
                        ),
                      ),
                    ],
                  ),
                  if (item.categoryName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Donne un billet ${item.categoryName}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                  ],
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
      ),
    );
  }
}

// ── Contribution selection sheet ──────────────────────────────────────────────

class _ContribSelectionSheet extends StatefulWidget {
  final List<ContributionItemModel> items;
  final int? amount;
  // itemId == null → le participant choisit de payer.
  final void Function(String? itemId, int quantity) onConfirm;
  const _ContribSelectionSheet({
    required this.items,
    required this.amount,
    required this.onConfirm,
  });

  @override
  State<_ContribSelectionSheet> createState() => _ContribSelectionSheetState();
}

class _ContribSelectionSheetState extends State<_ContribSelectionSheet> {
  static const _kPay = '__pay__';
  String? _selectedId;
  int _qty = 1;

  ContributionItemModel? get _selectedItem =>
      (_selectedId == null || _selectedId == _kPay)
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
              'Comment participer ?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.tpInk,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.amount != null && widget.items.isNotEmpty
                  ? 'Paie l\'entrée ou apporte une contribution'
                  : widget.amount != null
                  ? 'Confirme ta participation'
                  : 'Choisis ce que tu apportes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
              ),
            ),
            const SizedBox(height: Sp.md),

            // Option « Payer »
            if (widget.amount != null) ...[
              GestureDetector(
                onTap: () => setState(() {
                  _selectedId = _kPay;
                  _qty = 1;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: Sp.sm),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selectedId == _kPay
                        ? kPrimary.withValues(alpha: 0.08)
                        : context.tpCard,
                    borderRadius: BorderRadius.circular(Radii.button),
                    border: Border.all(
                      color: _selectedId == _kPay ? kPrimary : context.tpHair,
                      width: _selectedId == _kPay ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payer l\'entrée',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.tpInk,
                              ),
                            ),
                            Text(
                              '${widget.amount} FCFA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.tpInkSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedId == _kPay)
                        Icon(
                          PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                          color: kPrimary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.sm),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: context.tpHair)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'ou en nature',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: context.tpInkMute,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.tpHair)),
                    ],
                  ),
                ),
            ],

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
                  ? 'Choisis une option'
                  : _selectedId == _kPay
                  ? 'Payer ${widget.amount} FCFA'
                  : 'Confirmer — $_qty ${_qty > 1 ? '${selected!.emoji} apporté(s)' : '${selected!.emoji} apporté'}',
              fullWidth: true,
              state: _selectedId == null
                  ? TpButtonState.disabled
                  : TpButtonState.idle,
              onPressed: _selectedId == null
                  ? null
                  : () => _selectedId == _kPay
                        ? widget.onConfirm(null, 1)
                        : widget.onConfirm(_selectedId, _qty),
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
  const _InviteSheet({
    required this.eventId,
    required this.eventTitle,
  });

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _done.remove(user.id));
      // Affiche le motif (ex. « passe au plan Pro », opt-out, blocage…).
      final msg = e is ApiException ? e.message : 'Invitation impossible.';
      TpToast.error(context, msg);
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

/// Marqueur « ma position » sur la mini-carte (point bleu façon GPS + label).
class _MinimapMeMarker extends StatelessWidget {
  const _MinimapMeMarker();

  static const _blue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: const Text(
            'Moi',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _blue),
          ),
        ),
        const SizedBox(height: 3),
        // Halo + point
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _blue.withValues(alpha: 0.22),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
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
