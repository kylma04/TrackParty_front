import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/event_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/event_cards.dart';
import '../../widgets/feed_filter_sheet.dart';

/// « Explorer tout » : tous les événements en grille, défilement vertical sans fin
/// (20 par 20) + bouton de filtres.
class AllEventsScreen extends ConsumerWidget {
  const AllEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(feedFiltersProvider);
    final async = ref.watch(allEventsFeedProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.sm, Sp.md, Sp.sm),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/feed'),
                    icon: Icon(PhosphorIcons.arrowLeft(), color: context.tpInk),
                  ),
                  Expanded(
                    child: Text(
                      'Tous les événements',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.tpInk,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  _FilterButton(
                    active: filters.hasActiveFilters,
                    onTap: () => showFeedFilterSheet(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: kPrimary,
                onRefresh: () =>
                    ref.read(allEventsFeedProvider.notifier).refresh(),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kPrimary,
                    ),
                  ),
                  error: (_, _) => _Message(
                    icon: PhosphorIcons.wifiSlash(),
                    text: 'Impossible de charger les événements',
                    actionLabel: 'Réessayer',
                    onAction: () =>
                        ref.read(allEventsFeedProvider.notifier).refresh(),
                  ),
                  data: (page) {
                    if (page.items.isEmpty) {
                      return _Message(
                        icon: PhosphorIcons.magnifyingGlass(),
                        text: filters.hasActiveFilters
                            ? 'Aucun événement ne correspond à ces filtres'
                            : 'Aucun événement pour le moment',
                      );
                    }
                    final items = page.items;
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            Sp.md,
                            Sp.xs,
                            Sp.md,
                            0,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: Sp.sm + 4,
                                  crossAxisSpacing: Sp.sm + 4,
                                  childAspectRatio: 0.66,
                                ),
                            delegate: SliverChildBuilderDelegate((context, i) {
                              // Dernier événement affiché → on charge les 20 suivants.
                              if (i == items.length - 1 && page.hasMore) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  ref
                                      .read(allEventsFeedProvider.notifier)
                                      .loadMore();
                                });
                              }
                              return EventGridCard(event: items[i]);
                            }, childCount: items.length),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Sp.lg,
                            ),
                            child: Center(
                              child: page.isLoadingMore
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: kPrimary,
                                      ),
                                    )
                                  : !page.hasMore
                                  ? Text(
                                      'Tu as tout vu',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: context.tpInkMute,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 90)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: active ? 'Filtres (actifs)' : 'Filtres',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? kPrimary.withValues(alpha: 0.12) : context.tpCard,
            borderRadius: BorderRadius.circular(Radii.button),
            border: Border.all(color: active ? kPrimary : context.tpHair),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.slidersHorizontal(),
                size: 18,
                color: active ? kPrimary : context.tpInk,
              ),
              const SizedBox(width: 6),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active ? kPrimary : context.tpInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // ListView pour que le pull-to-refresh fonctionne aussi sur l'écran vide.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 44, color: context.tpInkMute),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.tpInk,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ),
        ],
      ],
    );
  }
}
