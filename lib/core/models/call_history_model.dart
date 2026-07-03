/// Entrée d'historique d'appel — reflète la réponse de
/// `GET /api/chat/calls/history/` (voir CallHistoryView côté backend).
class CallHistoryEntry {
  final String id;
  final String callType;   // 'audio' | 'video'
  final String status;     // ringing / accepted / rejected / missed / ended
  final String direction;  // 'incoming' | 'outgoing'
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String roomId;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatarUrl;

  const CallHistoryEntry({
    required this.id,
    required this.callType,
    required this.status,
    required this.direction,
    required this.startedAt,
    required this.roomId,
    this.endedAt,
    this.durationSeconds,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatarUrl,
  });

  bool get isIncoming => direction == 'incoming';
  bool get isVideo    => callType == 'video';
  /// Appel réellement manqué = entrant et non décroché.
  bool get isMissed   => status == 'missed' && isIncoming;

  factory CallHistoryEntry.fromJson(Map<String, dynamic> j) {
    final other = j['other_user'] as Map<String, dynamic>?;
    return CallHistoryEntry(
      id:              j['id'] as String,
      callType:        (j['call_type'] as String?) ?? 'audio',
      status:          (j['status'] as String?) ?? 'ended',
      direction:       (j['direction'] as String?) ?? 'outgoing',
      startedAt:       DateTime.parse(j['started_at'] as String).toLocal(),
      endedAt:         j['ended_at'] != null
          ? DateTime.parse(j['ended_at'] as String).toLocal()
          : null,
      durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
      roomId:          j['room_id'] as String,
      otherUserId:         other?['id'] as String?,
      otherUserName:       other?['name'] as String?,
      otherUserAvatarUrl:  (other?['avatar_url'] as String?)?.isNotEmpty == true
          ? other!['avatar_url'] as String
          : null,
    );
  }
}
