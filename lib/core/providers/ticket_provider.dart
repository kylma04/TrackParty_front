import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ticket_model.dart';
import '../services/ticket_service.dart';

final myTicketProvider = FutureProvider.autoDispose.family<TicketModel, String>(
  (ref, eventId) => ref.read(ticketServiceProvider).getMyTicket(eventId),
);

final myTicketsProvider = FutureProvider.autoDispose<List<TicketModel>>(
  (ref) => ref.read(ticketServiceProvider).getMyTickets(),
);

final eventCheckinsProvider = FutureProvider.autoDispose.family<List<TicketModel>, String>(
  (ref, eventId) => ref.read(ticketServiceProvider).getCheckins(eventId),
);

final eventStaffProvider = AsyncNotifierProvider.autoDispose
    .family<EventStaffNotifier, List<EventStaffModel>, String>(
  EventStaffNotifier.new,
);

class EventStaffNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<EventStaffModel>, String> {
  @override
  Future<List<EventStaffModel>> build(String arg) =>
      ref.read(ticketServiceProvider).getStaff(arg);

  Future<void> add(String userId) async {
    final member = await ref.read(ticketServiceProvider).addStaff(arg, userId);
    state = AsyncData([...state.valueOrNull ?? [], member]);
  }

  Future<void> remove(String userId) async {
    await ref.read(ticketServiceProvider).removeStaff(arg, userId);
    state = AsyncData(
      (state.valueOrNull ?? []).where((s) => s.userId != userId).toList(),
    );
  }
}
