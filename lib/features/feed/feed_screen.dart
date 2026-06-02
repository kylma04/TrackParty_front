import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/event_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/event_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_chip.dart';


class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _filterIndex = 0;

  static const _chips = ['Tous ✨', 'Ce soir 🌙', 'Weekend 🎉', 'Gratuit 💸'];

  String? get _dateFilter {
    switch (_filterIndex) {
      case 1:
        return 'tonight';
      case 2:
        return 'weekend';
      default:
        return 'upcoming';
    }
  }

  String? get _contribFilter => _filterIndex == 3 ? 'free' : null;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final displayName = authState is AuthAuthenticated
        ? authState.user.displayName.split(' ').first
        : '';
    final avatarUrl = authState is AuthAuthenticated ? authState.user.avatarUrl : null;

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
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TpAvatar(name: displayName, imageUrl: avatarUrl, size: 44),
                          const SizedBox(width: Sp.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bonjour 👋', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkSub)),
                                Text(displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.4)),
                              ],
                            ),
                          ),
                          _BellButton(),
                        ],
                      ),
                      const SizedBox(height: Sp.md),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.tpCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.tpHair),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: context.tpInkMute, size: 20),
                            const SizedBox(width: Sp.sm),
                            Text('Recherche un event…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                          ],
                        ),
                      ),
                      const SizedBox(height: Sp.md),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TpFilterChipRow(
                labels: _chips,
                activeIndex: _filterIndex,
                onChanged: (i) => setState(() => _filterIndex = i),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Sp.lg)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Près de toi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.4)),
                    Text('Voir tout', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Sp.sm)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: nearbyAsync.when(
                  loading: () => _HorizontalSkeleton(),
                  error: (_, _) => _ErrorHint(onRetry: () => ref.read(nearbyEventsFeedProvider.notifier).refresh()),
                  data: (events) {
                    final filtered = _applyFilter(events);
                    if (filtered.isEmpty) {
                      return Center(child: Text('Aucun event pour le moment 😔', style: TextStyle(color: context.tpInkSub, fontSize: 14, fontWeight: FontWeight.w600)));
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final event = filtered[i];
                        return Semantics(
                          button: true,
                          label: 'Voir ${event.title}',
                          child: GestureDetector(
                            onTap: () => context.push('/event/${event.id}'),
                            child: _EventCard(event: event),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Sp.lg)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🔥 Tendances', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.4)),
                    Text('Voir tout', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Sp.sm)),
            trendingAsync.when(
              loading: () => const SliverToBoxAdapter(child: _ListSkeleton()),
              error: (_, _) => SliverToBoxAdapter(
                child: _ErrorHint(onRetry: () => ref.read(trendingEventsFeedProvider.notifier).refresh()),
              ),
              data: (events) {
                final filtered = _applyFilter(events);
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final event = filtered[i];
                      return Semantics(
                        button: true,
                        label: 'Voir l\'événement tendance ${event.title}',
                        child: GestureDetector(
                          onTap: () => context.push('/event/${event.id}'),
                          child: _TrendRow(event: event, rank: i + 1),
                        ),
                      );
                    },
                    childCount: filtered.take(6).length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<EventModel> _applyFilter(List<EventModel> events) {
    var filtered = events;
    final now = DateTime.now();

    if (_dateFilter == 'tonight') {
      filtered = filtered.where((e) => e.startAt.year == now.year && e.startAt.month == now.month && e.startAt.day == now.day).toList();
    } else if (_dateFilter == 'weekend') {
      final daysToSat = (6 - now.weekday) % 7;
      final sat = now.add(Duration(days: daysToSat == 0 ? 7 : daysToSat));
      final sun = sat.add(const Duration(days: 1));
      filtered = filtered.where((e) =>
        (e.startAt.day == sat.day && e.startAt.month == sat.month) ||
        (e.startAt.day == sun.day && e.startAt.month == sun.month)).toList();
    }

    if (_contribFilter == 'free') {
      filtered = filtered.where((e) => e.contributionType == 'free').toList();
    }

    return filtered;
  }
}

// ── Event card (horizontal scroll) ───────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final startFormatted = DateFormat('EEE d MMM · HH\'h\'mm', 'fr_FR').format(event.startAt.toLocal());
    final contribLabel = switch (event.contributionType) {
      'nature' => '🎁 En nature',
      'money' => '💳 Payant',
      _ => '✨ Gratuit',
    };
    final categoryLabel = _categoryEmoji(event.category);

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: Sp.sm),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x141B1A2E), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  event.coverImageUrl != null
                      ? Image.network(event.coverImageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _GradientPlaceholder())
                      : _GradientPlaceholder(),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _OverlayPill(categoryLabel),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _OverlayPill(contribLabel),
                  ),
                  if (event.isFull)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45)),
                        child: const Center(
                          child: Text('COMPLET', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
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
                Text(event.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: context.tpInkSub),
                    const SizedBox(width: 4),
                    Expanded(child: Text(startFormatted, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: context.tpInkSub),
                    const SizedBox(width: 4),
                    Expanded(child: Text(event.city.isNotEmpty ? event.city : event.addressLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                if (event.maxParticipants != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: event.maxParticipants! > 0 ? event.participantsCount / event.maxParticipants! : 0,
                      backgroundColor: context.tpHair,
                      valueColor: const AlwaysStoppedAnimation(kPrimary),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trend row (vertical list) ─────────────────────────────────────────────────

class _TrendRow extends StatelessWidget {
  final EventModel event;
  final int rank;
  const _TrendRow({required this.event, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A1B1A2E), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: event.coverImageUrl != null
                      ? Image.network(event.coverImageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _GradientPlaceholder())
                      : _GradientPlaceholder(),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(7)),
                  alignment: Alignment.center,
                  child: Text('#$rank', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'par ${event.organizerName} · ${event.participantsCount} viennent',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tpInkSub),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: kPrimary, size: 22),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _GradientPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final String label;
  const _OverlayPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class _HorizontalSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md),
      itemCount: 3,
      itemBuilder: (_, _) => Container(
        width: 220,
        margin: const EdgeInsets.only(right: Sp.sm),
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 80,
          margin: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
          decoration: BoxDecoration(color: context.tpCard, borderRadius: BorderRadius.circular(16)),
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
          Text('Impossible de charger les events', style: TextStyle(fontSize: 13, color: context.tpInkSub)),
          TextButton(onPressed: onRetry, child: const Text('Réessayer', style: TextStyle(color: kPrimary))),
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.tpHair),
              ),
              child: Icon(Icons.notifications_outlined, color: context.tpInk, size: 22),
            ),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.tpBg, width: 1.5),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _categoryEmoji(String category) => switch (category) {
      'soiree' => '🎉 Soirée',
      'concert' => '🎵 Concert',
      'sport' => '⚽ Sport',
      'art' => '🎨 Art',
      'gastronomie' => '🍽 Gastro',
      'business' => '💼 Business',
      'plage' => '🏖 Plage',
      _ => '✨ Event',
    };
