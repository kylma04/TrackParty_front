class PromoterProfileModel {
  final double trustScore;
  final String badgeLevel;
  final int totalEvents;
  final int totalParticipants;
  final double avgRating;
  final int ratingsCount;
  final int followerCount;

  const PromoterProfileModel({
    required this.trustScore,
    required this.badgeLevel,
    required this.totalEvents,
    required this.totalParticipants,
    required this.avgRating,
    required this.ratingsCount,
    required this.followerCount,
  });

  factory PromoterProfileModel.fromJson(Map<String, dynamic> j) => PromoterProfileModel(
        trustScore: (j['trust_score'] as num).toDouble(),
        badgeLevel: j['badge_level'] as String,
        totalEvents: j['total_events'] as int,
        totalParticipants: j['total_participants'] as int,
        avgRating: (j['avg_rating'] as num).toDouble(),
        ratingsCount: j['ratings_count'] as int,
        followerCount: j['follower_count'] as int,
      );
}

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? phone;
  final String? avatarUrl;
  final DateTime? dateBirth;
  final String bio;
  final String city;
  final String quartier;
  final bool isPromoter;
  final bool isVerified;
  final PromoterProfileModel? promoterProfile;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.phone,
    this.avatarUrl,
    this.dateBirth,
    required this.bio,
    required this.city,
    required this.quartier,
    required this.isPromoter,
    required this.isVerified,
    this.promoterProfile,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['display_name'] as String,
        phone: j['phone'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        dateBirth: j['date_birth'] != null
          ? DateTime.parse(j['date_birth'] as String)
          : null,
        bio: (j['bio'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        quartier: (j['quartier'] as String?) ?? '',
        isPromoter: j['is_promoter'] as bool,
        isVerified: j['is_verified'] as bool,
        promoterProfile: j['promoter_profile'] != null
            ? PromoterProfileModel.fromJson(j['promoter_profile'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  UserModel copyWith({
    String? displayName,
    String? phone,
    String? avatarUrl,
    DateTime? dateBirth,
    String? bio,
    String? city,
    String? quartier,
    bool? isPromoter,
    bool? isVerified,
  }) =>
      UserModel(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        dateBirth: dateBirth ?? this.dateBirth,
        bio: bio ?? this.bio,
        city: city ?? this.city,
        quartier: quartier ?? this.quartier,
        isPromoter: isPromoter ?? this.isPromoter,
        isVerified: isVerified ?? this.isVerified,
        promoterProfile: promoterProfile,
        createdAt: createdAt,
      );
}
