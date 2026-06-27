import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

/// Moyens de paiement supportés par GeniusPay (https://geniuspay.ci/docs/api).
enum PayMethod { wave, orange, mtn, moov, card }

extension PayMethodX on PayMethod {
  /// Code `payment_method` attendu par l'API GeniusPay.
  String get api => switch (this) {
        PayMethod.wave => 'wave',
        PayMethod.orange => 'orange_money',
        PayMethod.mtn => 'mtn_money',
        PayMethod.moov => 'moov_money',
        PayMethod.card => 'card',
      };
  String get label => switch (this) {
        PayMethod.wave => 'Wave',
        PayMethod.orange => 'Orange Money',
        PayMethod.mtn => 'MTN MoMo',
        PayMethod.moov => 'Moov Money',
        PayMethod.card => 'Carte bancaire',
      };
  /// Logo officiel du moyen de paiement (fichiers à déposer dans
  /// assets/icons/payments/). Un fallback emoji est affiché s'il manque.
  String get logoAsset => 'assets/icons/payments/$name.png';
  String get emoji => switch (this) {
        PayMethod.wave => '🌊',
        PayMethod.orange => '🟠',
        PayMethod.mtn => '🟡',
        PayMethod.moov => '🔵',
        PayMethod.card => '💳',
      };
}

class PaymentInit {
  final String paymentId;
  final String status;
  final int amount;
  final String? category;
  final String? redirectUrl;
  const PaymentInit({
    required this.paymentId,
    required this.status,
    required this.amount,
    this.category,
    this.redirectUrl,
  });
  factory PaymentInit.fromJson(Map<String, dynamic> j) => PaymentInit(
        paymentId: j['payment_id'] as String,
        status: j['status'] as String,
        amount: (j['amount'] as num).toInt(),
        category: j['category'] as String?,
        redirectUrl: j['redirect_url'] as String?,
      );
}

class OrderResult {
  final String orderId;
  final String status; // pending | paid | cancelled
  final int amount;
  final int tickets;
  final String? paymentId;
  final String? redirectUrl;
  const OrderResult({
    required this.orderId,
    required this.status,
    required this.amount,
    required this.tickets,
    this.paymentId,
    this.redirectUrl,
  });
  factory OrderResult.fromJson(Map<String, dynamic> j) => OrderResult(
        orderId: j['order_id'] as String,
        status: j['status'] as String,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        tickets: (j['tickets'] as num?)?.toInt() ?? 0,
        paymentId: j['payment_id'] as String?,
        redirectUrl: j['redirect_url'] as String?,
      );
  bool get needsPayment => (redirectUrl ?? '').isNotEmpty;
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.read(dioProvider));
});

class PaymentService {
  final Dio _dio;
  PaymentService(this._dio);

  /// Démarre l'achat d'un billet payant : réserve la place + renvoie l'URL GeniusPay.
  Future<PaymentInit> purchaseTicket({
    required String eventId,
    required String categoryId,
    required PayMethod method,
  }) async {
    try {
      final res = await _dio.post(
        'events/$eventId/tickets/purchase/',
        data: {'category_id': categoryId, 'payment_method': method.api},
      );
      return PaymentInit.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Commande un panier de billets (mixte payant + nature).
  /// `items` : [{kind:'paid', category_id, quantity}] / [{kind:'nature', item_id, quantity}].
  Future<OrderResult> createOrder({
    required String eventId,
    required List<Map<String, dynamic>> items,
    PayMethod? method,
  }) async {
    try {
      final res = await _dio.post('events/$eventId/order/', data: {
        'items': items,
        if (method != null) 'payment_method': method.api,
      });
      return OrderResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Démarre un paiement abonnement Pro / boost (POST /api/payments/create/).
  /// `purpose` : 'subscription' | 'boost'. `objectId` = id du boost (si boost).
  Future<PaymentInit> createPayment({
    required String purpose,
    required PayMethod method,
    String? objectId,
  }) async {
    try {
      final body = <String, dynamic>{
        'purpose': purpose,
        'payment_method': method.api,
      };
      if (objectId != null) body['object_id'] = objectId;
      final res = await _dio.post('payments/create/', data: body);
      final j = res.data as Map<String, dynamic>;
      // CreatePaymentView renvoie {id, status, amount, redirect_url, ...}.
      return PaymentInit(
        paymentId: j['id'] as String,
        status: j['status'] as String,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        redirectUrl: j['redirect_url'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Statut courant d'un paiement (pour le polling) : pending|success|error|expired.
  Future<String> getStatus(String paymentId) async {
    try {
      final res = await _dio.get('payments/$paymentId/');
      return (res.data as Map<String, dynamic>)['status'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
