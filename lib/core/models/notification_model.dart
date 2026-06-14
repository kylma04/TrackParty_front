class NotificationModel {
  final String id;
  final String notificationType;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      notificationType: json['notification_type'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id,
    notificationType: notificationType,
    title: title,
    body: body,
    payload: payload,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  String get icon {
    switch (notificationType) {
      case 'new_message':         return '💬';
      case 'invitation':          return '🎉';
      case 'invitation_accepted': return '✅';
      case 'event_reminder':      return '⏰';
      case 'event_updated':       return '📝';
      case 'event_cancelled':     return '🚫';
      case 'new_follower':        return '✨';
      case 'new_review':          return '⭐';
      case 'participation_confirmed': return '✅';
      default:                    return '🔔';
    }
  }

  // 'events' | 'messages' | 'social'
  String get category {
    switch (notificationType) {
      case 'event_reminder':
      case 'event_updated':
      case 'event_cancelled':
      case 'participation_confirmed':
        return 'events';
      case 'new_message':
        return 'messages';
      default:
        return 'social';
    }
  }

  bool get isInvitation => notificationType == 'invitation';
  bool get isReviewRequest =>
      notificationType == 'review_request' || notificationType == 'checkin_review';
  String? get invitationId => payload['invitation_id'] as String?;
  String? get eventId => payload['event_id'] as String?;
  String? get roomId => payload['room_id'] as String?;
}
