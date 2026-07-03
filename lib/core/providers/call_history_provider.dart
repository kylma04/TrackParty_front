import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../models/call_history_model.dart';

/// Liste des 100 derniers appels (entrants + sortants) de l'utilisateur.
final callHistoryProvider =
    FutureProvider.autoDispose<List<CallHistoryEntry>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get('chat/calls/history/');
  final data = (resp.data as List);
  return data
      .map((e) => CallHistoryEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Mémorise la date à laquelle l'utilisateur a consulté l'historique d'appels,
/// pour calculer la pastille « appels manqués non vus » sans état serveur.
class CallHistorySeen {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'tp_calls_last_seen';

  static Future<DateTime?> get() async {
    final v = await _storage.read(key: _key);
    return v == null ? null : DateTime.tryParse(v)?.toLocal();
  }

  static Future<void> markSeenNow() =>
      _storage.write(key: _key, value: DateTime.now().toUtc().toIso8601String());

  /// Remise à zéro au changement de compte (évite un mauvais compteur entre comptes).
  static Future<void> clear() => _storage.delete(key: _key);
}

/// Nombre d'appels manqués (entrants) survenus depuis la dernière consultation
/// de l'historique — alimente la pastille sur l'icône des conversations.
final missedCallsBadgeProvider = FutureProvider.autoDispose<int>((ref) async {
  final history  = await ref.watch(callHistoryProvider.future);
  final lastSeen = await CallHistorySeen.get();
  return history
      .where((c) =>
          c.isMissed && (lastSeen == null || c.startedAt.isAfter(lastSeen)))
      .length;
});
