/// Un autre participant d'un appel de l'historique (DM ou groupe).
class CallHistoryParticipant {
  final String id;
  final String name;
  final String? avatarUrl;

  const CallHistoryParticipant({required this.id, required this.name, this.avatarUrl});

  factory CallHistoryParticipant.fromJson(Map<String, dynamic> j) => CallHistoryParticipant(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarUrl: (j['avatar_url'] as String?)?.isNotEmpty == true
            ? j['avatar_url'] as String
            : null,
      );
}

/// Entrée d'historique d'appel — reflète la réponse de
/// `GET /api/chat/calls/history/` (voir CallHistoryView côté backend).
class CallHistoryEntry {
  final String id;
  final String callType;   // 'audio' | 'video'
  final String status;     // ringing / active / ended (état global de l'appel)
  final String myStatus;   // ringing / joined / declined / missed / left (mon statut)
  final bool isGroup;
  final String direction;  // 'incoming' | 'outgoing'
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String roomId;
  final List<CallHistoryParticipant> participants;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatarUrl;

  const CallHistoryEntry({
    required this.id,
    required this.callType,
    required this.status,
    required this.myStatus,
    required this.isGroup,
    required this.direction,
    required this.startedAt,
    required this.roomId,
    this.endedAt,
    this.durationSeconds,
    this.participants = const [],
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatarUrl,
  });

  bool get isIncoming => direction == 'incoming';
  bool get isVideo    => callType == 'video';
  /// Appel réellement manqué = entrant et jamais décroché.
  bool get isMissed   => myStatus == 'missed' && isIncoming;
  bool get isDeclined => myStatus == 'declined';

  /// Nom(s) à afficher : le seul autre participant (DM), ou la liste des
  /// prénoms pour un appel de groupe.
  String get displayName {
    if (participants.isEmpty) return otherUserName ?? 'Inconnu';
    if (participants.length == 1) return participants.first.name;
    return participants.map((p) => p.name).join(', ');
  }

  factory CallHistoryEntry.fromJson(Map<String, dynamic> j) {
    final other = j['other_user'] as Map<String, dynamic>?;
    final participantsJson = j['participants'] as List<dynamic>? ?? const [];
    return CallHistoryEntry(
      id:              j['id'] as String,
      callType:        (j['call_type'] as String?) ?? 'audio',
      status:          (j['status'] as String?) ?? 'ended',
      myStatus:        (j['my_status'] as String?) ?? 'left',
      isGroup:         j['is_group'] as bool? ?? false,
      direction:       (j['direction'] as String?) ?? 'outgoing',
      startedAt:       DateTime.parse(j['started_at'] as String).toLocal(),
      endedAt:         j['ended_at'] != null
          ? DateTime.parse(j['ended_at'] as String).toLocal()
          : null,
      durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
      roomId:          j['room_id'] as String,
      participants: participantsJson
          .map((e) => CallHistoryParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      otherUserId:         other?['id'] as String?,
      otherUserName:       other?['name'] as String?,
      otherUserAvatarUrl:  (other?['avatar_url'] as String?)?.isNotEmpty == true
          ? other!['avatar_url'] as String
          : null,
    );
  }
}
