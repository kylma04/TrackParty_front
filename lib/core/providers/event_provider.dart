import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

// ── Filtres du feed ───────────────────────────────────────────────────────────

class FeedFilters {
  final String? category;
  final String dateFilter;
  final bool freeOnly;
  final String sortBy;     // 'start_at' | '-participants_count' | 'distance'
  final double radiusKm;

  const FeedFilters({
    this.category,
    this.dateFilter = 'upcoming',
    this.freeOnly = false,
    this.sortBy = 'start_at',
    this.radiusKm = 25,
  });

  FeedFilters copyWith({
    Object? category = _sentinel,
    String? dateFilter,
    bool? freeOnly,
    String? sortBy,
    double? radiusKm,
  }) => FeedFilters(
        category: category == _sentinel ? this.category : category as String?,
        dateFilter: dateFilter ?? this.dateFilter,
        freeOnly: freeOnly ?? this.freeOnly,
        sortBy: sortBy ?? this.sortBy,
        radiusKm: radiusKm ?? this.radiusKm,
      );

  bool get hasActiveFilters =>
      category != null || freeOnly || dateFilter != 'upcoming' || sortBy != 'start_at' || radiusKm != 25;

  static const _sentinel = Object();
}

final feedFiltersProvider = StateProvider<FeedFilters>((ref) => const FeedFilters());

// ── Page paginée ──────────────────────────────────────────────────────────────

class FeedPage {
  final List<EventModel> items;
  final bool hasMore;
  final bool isLoadingMore;
  final int page;

  const FeedPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.page = 1,
  });

  FeedPage copyWith({
    List<EventModel>? items,
    bool? hasMore,
    bool? isLoadingMore,
    int? page,
  }) => FeedPage(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        page: page ?? this.page,
      );
}

// ── Localisation utilisateur ──────────────────────────────────────────────────

final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  } catch (_) {
    return null;
  }
});

// ── Feed "Près de toi" ────────────────────────────────────────────────────────

final nearbyEventsFeedProvider =
    AsyncNotifierProvider<NearbyFeedNotifier, FeedPage>(
  NearbyFeedNotifier.new,
);

class NearbyFeedNotifier extends AsyncNotifier<FeedPage> {
  @override
  Future<FeedPage> build() async {
    final loc     = await ref.watch(userLocationProvider.future);
    final filters = ref.watch(feedFiltersProvider);
    return _fetchPage(loc, filters, page: 1);
  }

  Future<FeedPage> _fetchPage(Position? loc, FeedFilters filters, {required int page}) async {
    final service = ref.read(eventServiceProvider);
    final result  = await service.getFeed(
      filter: filters.dateFilter,
      category: filters.category,
      contribution: filters.freeOnly ? 'free' : null,
      lat: loc?.latitude,
      lng: loc?.longitude,
      radius: filters.radiusKm,
      ordering: filters.sortBy == 'distance' && loc != null ? 'distance' : filters.sortBy,
      page: page,
    );
    return FeedPage(
      items: result.results,
      hasMore: result.next != null,
      page: page,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final loc     = await ref.read(userLocationProvider.future);
    final filters = ref.read(feedFiltersProvider);
    state = await AsyncValue.guard(() => _fetchPage(loc, filters, page: 1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final loc      = await ref.read(userLocationProvider.future);
      final filters  = ref.read(feedFiltersProvider);
      final nextPage = current.page + 1;
      final result   = await ref.read(eventServiceProvider).getFeed(
        filter: filters.dateFilter,
        category: filters.category,
        contribution: filters.freeOnly ? 'free' : null,
        lat: loc?.latitude,
        lng: loc?.longitude,
        radius: filters.radiusKm,
        ordering: filters.sortBy == 'distance' && loc != null ? 'distance' : filters.sortBy,
        page: nextPage,
      );
      state = AsyncValue.data(FeedPage(
        items: [...current.items, ...result.results],
        hasMore: result.next != null,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

// ── Feed "Tendances" ──────────────────────────────────────────────────────────

final trendingEventsFeedProvider =
    AsyncNotifierProvider<FeedNotifier, FeedPage>(
  FeedNotifier.new,
);

class FeedNotifier extends AsyncNotifier<FeedPage> {
  @override
  Future<FeedPage> build() async {
    final filters = ref.watch(feedFiltersProvider);
    return _fetchPage(filters, page: 1);
  }

  Future<FeedPage> _fetchPage(FeedFilters filters, {required int page}) async {
    final service = ref.read(eventServiceProvider);
    final result  = await service.getFeed(
      filter: filters.dateFilter,
      category: filters.category,
      contribution: filters.freeOnly ? 'free' : null,
      ordering: filters.sortBy,
      page: page,
    );
    return FeedPage(
      items: result.results,
      hasMore: result.next != null,
      page: page,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final filters = ref.read(feedFiltersProvider);
    state = await AsyncValue.guard(() => _fetchPage(filters, page: 1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final filters  = ref.read(feedFiltersProvider);
      final nextPage = current.page + 1;
      final result   = await ref.read(eventServiceProvider).getFeed(
        filter: filters.dateFilter,
        category: filters.category,
        contribution: filters.freeOnly ? 'free' : null,
        ordering: filters.sortBy,
        page: nextPage,
      );
      state = AsyncValue.data(FeedPage(
        items: [...current.items, ...result.results],
        hasMore: result.next != null,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

// ── Event detail provider ─────────────────────────────────────────────────────

final eventDetailProvider =
    AsyncNotifierProviderFamily<EventDetailNotifier, EventModel, String>(
  EventDetailNotifier.new,
);

class EventDetailNotifier extends FamilyAsyncNotifier<EventModel, String> {
  @override
  Future<EventModel> build(String id) =>
      ref.read(eventServiceProvider).getEvent(id);

  Future<void> participate({String? contributionItemId, int quantity = 1}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final willWaitlist = current.isFull;
    state = AsyncValue.data(current.copyWith(
      isParticipating: !willWaitlist,
      isWaitlisted: willWaitlist,
      participantsCount: willWaitlist ? current.participantsCount : current.participantsCount + 1,
    ));

    try {
      await ref.read(eventServiceProvider).participate(
        arg,
        contributionItemId: contributionItemId,
        quantity: quantity,
      );
      state = await AsyncValue.guard(() => ref.read(eventServiceProvider).getEvent(arg));
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancelParticipation() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final wasConfirmed = current.isParticipating;
    state = AsyncValue.data(current.copyWith(
      isParticipating: false,
      isWaitlisted: false,
      participantsCount: wasConfirmed ? current.participantsCount - 1 : current.participantsCount,
      userParticipation: null,
    ));

    try {
      await ref.read(eventServiceProvider).cancelParticipation(arg);
      state = await AsyncValue.guard(() => ref.read(eventServiceProvider).getEvent(arg));
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(eventServiceProvider).getEvent(arg),
    );
  }
}

// ── Stats événements de l'utilisateur ────────────────────────────────────────

final myEventStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.read(eventServiceProvider);
  return service.getMyEventStats();
});

// ── Dashboard statistiques d'un événement (organisateur) ─────────────────────

final eventStatsProvider =
    FutureProvider.autoDispose.family<EventStats, String>((ref, eventId) {
  return ref.read(eventServiceProvider).getEventStats(eventId);
});

// ── Favoris ───────────────────────────────────────────────────────────────────

final savedEventsProvider = AsyncNotifierProvider<SavedEventsNotifier, List<EventModel>>(
  SavedEventsNotifier.new,
);

class SavedEventsNotifier extends AsyncNotifier<List<EventModel>> {
  @override
  Future<List<EventModel>> build() =>
      ref.read(eventServiceProvider).getSavedEvents();

  Future<void> toggleSave(String eventId, {required bool currentlySaved}) async {
    final svc = ref.read(eventServiceProvider);
    if (currentlySaved) {
      await svc.unsaveEvent(eventId);
    } else {
      await svc.saveEvent(eventId);
    }
    state = await AsyncValue.guard(() => svc.getSavedEvents());
  }
}

// ── Waitlist d'un événement ───────────────────────────────────────────────────

final eventWaitlistProvider = FutureProvider.autoDispose
    .family<List<ParticipantModel>, String>((ref, eventId) {
  return ref.read(eventServiceProvider).getWaitlist(eventId);
});
