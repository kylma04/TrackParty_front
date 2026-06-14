import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

// ── Page paginée ──────────────────────────────────────────────────────────────

class NotifPage {
  final List<NotificationModel> items;
  final bool hasMore;
  final bool isLoadingMore;
  final int page;

  const NotifPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.page = 1,
  });

  NotifPage copyWith({
    List<NotificationModel>? items,
    bool? hasMore,
    bool? isLoadingMore,
    int? page,
  }) =>
      NotifPage(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        page: page ?? this.page,
      );
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotifPage>(
        NotificationsNotifier.new);

class NotificationsNotifier extends AsyncNotifier<NotifPage> {
  @override
  Future<NotifPage> build() => _fetch(page: 1);

  Future<NotifPage> _fetch({required int page}) async {
    final res = await ref.read(notificationServiceProvider).getNotifications(page: page);
    return NotifPage(items: res.results, hasMore: res.hasMore, page: page);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(page: 1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final nextPage = current.page + 1;
      final res = await ref.read(notificationServiceProvider).getNotifications(page: nextPage);
      state = AsyncData(NotifPage(
        items: [...current.items, ...res.results],
        hasMore: res.hasMore,
        page: nextPage,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> markAllRead() async {
    await ref.read(notificationServiceProvider).markAllRead();
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: current.items.map((n) => n.copyWith(isRead: true)).toList(),
    ));
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationServiceProvider).markRead(id);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: current.items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
    ));
  }

  /// Supprime une notification (mise à jour optimiste avec rollback en cas d'échec).
  Future<void> deleteOne(String id) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
        items: current.items.where((n) => n.id != id).toList(),
      ));
    }
    try {
      await ref.read(notificationServiceProvider).deleteNotification(id);
    } catch (e) {
      if (current != null) state = AsyncData(current);
      rethrow;
    }
  }

  /// Supprime toutes les notifications (mise à jour optimiste avec rollback).
  Future<void> clearAll() async {
    final current = state.valueOrNull;
    state = const AsyncData(NotifPage(items: [], hasMore: false, page: 1));
    try {
      await ref.read(notificationServiceProvider).clearAll();
    } catch (e) {
      if (current != null) state = AsyncData(current);
      rethrow;
    }
  }
}

// Expose le nombre de non-lus pour le badge de tab
final unreadNotifCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider).valueOrNull?.items ?? [];
  return notifs.where((n) => !n.isRead).length;
});
