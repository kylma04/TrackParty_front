import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pont natif + préférences pour la « préparation aux appels en arrière-plan ».
///
/// Sur beaucoup de constructeurs Android (Xiaomi/MIUI, Oppo/ColorOS, Vivo,
/// Huawei, Samsung…), une app **tuée** n'est PAS réveillée par le push d'appel
/// tant qu'elle n'est pas **exemptée de l'optimisation batterie** (et parfois
/// autorisée au **démarrage automatique**). Ces réglages ne sont accordables que
/// par l'utilisateur : ce service ouvre les bonnes pages système.
///
/// iOS n'a pas ce problème (PushKit/CallKit gère le réveil) → tout est neutre.
class CallReadinessService {
  static const _channel = MethodChannel('trackparty/battery');
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kReminderOff = '_tp_call_bg_reminder_off';
  static const _kPrompted    = '_tp_call_bg_prompted';

  /// true si l'app est déjà exemptée d'optimisation batterie (ou hors Android).
  static Future<bool> isBatteryExempted() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ouvre la boîte de dialogue système d'exemption d'optimisation batterie.
  static Future<void> requestBatteryExemption() async {
    if (!Platform.isAndroid) return;
    try { await _channel.invokeMethod('requestBatteryExemption'); } catch (_) {}
  }

  /// Ouvre la page « Démarrage automatique » du constructeur (repli : réglages app).
  static Future<void> openAutoStartSettings() async {
    if (!Platform.isAndroid) return;
    try { await _channel.invokeMethod('openAutoStartSettings'); } catch (_) {}
  }

  /// Ouvre la fiche de l'app dans les réglages système.
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    try { await _channel.invokeMethod('openAppSettings'); } catch (_) {}
  }

  // ── Préférence : rappel d'onboarding activé / désactivé ────────────────────

  /// true si l'utilisateur a désactivé le rappel automatique au démarrage.
  static Future<bool> reminderDisabled() async =>
      (await _storage.read(key: _kReminderOff)) == '1';

  static Future<void> setReminderDisabled(bool off) async =>
      _storage.write(key: _kReminderOff, value: off ? '1' : '0');

  static Future<bool> _alreadyPrompted() async =>
      (await _storage.read(key: _kPrompted)) == '1';

  /// Marque l'onboarding comme déjà proposé automatiquement (une seule fois).
  static Future<void> markAutoPrompted() =>
      _storage.write(key: _kPrompted, value: '1');

  /// Faut-il afficher l'onboarding automatiquement après login ?
  /// Oui si : Android, pas encore exempté, rappel non désactivé, jamais proposé.
  static Future<bool> shouldAutoPrompt() async {
    if (!Platform.isAndroid) return false;
    if (await reminderDisabled()) return false;
    if (await _alreadyPrompted()) return false;
    if (await isBatteryExempted()) return false;
    return true;
  }
}
