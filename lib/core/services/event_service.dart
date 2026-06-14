import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/custom_category.dart';
import '../models/event_model.dart';

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(ref.read(dioProvider));
});

class EventService {
  final Dio _dio;
  EventService(this._dio);

  Future<PaginatedEvents> getFeed({
    String? category,
    String? customCategory,
    String? filter,
    String? contribution,
    double? lat,
    double? lng,
    double radius = 25,
    String ordering = 'start_at',
    int page = 1,
  }) async {
    try {
      final params = <String, dynamic>{'page': page};
      if (category != null) params['category'] = category;
      if (customCategory != null) params['custom_category'] = customCategory;
      if (filter != null) params['filter'] = filter;
      if (contribution != null) params['contribution'] = contribution;
      if (lat != null) params['lat'] = lat;
      if (lng != null) params['lng'] = lng;
      if (lat != null) params['radius'] = radius;
      params['ordering'] = ordering;

      final res = await _dio.get('events/', queryParameters: params);
      return PaginatedEvents.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Catégories personnalisées existantes, triées par popularité.
  Future<List<CustomCategory>> getCustomCategories() async {
    try {
      final res = await _dio.get('events/custom-categories/');
      final list = res.data as List<dynamic>;
      return list
          .map((e) => CustomCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EventModel> getEvent(String id) async {
    try {
      final res = await _dio.get('events/$id/');
      return EventModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EventModel> createEvent(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('events/', data: data);
      return EventModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EventModel> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('events/$id/', data: data);
      return EventModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> cancelEvent(String id) async {
    try {
      await _dio.post('events/$id/cancel/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> participate(
    String eventId, {
    String? contributionItemId,
    int quantity = 1,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (contributionItemId != null) {
        body['contribution_item_id'] = contributionItemId;
        body['quantity'] = quantity;
      }
      await _dio.post('events/$eventId/participate/', data: body);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> cancelParticipation(String eventId) async {
    try {
      await _dio.delete('events/$eventId/participate/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ParticipantModel>> getParticipants(String eventId) async {
    try {
      final res = await _dio.get('events/$eventId/participants/');
      final list = res.data as List<dynamic>;
      return list
          .map((j) => ParticipantModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> submitReview(
    String eventId, {
    required int rating,
    String? comment,
    bool isPublic = true,
    List<String> tags = const [],
  }) async {
    try {
      await _dio.post('events/$eventId/reviews/', data: {
        'rating': rating,
        'comment': comment,
        'is_public': isPublic,
        'tags': tags,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// L'utilisateur refuse les rappels d'avis pour cet événement.
  Future<void> declineReview(String eventId) async {
    try {
      await _dio.post('events/$eventId/review/decline/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> saveEvent(String eventId) async {
    try {
      await _dio.post('events/$eventId/save/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> unsaveEvent(String eventId) async {
    try {
      await _dio.delete('events/$eventId/save/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<EventModel>> getSavedEvents() async {
    try {
      final res = await _dio.get('events/saved/');
      final data = res.data;
      final List<dynamic> list = data is Map ? (data['results'] as List) : (data as List);
      return list.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ParticipantModel>> getWaitlist(String eventId) async {
    try {
      final res = await _dio.get('events/$eventId/waitlist/');
      final list = res.data as List<dynamic>;
      return list.map((j) => ParticipantModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> waitlistAction(String eventId, String participationId, {required bool accept}) async {
    try {
      await _dio.patch('events/$eventId/waitlist/$participationId/', data: {
        'action': accept ? 'accept' : 'reject',
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EventStats> getEventStats(String eventId) async {
    try {
      final res = await _dio.get('events/$eventId/stats/');
      return EventStats.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, int>> getMyEventStats() async {
    try {
      final res = await _dio.get('auth/me/stats/');
      final data = res.data as Map<String, dynamic>;
      return {
        'organized_upcoming': (data['organized_upcoming'] as num).toInt(),
        'confirmed_participations': (data['confirmed_participations'] as num).toInt(),
        'past_events': (data['past_events'] as num).toInt(),
      };
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
