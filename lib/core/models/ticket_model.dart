class TicketModel {
  final String id;
  final String token;
  final bool isValid;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final String eventId;
  final String eventTitle;
  final String? eventCover;
  final DateTime eventStart;
  final String eventCity;
  final String holderName;
  final DateTime createdAt;

  const TicketModel({
    required this.id,
    required this.token,
    required this.isValid,
    required this.checkedIn,
    this.checkedInAt,
    required this.eventId,
    required this.eventTitle,
    this.eventCover,
    required this.eventStart,
    required this.eventCity,
    required this.holderName,
    required this.createdAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> j) => TicketModel(
        id: j['id'] as String,
        token: j['token'] as String,
        isValid: j['is_valid'] as bool,
        checkedIn: j['checked_in'] as bool,
        checkedInAt: j['checked_in_at'] != null
            ? DateTime.parse(j['checked_in_at'] as String)
            : null,
        eventId: j['event_id'] as String,
        eventTitle: j['event_title'] as String,
        eventCover: j['event_cover'] as String?,
        eventStart: DateTime.parse(j['event_start'] as String),
        eventCity: (j['event_city'] as String?) ?? '',
        holderName: j['holder_name'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class CheckinResult {
  final bool valid;
  final String holderName;
  final String eventTitle;
  final bool alreadyChecked;
  final DateTime? checkedInAt;
  final String message;

  const CheckinResult({
    required this.valid,
    required this.holderName,
    required this.eventTitle,
    required this.alreadyChecked,
    this.checkedInAt,
    required this.message,
  });

  factory CheckinResult.fromJson(Map<String, dynamic> j) => CheckinResult(
        valid: j['valid'] as bool,
        holderName: (j['holder_name'] as String?) ?? '',
        eventTitle: (j['event_title'] as String?) ?? '',
        alreadyChecked: j['already_checked'] as bool,
        checkedInAt: j['checked_in_at'] != null
            ? DateTime.parse(j['checked_in_at'] as String)
            : null,
        message: (j['message'] as String?) ?? '',
      );
}

class EventStaffModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final DateTime addedAt;

  const EventStaffModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.addedAt,
  });

  factory EventStaffModel.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>;
    return EventStaffModel(
      id: j['id'] as String,
      userId: user['id'] as String,
      userName: user['display_name'] as String,
      userAvatarUrl: user['avatar_url'] as String?,
      addedAt: DateTime.parse(j['added_at'] as String),
    );
  }
}
