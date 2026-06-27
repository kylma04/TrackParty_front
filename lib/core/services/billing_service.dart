import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

/// Droits du promoteur selon son abonnement (renvoyés par /billing/subscription/).
class Entitlements {
  final bool isPro;
  final int? maxActiveEvents; // null = illimité
  final int? maxCoOrganizers;
  final bool canAnalytics;
  final bool proBadge;
  final int proBoostDaysLeft;
  final DateTime? periodEnd;

  const Entitlements({
    required this.isPro,
    this.maxActiveEvents,
    this.maxCoOrganizers,
    this.canAnalytics = false,
    this.proBadge = false,
    this.proBoostDaysLeft = 0,
    this.periodEnd,
  });

  factory Entitlements.fromJson(Map<String, dynamic> j) => Entitlements(
        isPro: j['is_pro'] as bool? ?? false,
        maxActiveEvents: (j['max_active_events'] as num?)?.toInt(),
        maxCoOrganizers: (j['max_co_organizers'] as num?)?.toInt(),
        canAnalytics: j['can_analytics'] as bool? ?? false,
        proBadge: j['pro_badge'] as bool? ?? false,
        proBoostDaysLeft: (j['pro_boost_days_left'] as num?)?.toInt() ?? 0,
        periodEnd: j['period_end'] != null
            ? DateTime.tryParse(j['period_end'] as String)
            : null,
      );

  static const free = Entitlements(isPro: false, maxActiveEvents: 2, maxCoOrganizers: 1);
}

/// Catalogue public des offres (renvoyé par /billing/plans/, piloté par le .env backend).
class PlansCatalog {
  final String currentPlan; // 'free' | 'pro'
  final DateTime? periodEnd;
  final double commissionPct;
  final int freeMaxEvents;
  final int freeMaxCoOrganizers;
  final int freeMaxEventInvites; // plafond cumulé d'invitations/event (gratuit)
  final int proPrice;
  final int proWeeklyBoostDays;

  const PlansCatalog({
    required this.currentPlan,
    this.periodEnd,
    required this.commissionPct,
    required this.freeMaxEvents,
    required this.freeMaxCoOrganizers,
    required this.freeMaxEventInvites,
    required this.proPrice,
    required this.proWeeklyBoostDays,
  });

  bool get isPro => currentPlan == 'pro';

  factory PlansCatalog.fromJson(Map<String, dynamic> j) {
    final free = (j['free'] as Map<String, dynamic>?) ?? const {};
    final pro = (j['pro'] as Map<String, dynamic>?) ?? const {};
    return PlansCatalog(
      currentPlan: j['current_plan'] as String? ?? 'free',
      periodEnd: j['period_end'] != null
          ? DateTime.tryParse(j['period_end'] as String)
          : null,
      commissionPct: (j['commission_pct'] as num?)?.toDouble() ?? 0,
      freeMaxEvents: (free['max_active_events'] as num?)?.toInt() ?? 2,
      freeMaxCoOrganizers: (free['max_co_organizers'] as num?)?.toInt() ?? 1,
      freeMaxEventInvites: (free['max_event_invites'] as num?)?.toInt() ?? 100,
      proPrice: (pro['price'] as num?)?.toInt() ?? 0,
      proWeeklyBoostDays: (pro['weekly_boost_days'] as num?)?.toInt() ?? 0,
    );
  }
}

final billingServiceProvider = Provider<BillingService>((ref) {
  return BillingService(ref.read(dioProvider));
});

class BillingService {
  final Dio _dio;
  BillingService(this._dio);

  Future<Entitlements> getEntitlements() async {
    try {
      final res = await _dio.get('billing/subscription/');
      return Entitlements.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<PlansCatalog> getPlans() async {
    try {
      final res = await _dio.get('billing/plans/');
      return PlansCatalog.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Droits du promoteur connecté (badge Pro, plafonds…).
final entitlementsProvider = FutureProvider.autoDispose<Entitlements>((ref) {
  return ref.read(billingServiceProvider).getEntitlements();
});

/// Catalogue des offres (tarifs Free/Pro, commission…).
final plansProvider = FutureProvider.autoDispose<PlansCatalog>((ref) {
  return ref.read(billingServiceProvider).getPlans();
});
