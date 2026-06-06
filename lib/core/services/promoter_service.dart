import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/promoter_model.dart';

final promoterServiceProvider = Provider<PromoterService>((ref) {
  return PromoterService(ref.read(dioProvider));
});

class PromoterService {
  final Dio _dio;
  PromoterService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<PromoterData> getProfile(String userId) => _call(() async {
        final res = await _dio.get('auth/promoters/$userId/');
        return PromoterData.fromJson(res.data as Map<String, dynamic>);
      });

  Future<bool> isFollowing(String userId) => _call(() async {
        final res = await _dio.get('auth/promoters/$userId/');
        return (res.data['is_following'] as bool?) ?? false;
      });

  Future<void> follow(String userId) => _call(() async {
        await _dio.post('auth/promoters/$userId/follow/');
      });

  Future<void> unfollow(String userId) => _call(() async {
        await _dio.delete('auth/promoters/$userId/follow/');
      });

  Future<List<PromoterEventItem>> getPromoterEvents(String userId, {String type = 'upcoming'}) =>
      _call(() async {
        final res = await _dio.get(
          'auth/promoters/$userId/events/',
          queryParameters: {'type': type},
        );
        final list = res.data as List<dynamic>;
        return list.map((e) => PromoterEventItem.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<TrustScoreData> getTrustScore(String userId) => _call(() async {
        final res = await _dio.get('auth/promoters/$userId/trust-score/');
        return TrustScoreData.fromJson(res.data as Map<String, dynamic>);
      });

  Future<List<ReviewItem>> getPromoterReviews(String userId) => _call(() async {
        final res = await _dio.get('auth/promoters/$userId/reviews/');
        final list = res.data as List<dynamic>;
        return list.map((e) => ReviewItem.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<ReviewItem> replyToReview(String reviewId, String reply) => _call(() async {
        final res = await _dio.patch(
          'events/reviews/$reviewId/reply/',
          data: {'reply': reply},
        );
        return ReviewItem.fromJson(res.data as Map<String, dynamic>);
      });
}
