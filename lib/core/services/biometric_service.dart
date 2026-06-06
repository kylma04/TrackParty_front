import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
);

class BiometricService {
  static const _emailKey    = '_tp_bio_email';
  static const _passKey     = '_tp_bio_pass';
  static const _enabledKey  = '_tp_bio_enabled';
  static const _providerKey = '_tp_bio_provider';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _auth = LocalAuthentication();

  /// Vérifie si l'appareil supporte la biométrie (Face ID ou empreinte).
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Déclenche le prompt biométrique natif.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirme ton identité pour te connecter à TrackParty',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // autorise aussi le code PIN comme fallback
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Sauvegarde les identifiants après une connexion email réussie.
  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passKey, value: password);
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(key: _providerKey, value: 'email');
  }

  /// Sauvegarde le fait que l'user s'est connecté via Google.
  Future<void> saveGoogleLogin() async {
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(key: _providerKey, value: 'google');
  }

  /// Retourne 'email', 'google', ou null si jamais connecté.
  Future<String?> getProvider() => _storage.read(key: _providerKey);

  /// Retourne les identifiants stockés, ou null si aucun.
  Future<({String email, String password})?> getCredentials() async {
    final email = await _storage.read(key: _emailKey);
    final pass  = await _storage.read(key: _passKey);
    if (email == null || pass == null) return null;
    return (email: email, password: pass);
  }

  /// Supprime les identifiants biométriques (ex: après déconnexion).
  Future<void> clearCredentials() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passKey);
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _providerKey);
  }

  Future<bool> isEnabled() async {
    final val = await _storage.read(key: _enabledKey);
    return val == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _storage.write(key: _enabledKey, value: 'true');
    } else {
      await clearCredentials();
    }
  }
}
