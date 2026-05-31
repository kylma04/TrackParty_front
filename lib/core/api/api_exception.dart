import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? _fields;

  const ApiException({
    this.statusCode,
    required this.message,
    Map<String, dynamic>? fields,
  }) : _fields = fields;

  factory ApiException.fromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      // DRF field errors: {"email": ["already used."]}
      // DRF non_field_errors: {"non_field_errors": ["invalid."]}
      // DRF detail: {"detail": "message"}
      final detail = data['detail'] as String?;
      final nonField = (data['non_field_errors'] as List?)?.firstOrNull as String?;
      final message = detail ?? nonField ?? _extractFirstFieldError(data) ?? 'Erreur inconnue';
      return ApiException(
        statusCode: e.response?.statusCode,
        message: message,
        fields: data,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const ApiException(message: 'Délai de connexion dépassé. Réessaie.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const ApiException(message: 'Impossible de contacter le serveur. Vérifie ta connexion.');
    }
    return ApiException(statusCode: e.response?.statusCode, message: e.message ?? 'Erreur réseau');
  }

  String? fieldError(String field) {
    final v = _fields?[field];
    if (v is List && v.isNotEmpty) return v.first as String;
    if (v is String) return v;
    return null;
  }

  static String? _extractFirstFieldError(Map<String, dynamic> data) {
    for (final val in data.values) {
      if (val is List && val.isNotEmpty) return val.first as String;
      if (val is String) return val;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
