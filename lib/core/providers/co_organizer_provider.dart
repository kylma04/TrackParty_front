import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/co_organizer_service.dart';

// Invitations co-organisateur en attente pour l'utilisateur connecté
final coOrganizerInvitationsProvider =
    AsyncNotifierProvider<CoOrganizerInvitationsNotifier, List<CoOrganizerInvitationModel>>(
  CoOrganizerInvitationsNotifier.new,
);

class CoOrganizerInvitationsNotifier
    extends AsyncNotifier<List<CoOrganizerInvitationModel>> {
  @override
  Future<List<CoOrganizerInvitationModel>> build() =>
      ref.read(coOrganizerServiceProvider).myInvitations();

  Future<void> respond(String invitationId, {required bool accept}) async {
    await ref
        .read(coOrganizerServiceProvider)
        .respond(invitationId, accept: accept);
    state = await AsyncValue.guard(
        () => ref.read(coOrganizerServiceProvider).myInvitations());
  }
}
