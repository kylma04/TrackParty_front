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
  final String? holderAvatarUrl;
  final bool isTransferable;
  final int transferCount;
  final DateTime createdAt;
  final String? categoryName;
  final String? categoryColor; // hex #RRGGBB
  final String? natureItemName;
  final String? natureItemEmoji;
  final List<String> categoryAdvantages;
  final bool isInKind;

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
    this.holderAvatarUrl,
    this.isTransferable = false,
    this.transferCount = 0,
    required this.createdAt,
    this.categoryName,
    this.categoryColor,
    this.natureItemName,
    this.natureItemEmoji,
    this.categoryAdvantages = const [],
    this.isInKind = false,
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
        holderAvatarUrl: j['holder_avatar_url'] as String?,
        isTransferable: j['is_transferable'] as bool? ?? false,
        transferCount: (j['transfer_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
        categoryName: j['category_name'] as String?,
        categoryColor: j['category_color'] as String?,
        natureItemName: j['nature_item_name'] as String?,
        natureItemEmoji: j['nature_item_emoji'] as String?,
        categoryAdvantages: (j['category_advantages'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        isInKind: j['is_in_kind'] as bool? ?? false,
      );
}

/// Un billet que l'utilisateur a CÉDÉ (transféré), avec le destinataire.
class SentTransferModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final String? eventCover;
  final DateTime eventStart;
  final String recipientName;
  final String? recipientAvatarUrl;
  final String? categoryName;
  final bool checkedIn;
  final DateTime transferredAt;

  const SentTransferModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    this.eventCover,
    required this.eventStart,
    required this.recipientName,
    this.recipientAvatarUrl,
    this.categoryName,
    required this.checkedIn,
    required this.transferredAt,
  });

  factory SentTransferModel.fromJson(Map<String, dynamic> j) {
    final r = (j['recipient'] as Map<String, dynamic>?) ?? const {};
    return SentTransferModel(
      id: j['id'] as String,
      eventId: j['event_id'] as String,
      eventTitle: j['event_title'] as String,
      eventCover: j['event_cover'] as String?,
      eventStart: DateTime.parse(j['event_start'] as String),
      recipientName: (r['display_name'] as String?) ?? 'Utilisateur',
      recipientAvatarUrl: r['avatar_url'] as String?,
      categoryName: j['category_name'] as String?,
      checkedIn: j['checked_in'] as bool? ?? false,
      transferredAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

class CheckinResult {
  final bool valid;
  final String holderName;
  final String eventTitle;
  final bool alreadyChecked;
  final DateTime? checkedInAt;
  final String message;
  /// Billet en nature valide dont le staff doit encore vérifier la
  /// contribution avant que l'entrée soit matérialisée (voir
  /// TicketService.checkin(confirm:)).
  final bool requiresConfirmation;
  final bool isInKind;
  final String? categoryName;
  final String? categoryColor; // hex #RRGGBB
  final String? natureItemName;
  final String? natureItemEmoji;

  const CheckinResult({
    required this.valid,
    required this.holderName,
    required this.eventTitle,
    required this.alreadyChecked,
    this.checkedInAt,
    required this.message,
    this.requiresConfirmation = false,
    this.isInKind = false,
    this.categoryName,
    this.categoryColor,
    this.natureItemName,
    this.natureItemEmoji,
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
        requiresConfirmation: j['requires_confirmation'] as bool? ?? false,
        isInKind: j['is_in_kind'] as bool? ?? false,
        categoryName: j['category_name'] as String?,
        categoryColor: j['category_color'] as String?,
        natureItemName: j['nature_item_name'] as String?,
        natureItemEmoji: j['nature_item_emoji'] as String?,
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
