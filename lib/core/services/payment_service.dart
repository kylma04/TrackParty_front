import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

/// Moyens de paiement supportés par Jeko (https://developer.jeko.africa).
enum PayMethod { wave, orange, mtn, moov, djamo }

extension PayMethodX on PayMethod {
  /// Code `payment_method` attendu par l'API Jeko.
  String get api => switch (this) {
        PayMethod.wave => 'wave',
        PayMethod.orange => 'orange',
        PayMethod.mtn => 'mtn',
        PayMethod.moov => 'moov',
        PayMethod.djamo => 'djamo',
      };
  String get label => switch (this) {
        PayMethod.wave => 'Wave',
        PayMethod.orange => 'Orange Money',
        PayMethod.mtn => 'MTN MoMo',
        PayMethod.moov => 'Moov Money',
        PayMethod.djamo => 'Djamo',
      };
  /// Logo officiel (assets/icons/payments/) — SVG ou PNG selon le fichier
  /// disponible. `null` → l'UI retombe sur l'emoji.
  String? get logoAsset => switch (this) {
        PayMethod.wave => 'assets/icons/payments/wave.svg',
        PayMethod.orange => 'assets/icons/payments/orange.svg',
        PayMethod.mtn => 'assets/icons/payments/mtn.svg',
        // Recadré en cercle depuis moov_money.webp (voir scripts d'origine
        // dans l'historique) : l'asset brut est un bandeau rectangulaire.
        PayMethod.moov => 'assets/icons/payments/moov.png',
        PayMethod.djamo => 'assets/icons/payments/Djamo.svg',
      };

  /// Djamo n'a qu'un logo NOIR (wordmark) : sans fond clair derrière, il
  /// devient invisible sur les surfaces sombres de l'app (thème dark-first).
  bool get logoNeedsLightBackdrop => this == PayMethod.djamo;
  String get emoji => switch (this) {
        PayMethod.wave => '🌊',
        PayMethod.orange => '🟠',
        PayMethod.mtn => '🟡',
        PayMethod.moov => '🔵',
        PayMethod.djamo => '💜',
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

  /// Démarre l'achat d'un billet payant : réserve la place + renvoie l'URL Jeko.
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
