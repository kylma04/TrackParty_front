import '../models/event_model.dart';

/// Règles autour de `event.maxTicketsPerUserPerEvent` — centralisées ici pour
/// éviter que la même limite soit réinterprétée indépendamment à chaque
/// écran qui l'affiche (event_detail_screen.dart, order_cart_screen.dart).

/// Vrai si l'utilisateur a déjà atteint son plafond de billets pour cet
/// événement, au vu des billets qu'il possède déjà (hors panier en cours).
bool hasReachedTicketLimit(EventModel event) {
  final max = event.maxTicketsPerUserPerEvent;
  return max != null && event.myTicketsCount >= max;
}

/// Vrai si le panier peut encore accueillir `cartTotal` billets sans
/// dépasser le plafond par utilisateur (le panier seul, indépendamment des
/// billets déjà possédés — cohérent avec le comportement existant du panier).
bool isWithinCartTicketLimit(EventModel event, int cartTotal) {
  final max = event.maxTicketsPerUserPerEvent;
  return max == null || cartTotal <= max;
}
