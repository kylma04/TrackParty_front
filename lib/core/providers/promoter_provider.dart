import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/promoter_model.dart';
import '../services/promoter_service.dart';

// ── Profil promoteur ──────────────────────────────────────────────────────────

final promoterProfileProvider =
    AsyncNotifierProvider.family<PromoterProfileNotifier, PromoterData, String>(
  PromoterProfileNotifier.new,
);

class PromoterProfileNotifier
    extends FamilyAsyncNotifier<PromoterData, String> {
  @override
  Future<PromoterData> build(String arg) =>
      ref.read(promoterServiceProvider).getProfile(arg);

  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final svc = ref.read(promoterServiceProvider);
    if (current.isFollowing) {
      await svc.unfollow(current.id);
    } else {
      await svc.follow(current.id);
    }
    state = AsyncData(PromoterData(
      id: current.id,
      displayName: current.displayName,
      avatarUrl: current.avatarUrl,
      bio: current.bio,
      city: current.city,
      isFollowing: !current.isFollowing,
      avgRating: current.avgRating,
      ratingsCount: current.ratingsCount,
      totalEvents: current.totalEvents,
      totalParticipants: current.totalParticipants,
      followerCount: current.isFollowing
          ? current.followerCount - 1
          : current.followerCount + 1,
      trustScore: current.trustScore,
      badgeLevel: current.badgeLevel,
    ));
  }
}

// ── Événements d'un promoteur ─────────────────────────────────────────────────

final promoterEventsProvider = FutureProvider.autoDispose
    .family<List<PromoterEventItem>, ({String userId, String type})>(
  (ref, arg) =>
      ref.read(promoterServiceProvider).getPromoterEvents(arg.userId, type: arg.type),
);

// ── Score de confiance ────────────────────────────────────────────────────────

final promoterTrustScoreProvider =
    FutureProvider.autoDispose.family<TrustScoreData, String>(
  (ref, userId) => ref.read(promoterServiceProvider).getTrustScore(userId),
);

// ── Avis sur les événements d'un promoteur ────────────────────────────────────

final promoterReviewsProvider =
    AsyncNotifierProvider.family<PromoterReviewsNotifier, List<ReviewItem>, String>(
  PromoterReviewsNotifier.new,
);

class PromoterReviewsNotifier
    extends FamilyAsyncNotifier<List<ReviewItem>, String> {
  @override
  Future<List<ReviewItem>> build(String arg) =>
      ref.read(promoterServiceProvider).getPromoterReviews(arg);

  Future<void> replyToReview(String reviewId, String reply) async {
    final updated = await ref.read(promoterServiceProvider).replyToReview(reviewId, reply);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((r) => r.id == reviewId ? updated : r).toList());
  }
}
