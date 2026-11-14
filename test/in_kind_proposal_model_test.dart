import 'package:flutter_test/flutter_test.dart';
import 'package:trackparty/core/models/event_model.dart';
import 'package:trackparty/core/models/notification_model.dart';

void main() {
  group('InKindProposalModel & EventModel contract', () {
    final baseEventJson = <String, dynamic>{
      'id': 'evt-1',
      'title': 'Soirée Test',
      'description': 'Test description',
      'category': 'soiree',
      'start_at': '2026-12-01T20:00:00Z',
      'address_label': 'Cocody',
      'city': 'Abidjan',
      'quartier': 'Riviera',
      'visibility': 'public',
      'status': 'published',
      'contribution_type': 'monetaire',
      'contribution_amount': 5000,
      'participants_count': 3,
      'organizer_id': 'org-1',
      'organizer_name': 'Promo',
      'organizer_is_promoter': true,
      'is_past': false,
      'is_full': false,
      'is_participating': false,
      'allow_in_kind_proposals': true,
      'user_participation': {
        'id': 'part-1',
        'status': 'confirmed',
        'contribution_item_id': null,
        'is_in_kind': true,
      },
      'my_in_kind_proposal': {
        'id': 'prop-1',
        'event_id': 'evt-1',
        'event_title': 'Soirée Test',
        'user_id': 'user-1',
        'user_name': 'Koffi',
        'title': '2 packs de jus',
        'description': 'Bien frais',
        'emoji': '🧃',
        'status': 'pending',
        'ticket_category_id': null,
        'ticket_category_name': null,
        'ticket_category_color': null,
        'rejection_reason': '',
        'reviewed_by_name': null,
        'reviewed_at': null,
        'created_at': '2026-11-14T10:00:00Z',
        'updated_at': '2026-11-14T10:00:00Z',
      },
    };

    test('parses EventModel allowInKindProposals, myInKindProposal, and copyWith', () {
      final event = EventModel.fromJson(baseEventJson);
      expect(event.allowInKindProposals, isTrue);
      expect(event.userParticipation?.isInKind, isTrue);
      expect(event.myInKindProposal, isNotNull);
      expect(event.myInKindProposal!.isPending, isTrue);
      expect(event.myInKindProposal!.emoji, '🧃');

      final cleared = event.copyWith(clearMyInKindProposal: true);
      expect(cleared.myInKindProposal, isNull);
      expect(cleared.allowInKindProposals, isTrue);
    });

    test('parses accepted and rejected InKindProposalModel states', () {
      final accepted = InKindProposalModel.fromJson({
        ...baseEventJson['my_in_kind_proposal'] as Map<String, dynamic>,
        'status': 'accepted',
        'ticket_category_id': 'cat-vip',
        'ticket_category_name': 'VIP',
        'ticket_category_color': '#FF4B26',
        'reviewed_by_name': 'Promo',
        'reviewed_at': '2026-11-14T11:00:00Z',
      });
      expect(accepted.isAccepted, isTrue);
      expect(accepted.ticketCategoryName, 'VIP');

      final rejected = InKindProposalModel.fromJson({
        ...baseEventJson['my_in_kind_proposal'] as Map<String, dynamic>,
        'status': 'rejected',
        'rejection_reason': 'Stock suffisant',
      });
      expect(rejected.isRejected, isTrue);
      expect(rejected.rejectionReason, 'Stock suffisant');
    });

    test('parses ParticipantModel and EventStats in-kind metadata', () {
      final participant = ParticipantModel.fromJson({
        'id': 'p1',
        'status': 'confirmed',
        'registered_at': '2026-11-14T12:00:00Z',
        'user_id': 'u1',
        'user_name': 'Aya',
        'contribution_item_id': null,
        'contribution_item_name': 'DJ set 1h',
        'contribution_item_emoji': '🎵',
        'is_in_kind': true,
        'in_kind_source': 'proposal',
        'quantity': 1,
      });
      expect(participant.isInKind, isTrue);
      expect(participant.inKindSource, 'proposal');
      expect(participant.contributionItemName, 'DJ set 1h');

      final stats = EventStats.fromJson({
        'participants_count': 4,
        'max_participants': 50,
        'checkins_count': 1,
        'waitlist_count': 0,
        'staff_count': 2,
        'co_organizers_count': 1,
        'avg_rating': 4.8,
        'reviews_count': 5,
        'contribution_type': 'monetaire',
        'contribution_amount': 5000,
        'status': 'published',
        'title': 'Soirée Test',
        'pending_in_kind_proposals_count': 3,
      });
      expect(stats.pendingInKindProposalsCount, 3);
    });

    test('parses in-kind NotificationModel types into events category', () {
      for (final type in [
        'in_kind_proposal',
        'in_kind_accepted',
        'in_kind_rejected',
      ]) {
        final n = NotificationModel.fromJson({
          'id': 'n-$type',
          'notification_type': type,
          'title': 'Titre',
          'body': 'Corps',
          'payload': {'event_id': 'evt-1', 'proposal_id': 'prop-1'},
          'is_read': false,
          'created_at': '2026-11-14T12:00:00Z',
          'action_status': type == 'in_kind_proposal' ? 'pending' : null,
        });
        expect(n.category, 'events');
        expect(n.eventId, 'evt-1');
        expect(n.isInKindProposal, type == 'in_kind_proposal');
      }
    });
  });
}
