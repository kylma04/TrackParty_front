import 'package:flutter/material.dart';
import '../../theme/colors.dart';

// ── PromoterData ──────────────────────────────────────────────────────────────

class PromoterData {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final bool isFollowing;
  final double avgRating;
  final int ratingsCount;
  final int totalEvents;
  final int totalParticipants;
  final int followerCount;
  final double trustScore;
  final String badgeLevel;

  const PromoterData({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.city,
    required this.isFollowing,
    required this.avgRating,
    required this.ratingsCount,
    required this.totalEvents,
    required this.totalParticipants,
    required this.followerCount,
    required this.trustScore,
    required this.badgeLevel,
  });

  factory PromoterData.fromJson(Map<String, dynamic> j) {
    final profile = j['promoter_profile'] as Map<String, dynamic>? ?? {};
    return PromoterData(
      id: j['id'] as String,
      displayName: j['display_name'] as String,
      avatarUrl: j['avatar_url'] as String?,
      bio: j['bio'] as String?,
      city: j['city'] as String?,
      isFollowing: (j['is_following'] as bool?) ?? false,
      avgRating: (profile['avg_rating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: (profile['ratings_count'] as num?)?.toInt() ?? 0,
      totalEvents: (profile['total_events'] as num?)?.toInt() ?? 0,
      totalParticipants: (profile['total_participants'] as num?)?.toInt() ?? 0,
      followerCount: (profile['follower_count'] as num?)?.toInt() ?? 0,
      trustScore: (profile['trust_score'] as num?)?.toDouble() ?? 0.0,
      badgeLevel: (profile['badge_level'] as String?) ?? 'bronze',
    );
  }

  String get badgeLabel {
    switch (badgeLevel) {
      case 'gold':
        return 'Promoteur Or';
      case 'silver':
        return 'Promoteur Argent';
      default:
        return 'Promoteur Bronze';
    }
  }

  String get starLabel {
    switch (badgeLevel) {
      case 'gold':
        return '★ Promoteur Or';
      case 'silver':
        return '★ Promoteur Argent';
      default:
        return '★ Promoteur';
    }
  }

  String get participantsLabel {
    if (totalParticipants >= 1000) {
      return '${(totalParticipants / 1000).toStringAsFixed(1)}K';
    }
    return '$totalParticipants';
  }
}

// ── PromoterEventItem ─────────────────────────────────────────────────────────

class PromoterEventItem {
  final String id;
  final String title;
  final String? city;
  final String? coverUrl;
  final int participantsCount;
  final String category;
  final String? customCategoryLabel;
  final String? customCategoryEmoji;
  final DateTime startAt;

  const PromoterEventItem({
    required this.id,
    required this.title,
    this.city,
    this.coverUrl,
    required this.participantsCount,
    required this.category,
    this.customCategoryLabel,
    this.customCategoryEmoji,
    required this.startAt,
  });

  factory PromoterEventItem.fromJson(Map<String, dynamic> j) {
    return PromoterEventItem(
      id: j['id'] as String,
      title: j['title'] as String,
      city: j['city'] as String?,
      coverUrl: j['cover_image_url'] as String?,
      participantsCount: (j['participants_count'] as num?)?.toInt() ?? 0,
      category: (j['category'] as String?) ?? 'soirée',
      customCategoryLabel: j['custom_category_label'] as String?,
      customCategoryEmoji: j['custom_category_emoji'] as String?,
      startAt: DateTime.parse(j['start_at'] as String),
    );
  }

  String get categoryEmoji {
    if (category == 'autre' && customCategoryEmoji != null && customCategoryEmoji!.isNotEmpty) {
      return customCategoryEmoji!;
    }
    const emojis = {
      'soirée': '🎉', 'musique': '🎵', 'plage': '🏖', 'sport': '⚽',
      'culture': '🎨', 'food': '🍽', 'tech': '💻', 'business': '💼',
    };
    return emojis[category] ?? '✨';
  }

  Color get categoryColor {
    const colors = {
      'soirée':  kCategoryParty,
      'musique': kCategoryMusic,
      'plage':   kCategoryBeach,
      'sport':   kSuccess,
      'culture': kInfo,
      'food':    kCategoryFood,
      'tech':    kPrimary,
      'business':Color(0xFF64748B),
    };
    return colors[category] ?? kPrimary;
  }
}

// ── ReviewItem ────────────────────────────────────────────────────────────────

class ReviewItem {
  final String id;
  final String reviewerName;
  final String? reviewerAvatarUrl;
  final int rating;
  final DateTime createdAt;
  final String? eventTitle;
  final String comment;
  final List<String> tags;
  final String? organizerReply;
  final DateTime? replyAt;

  const ReviewItem({
    required this.id,
    required this.reviewerName,
    this.reviewerAvatarUrl,
    required this.rating,
    required this.createdAt,
    this.eventTitle,
    required this.comment,
    required this.tags,
    this.organizerReply,
    this.replyAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) {
    return ReviewItem(
      id: j['id'] as String,
      reviewerName: (j['reviewer_name'] as String?) ?? 'Anonyme',
      reviewerAvatarUrl: j['reviewer_avatar_url'] as String?,
      rating: (j['rating'] as num).toInt(),
      createdAt: DateTime.parse(j['created_at'] as String),
      eventTitle: j['event_title'] as String?,
      comment: (j['comment'] as String?) ?? '',
      tags: (j['tags'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      organizerReply: j['organizer_reply'] as String?,
      replyAt: j['reply_at'] != null ? DateTime.parse(j['reply_at'] as String) : null,
    );
  }

  String get dateLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays == 0) return "aujourd'hui";
    if (diff.inDays == 1) return 'il y a 1 jour';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
    if (diff.inDays < 14) return 'il y a 1 semaine';
    if (diff.inDays < 31) return 'il y a ${diff.inDays ~/ 7} semaines';
    if (diff.inDays < 60) return 'il y a 1 mois';
    return 'il y a ${diff.inDays ~/ 30} mois';
  }

  List<String> get tagLabels {
    const tagMap = {
      'ambiance': '🎵 Ambiance',
      'boissons': '🍾 Boissons',
      'monde_sympa': '👥 Monde sympa',
      'lieu': '📍 Lieu',
      'ponctualite': '⏰ Ponctualité',
      'bouffe': '🍽 Bouffe',
    };
    return tags.map((t) => tagMap[t] ?? t).toList();
  }
}

// ── TrustScoreData ────────────────────────────────────────────────────────────

class TrustCriterion {
  final String key;
  final String label;
  final int weight;
  final int fill;
  final Color color;
  final String emoji;

  const TrustCriterion({
    required this.key,
    required this.label,
    required this.weight,
    required this.fill,
    required this.color,
    required this.emoji,
  });

  factory TrustCriterion.fromJson(Map<String, dynamic> j) {
    const colorMap = {
      'orange': kAccent,
      'purple': kSecondary,
      'pink':   kTertiary,
      'cyan':   kInfo,
      'green':  kSuccess,
    };
    return TrustCriterion(
      key: j['key'] as String,
      label: j['label'] as String,
      weight: (j['weight'] as num).toInt(),
      fill: (j['fill'] as num).toInt(),
      color: colorMap[j['color'] as String?] ?? kPrimary,
      emoji: j['emoji'] as String,
    );
  }
}

class TrustScoreData {
  final int score;
  final String badgeLevel;
  final String badgeLabel;
  final String tip;
  final List<TrustCriterion> criteria;

  const TrustScoreData({
    required this.score,
    required this.badgeLevel,
    required this.badgeLabel,
    required this.tip,
    required this.criteria,
  });

  factory TrustScoreData.fromJson(Map<String, dynamic> j) {
    return TrustScoreData(
      score: (j['score'] as num).toInt(),
      badgeLevel: j['badge_level'] as String,
      badgeLabel: j['badge_label'] as String,
      tip: j['tip'] as String,
      criteria: (j['criteria'] as List<dynamic>)
          .map((e) => TrustCriterion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
