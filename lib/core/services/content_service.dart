import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/content_model.dart';

final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService(ref.read(dioProvider));
});

class ContentService {
  final Dio _dio;
  ContentService(this._dio);

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Charge l'écran « Aide & support » (contact + FAQ) en un seul appel.
  Future<SupportContent> getSupport() => _call(() async {
        final res = await _dio.get('content/support/');
        return SupportContent.fromJson(res.data as Map<String, dynamic>);
      });

  /// Charge un document légal par son slug (ex. `privacy`).
  Future<LegalDocument> getLegalDocument(String slug) => _call(() async {
        final res = await _dio.get('content/legal/$slug/');
        return LegalDocument.fromJson(res.data as Map<String, dynamic>);
      });
}

/// Contenu support — rechargeable via `ref.refresh`.
final supportProvider = FutureProvider.autoDispose<SupportContent>((ref) {
  return ref.read(contentServiceProvider).getSupport();
});

/// Document légal par slug.
final legalDocumentProvider =
    FutureProvider.autoDispose.family<LegalDocument, String>((ref, slug) {
  return ref.read(contentServiceProvider).getLegalDocument(slug);
});
