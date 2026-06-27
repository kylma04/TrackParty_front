import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Infos de maintenance renseignées quand l'API renvoie 503 {code:'maintenance'}
/// (cf. intercepteur dans `core/api/api_client.dart`) ou par un appel à
/// `/api/status/`. Tant que ce provider est non nul, le router confine
/// l'utilisateur sur l'écran `/maintenance`.
class MaintenanceInfo {
  final String message;
  final DateTime? estimatedEnd;

  const MaintenanceInfo({required this.message, this.estimatedEnd});
}

final maintenanceProvider = StateProvider<MaintenanceInfo?>((ref) => null);
