import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

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

// ── Feed providers ────────────────────────────────────────────────────────────

final nearbyEventsFeedProvider =
    AsyncNotifierProvider<NearbyFeedNotifier, List<EventModel>>(
  NearbyFeedNotifier.new,
);

class NearbyFeedNotifier extends AsyncNotifier<List<EventModel>> {
  @override
  Future<List<EventModel>> build() async {
    final loc = await ref.watch(userLocationProvider.future);
    return _fetch(loc);
  }

  Future<List<EventModel>> _fetch(Position? loc) async {
    final service = ref.read(eventServiceProvider);
    final page = await service.getFeed(
      filter: 'upcoming',
      lat: loc?.latitude,
      lng: loc?.longitude,
      radius: 25,
      ordering: 'start_at',
    );
    return page.results;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final loc = await ref.read(userLocationProvider.future);
    state = await AsyncValue.guard(() => _fetch(loc));
  }
}

final trendingEventsFeedProvider =
    AsyncNotifierProvider<FeedNotifier, List<EventModel>>(
  () => FeedNotifier(filter: 'upcoming', ordering: '-participants_count'),
);

class FeedNotifier extends AsyncNotifier<List<EventModel>> {
  final String? filter;
  final String? category;
  final String ordering;

  FeedNotifier({this.filter, this.category, this.ordering = 'start_at'});

  @override
  Future<List<EventModel>> build() => _fetch();

  Future<List<EventModel>> _fetch() async {
    final service = ref.read(eventServiceProvider);
    final page = await service.getFeed(
      filter: filter,
      category: category,
      ordering: ordering,
    );
    return page.results;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
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

    // Optimistic update
    state = AsyncValue.data(current.copyWith(
      isParticipating: true,
      participantsCount: current.participantsCount + 1,
    ));

    try {
      await ref.read(eventServiceProvider).participate(
        arg,
        contributionItemId: contributionItemId,
        quantity: quantity,
      );
      // Reload to get fresh userParticipation data
      state = await AsyncValue.guard(() => ref.read(eventServiceProvider).getEvent(arg));
    } catch (e, st) {
      // Rollback
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancelParticipation() async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(current.copyWith(
      isParticipating: false,
      participantsCount: current.participantsCount - 1,
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
