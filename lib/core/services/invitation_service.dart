import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/chat_model.dart';

final invitationServiceProvider = Provider<InvitationService>((ref) {
  return InvitationService(ref.read(dioProvider));
});

class InvitationService {
  final Dio _dio;
  InvitationService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Liste des invitations.
  /// [direction] : 'received' (défaut) ou 'sent'
  /// [status]    : null = défaut backend, 'pending', 'accepted', 'refused'
  Future<List<InvitationModel>> getInvitations({
    String direction = 'received',
    String? status,
  }) =>
      _call(() async {
        final params = <String, dynamic>{'direction': direction};
        if (status != null) params['status'] = status;
        final res  = await _dio.get('chat/invitations/', queryParameters: params);
        final data = res.data;
        // Gère les réponses paginées {"results":[...]} ET les listes brutes [...]
        final list = data is Map ? (data['results'] as List<dynamic>) : (data as List<dynamic>);
        return list
            .map((e) => InvitationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Envoie une invitation.
  /// Sans [eventId] → invitation de type DM (demande de contact).
  Future<InvitationModel> sendInvitation({
    required String receiverId,
    String? eventId,
  }) =>
      _call(() async {
        final data = <String, dynamic>{
          'receiver_id':      receiverId,
          'invitation_type':  eventId != null ? 'event' : 'dm',
        };
        if (eventId != null) data['event_id'] = eventId;
        final res = await _dio.post('chat/invitations/', data: data);
        return InvitationModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<InvitationModel> respondToInvitation(
    String invitationId,
    String action, { // 'accept' | 'refuse'
    String? contributionItemId,
    int quantity = 1,
  }) =>
      _call(() async {
        final body = <String, dynamic>{'action': action};
        if (action == 'accept' && contributionItemId != null) {
          body['contribution_item_id'] = contributionItemId;
          body['quantity'] = quantity;
        }
        final res = await _dio.patch(
          'chat/invitations/$invitationId/respond/',
          data: body,
        );
        return InvitationModel.fromJson(res.data as Map<String, dynamic>);
      });

  /// Invite PLUSIEURS personnes à un événement privé (organisateur/co-org).
  /// Au-delà du plafond gratuit, le reste est ignoré et `upgradeRequired` = true.
  Future<BulkInviteResult> bulkInviteToEvent({
    required String eventId,
    required List<String> userIds,
  }) =>
      _call(() async {
        final res = await _dio.post(
          'events/$eventId/invite/',
          data: {'user_ids': userIds},
        );
        final d = res.data as Map<String, dynamic>;
        return BulkInviteResult(
          invitedCount: d['invited_count'] as int? ?? 0,
          skippedCount: (d['skipped'] as List<dynamic>?)?.length ?? 0,
          cap: d['cap'] as int?,
          remaining: d['remaining'] as int?,
          upgradeRequired: d['upgrade_required'] as bool? ?? false,
        );
      });

  /// Candidats à inviter depuis une source déjà constituée.
  /// [source] : 'followers' | 'community' | 'participants'.
  Future<List<InviteCandidate>> getInviteCandidates({
    required String eventId,
    required String source,
    String? q,
  }) =>
      _call(() async {
        final res = await _dio.get(
          'events/$eventId/invite-candidates/',
          queryParameters: {'source': source, if (q != null && q.isNotEmpty) 'q': q},
        );
        final list = (res.data['candidates'] as List<dynamic>? ?? []);
        return list
            .map((e) => InviteCandidate.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Récupère le lien d'invitation courant (null si aucun).
  Future<EventInviteLink?> getInviteLink(String eventId) async {
    try {
      final res = await _dio.get('events/$eventId/invite-link/');
      return EventInviteLink.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioException(e);
    }
  }

  /// Crée ou régénère/réactive le lien d'invitation.
  Future<EventInviteLink> createInviteLink(String eventId, {bool regenerate = false}) =>
      _call(() async {
        final res = await _dio.post(
          'events/$eventId/invite-link/',
          data: {if (regenerate) 'regenerate': true},
        );
        return EventInviteLink.fromJson(res.data as Map<String, dynamic>);
      });

  /// Désactive le lien d'invitation.
  Future<void> deactivateInviteLink(String eventId) =>
      _call(() async => _dio.delete('events/$eventId/invite-link/'));

  /// Rejoint un event privé via un code d'invitation. Renvoie (accès, requiresPurchase).
  Future<({bool access, bool requiresPurchase})> joinByLink(
          String eventId, String code) =>
      _call(() async {
        final res = await _dio.post(
          'events/$eventId/join-by-link/',
          data: {'code': code},
        );
        final d = res.data as Map<String, dynamic>;
        return (
          access: d['access'] as bool? ?? false,
          requiresPurchase: d['requires_purchase'] as bool? ?? false,
        );
      });

  Future<List<UserSearchResult>> searchUsers(String query) =>
      _call(() async {
        if (query.trim().length < 2) return [];
        final res = await _dio.get(
          'auth/users/search/',
          queryParameters: {'q': query.trim()},
        );
        final list = res.data as List<dynamic>;
        return list
            .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      });
}

/// Candidat à inviter (issu d'une source : abonnés / communauté / participants).
class InviteCandidate {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isPromoter;
  final String status; // invitable | invited | participant | has_access | opted_out

  const InviteCandidate({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isPromoter = false,
    required this.status,
  });

  bool get isInvitable => status == 'invitable';

  /// Libellé d'un statut non-invitable (null si invitable).
  String? get statusLabel => switch (status) {
        'invited' => 'Déjà invité',
        'participant' => 'Participe déjà',
        'has_access' => 'A déjà accès',
        'opted_out' => 'N\'accepte pas',
        _ => null,
      };

  factory InviteCandidate.fromJson(Map<String, dynamic> j) => InviteCandidate(
        id: j['id'] as String,
        displayName: j['display_name'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String?,
        isPromoter: j['is_promoter'] as bool? ?? false,
        status: j['status'] as String? ?? 'invitable',
      );
}

/// Lien / code d'invitation partageable d'un événement privé.
class EventInviteLink {
  final String code;
  final bool isActive;
  final int usesCount;
  final String webUrl;
  final String deepLink;

  const EventInviteLink({
    required this.code,
    required this.isActive,
    required this.usesCount,
    required this.webUrl,
    required this.deepLink,
  });

  factory EventInviteLink.fromJson(Map<String, dynamic> j) => EventInviteLink(
        code: j['code'] as String,
        isActive: j['is_active'] as bool? ?? true,
        usesCount: j['uses_count'] as int? ?? 0,
        webUrl: j['web_url'] as String? ?? '',
        deepLink: j['deep_link'] as String? ?? '',
      );
}

/// Récap d'un envoi d'invitations en masse à un événement.
class BulkInviteResult {
  final int invitedCount;
  final int skippedCount;
  final int? cap;        // null = illimité (Pro)
  final int? remaining;  // places d'invitation restantes (null = illimité)
  final bool upgradeRequired; // plafond gratuit atteint → passer au Pro

  const BulkInviteResult({
    required this.invitedCount,
    required this.skippedCount,
    this.cap,
    this.remaining,
    required this.upgradeRequired,
  });
}
