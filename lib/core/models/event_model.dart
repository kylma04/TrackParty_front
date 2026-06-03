import 'user_model.dart';

class ContributionItemModel {
  final String id;
  final String name;
  final String emoji;
  final int quantityTotal;
  final int quantityTaken;
  final int quantityRemaining;
  final bool isAvailable;

  const ContributionItemModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.quantityTotal,
    required this.quantityTaken,
    required this.quantityRemaining,
    required this.isAvailable,
  });

  factory ContributionItemModel.fromJson(Map<String, dynamic> j) =>
      ContributionItemModel(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: (j['emoji'] as String?) ?? '',
        quantityTotal: j['quantity_total'] as int,
        quantityTaken: j['quantity_taken'] as int,
        quantityRemaining: j['quantity_remaining'] as int,
        isAvailable: j['is_available'] as bool,
      );
}

class UserParticipation {
  final String id;
  final String status;
  final String? contributionItemId;

  const UserParticipation({
    required this.id,
    required this.status,
    this.contributionItemId,
  });

  factory UserParticipation.fromJson(Map<String, dynamic> j) =>
      UserParticipation(
        id: j['id'] as String,
        status: j['status'] as String,
        contributionItemId: j['contribution_item_id'] as String?,
      );
}

class EventModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? customCategoryLabel;
  final String? customCategoryEmoji;
  final String? coverImageUrl;
  final DateTime startAt;
  final DateTime? endAt;
  final double? latitude;
  final double? longitude;
  final String addressLabel;
  final String city;
  final String quartier;
  final String visibility;
  final String status;
  final String contributionType;
  final double? contributionAmount;
  final int? maxParticipants;
  final int participantsCount;
  final double avgRating;
  final String organizerId;
  final String organizerName;
  final String? organizerAvatarUrl;
  final bool organizerIsPromoter;
  final bool isPast;
  final bool isFull;
  final bool isParticipating;
  final UserModel? organizer;
  final List<ContributionItemModel> contributionItems;
  final UserParticipation? userParticipation;
  final DateTime? createdAt;

  const EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.customCategoryLabel,
    this.customCategoryEmoji,
    this.coverImageUrl,
    required this.startAt,
    this.endAt,
    this.latitude,
    this.longitude,
    required this.addressLabel,
    required this.city,
    required this.quartier,
    required this.visibility,
    required this.status,
    required this.contributionType,
    this.contributionAmount,
    this.maxParticipants,
    required this.participantsCount,
    required this.avgRating,
    required this.organizerId,
    required this.organizerName,
    this.organizerAvatarUrl,
    required this.organizerIsPromoter,
    required this.isPast,
    required this.isFull,
    required this.isParticipating,
    this.organizer,
    this.contributionItems = const [],
    this.userParticipation,
    this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> j) => EventModel(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String,
        customCategoryLabel: j['custom_category_label'] as String?,
        customCategoryEmoji: j['custom_category_emoji'] as String?,
        coverImageUrl: j['cover_image_url'] as String?,
        startAt: DateTime.parse(j['start_at'] as String),
        endAt: j['end_at'] != null ? DateTime.parse(j['end_at'] as String) : null,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        addressLabel: (j['address_label'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        quartier: (j['quartier'] as String?) ?? '',
        visibility: j['visibility'] as String,
        status: j['status'] as String,
        contributionType: j['contribution_type'] as String,
        contributionAmount: (j['contribution_amount'] as num?)?.toDouble(),
        maxParticipants: j['max_participants'] as int?,
        participantsCount: j['participants_count'] as int,
        avgRating: (j['avg_rating'] as num?)?.toDouble() ?? 0.0,
        organizerId: j['organizer_id'] as String,
        organizerName: j['organizer_name'] as String,
        organizerAvatarUrl: j['organizer_avatar_url'] as String?,
        organizerIsPromoter: j['organizer_is_promoter'] as bool,
        isPast: j['is_past'] as bool,
        isFull: j['is_full'] as bool,
        isParticipating: j['is_participating'] as bool,
        organizer: j['organizer'] != null
            ? UserModel.fromJson(j['organizer'] as Map<String, dynamic>)
            : null,
        contributionItems: (j['contribution_items'] as List<dynamic>?)
                ?.map((e) => ContributionItemModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        userParticipation: j['user_participation'] != null
            ? UserParticipation.fromJson(j['user_participation'] as Map<String, dynamic>)
            : null,
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : null,
      );

  /// Emoji à afficher pour cette catégorie (priorité au custom)
  String get displayEmoji {
    if (category == 'autre' && customCategoryEmoji != null && customCategoryEmoji!.isNotEmpty) {
      return customCategoryEmoji!;
    }
    const emojis = {
      'musique': '🎵', 'soiree': '🎉', 'cuisine': '🍽',
      'sport': '⚽', 'art': '🎨', 'plage': '🏖',
    };
    return emojis[category] ?? '✨';
  }

  /// Label à afficher pour cette catégorie (priorité au custom)
  String get displayCategoryName {
    if (category == 'autre' && customCategoryLabel != null && customCategoryLabel!.isNotEmpty) {
      return customCategoryLabel!;
    }
    const labels = {
      'musique': 'Musique', 'soiree': 'Soirée', 'cuisine': 'Cuisine',
      'sport': 'Sport', 'art': 'Art', 'plage': 'Plage', 'autre': 'Autre',
    };
    return labels[category] ?? category;
  }

  bool get isCustomCategory =>
      category == 'autre' &&
      customCategoryLabel != null &&
      customCategoryLabel!.isNotEmpty;

  EventModel copyWith({bool? isParticipating, int? participantsCount, UserParticipation? userParticipation}) =>
      EventModel(
        id: id,
        title: title,
        description: description,
        category: category,
        coverImageUrl: coverImageUrl,
        startAt: startAt,
        endAt: endAt,
        latitude: latitude,
        longitude: longitude,
        addressLabel: addressLabel,
        city: city,
        quartier: quartier,
        visibility: visibility,
        status: status,
        contributionType: contributionType,
        contributionAmount: contributionAmount,
        maxParticipants: maxParticipants,
        participantsCount: participantsCount ?? this.participantsCount,
        avgRating: avgRating,
        organizerId: organizerId,
        organizerName: organizerName,
        organizerAvatarUrl: organizerAvatarUrl,
        organizerIsPromoter: organizerIsPromoter,
        isPast: isPast,
        isFull: isFull,
        isParticipating: isParticipating ?? this.isParticipating,
        organizer: organizer,
        contributionItems: contributionItems,
        userParticipation: userParticipation ?? this.userParticipation,
        createdAt: createdAt,
      );
}

class ParticipantModel {
  final String id;
  final String status;
  final String registeredAt;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? contributionItemId;
  final String? contributionItemName;
  final String? contributionItemEmoji;
  final int quantity;

  const ParticipantModel({
    required this.id,
    required this.status,
    required this.registeredAt,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.contributionItemId,
    this.contributionItemName,
    this.contributionItemEmoji,
    this.quantity = 1,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  factory ParticipantModel.fromJson(Map<String, dynamic> j) => ParticipantModel(
        id: j['id'] as String,
        status: j['status'] as String,
        registeredAt: j['registered_at'] as String,
        userId: j['user_id'] as String,
        userName: j['user_name'] as String,
        userAvatarUrl: j['user_avatar_url'] as String?,
        contributionItemId: j['contribution_item_id'] as String?,
        contributionItemName: j['contribution_item_name'] as String?,
        contributionItemEmoji: j['contribution_item_emoji'] as String?,
        quantity: (j['quantity'] as int?) ?? 1,
      );
}


class PaginatedEvents {
  final int count;
  final String? next;
  final String? previous;
  final List<EventModel> results;

  const PaginatedEvents({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PaginatedEvents.fromJson(Map<String, dynamic> j) => PaginatedEvents(
        count: j['count'] as int,
        next: j['next'] as String?,
        previous: j['previous'] as String?,
        results: (j['results'] as List<dynamic>)
            .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
