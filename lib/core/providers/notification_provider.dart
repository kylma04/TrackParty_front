import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
        NotificationsNotifier.new);

class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() =>
      ref.read(notificationServiceProvider).getNotifications();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(notificationServiceProvider).getNotifications());
  }

  Future<void> markAllRead() async {
    await ref.read(notificationServiceProvider).markAllRead();
    state = AsyncData(
      (state.valueOrNull ?? []).map((n) => n.copyWith(isRead: true)).toList(),
    );
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationServiceProvider).markRead(id);
    state = AsyncData(
      (state.valueOrNull ?? []).map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
    );
  }
}

// Expose le nombre de non-lus pour le badge de tab
final unreadNotifCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider).valueOrNull ?? [];
  return notifs.where((n) => !n.isRead).length;
});
