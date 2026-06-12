import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';
import '../providers/event_provider.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  final String accessToken;
  final String refreshToken;
  const AuthAuthenticated({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  AuthAuthenticated copyWithUser(UserModel user) => AuthAuthenticated(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  Future<AuthState> build() async {
    // Force logout when Dio interceptor can't renew the access token.
    // Called before any await to ensure the listener is always registered.
    ref.listen<int>(forceLogoutSignalProvider, (prev, next) {
      state = const AsyncValue.data(AuthUnauthenticated());
    });

    final stored = await TokenStorage.load();
    if (stored == null) return const AuthUnauthenticated();
    try {
      final user = await _service.getMe();
      // Ensure FCM token is fresh and registered even if already logged in
      _registerFcmToken();
      return AuthAuthenticated(
        user: user,
        accessToken: stored.access,
        refreshToken: stored.refresh,
      );
    } catch (_) {
      await TokenStorage.clear();
      return const AuthUnauthenticated();
    }
  }

  // ── Email/password ──────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _applyResponse(_service.login(email, password)));
  }

  /// Inscription : vérification d'email obligatoire. Aucun token n'est délivré ;
  /// on reste non authentifié et on retourne l'email pour l'écran de vérification.
  /// Lève une [ApiException] en cas d'erreur (gérée par l'écran via le state).
  Future<String> register({
    required String email,
    required String displayName,
    required String password,
    required DateTime dateBirth,
  }) async {
    state = const AsyncValue.loading();
    try {
      final registeredEmail = await _service.register(
        email: email, 
        displayName: displayName, 
        password: password,
        dateBirth: dateBirth,
      );
      state = const AsyncValue.data(AuthUnauthenticated());
      return registeredEmail;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Applique une AuthResponse déjà obtenue (ex: tokens retournés par verify-email-code).
  Future<void> loginWithResponse(AuthResponse response) async {
    state = AsyncValue.data(await _applyResponse(Future.value(response)));
    ref.invalidate(nearbyEventsFeedProvider);
    ref.invalidate(trendingEventsFeedProvider);
    ref.invalidate(savedEventsProvider);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _service.patchMe(data);
    await refreshUser();
  }

  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;
    final updated = await _service.getMe();
    state = AsyncValue.data(AuthAuthenticated(
      user: updated,
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
    ));
  }

  Future<void> logout() async {
    final current = state.valueOrNull;
    if (current is AuthAuthenticated) {
      try {
        await _service.logout(current.refreshToken);
      } catch (_) {}
    }
    await TokenStorage.clear();
    // On ne supprime PAS les credentials biométriques à la déconnexion
    // pour permettre une reconnexion rapide par biométrie
    state = const AsyncValue.data(AuthUnauthenticated());
    ref.invalidate(nearbyEventsFeedProvider);
    ref.invalidate(trendingEventsFeedProvider);
    ref.invalidate(savedEventsProvider);
  }

  // ── Social auth ─────────────────────────────────────────────────────────────

  Future<void> googleLogin(String idToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _applyResponse(_service.googleAuth(idToken)));
  }

  Future<void> appleLogin(String idToken, {String? displayName}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _applyResponse(_service.appleAuth(idToken, displayName: displayName)),
    );
  }

  Future<void> facebookLogin(String accessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _applyResponse(_service.facebookAuth(accessToken)));
  }

  Future<void> snapchatLogin(String accessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _applyResponse(_service.snapchatAuth(accessToken)));
  }

  Future<void> instagramLogin(String accessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _applyResponse(_service.instagramAuth(accessToken)));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<AuthState> _applyResponse(Future<AuthResponse> future) async {
    final response = await future;
    await TokenStorage.save(access: response.access, refresh: response.refresh);
    _registerFcmToken();
    ref.invalidate(nearbyEventsFeedProvider);
    ref.invalidate(trendingEventsFeedProvider);
    ref.invalidate(savedEventsProvider);
    return AuthAuthenticated(
      user: response.user,
      accessToken: response.access,
      refreshToken: response.refresh,
    );
  }

  // Fire-and-forget: get FCM token and send it to the backend.
  // Called after every successful login/register — safe to call multiple times.
  Future<void> _registerFcmToken() async {
    try {
      debugPrint('📱 FCM: Starting registration...');
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('📱 FCM: Permission status: ${settings.authorizationStatus}');
      
      final token = await messaging.getToken();
      if (token == null) {
        debugPrint('📱 FCM: Token is null, cannot register');
        return;
      }
      
      debugPrint('📱 FCM: Token obtained, sending to backend...');
      await _service.registerFcmToken(token);
      debugPrint('📱 FCM: Registration successful');
      
      // Keep token fresh when FCM rotates it
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('📱 FCM: Token refreshed, updating backend...');
        _service.registerFcmToken(newToken);
      });
    } catch (e) {
      debugPrint('📱 FCM: Registration error: $e');
      // Non-critical — push notifications simply won't work
    }
  }

  // Exposed so screens can rethrow ApiException for field-level errors
  ApiException? get lastError {
    final err = state.error;
    return err is ApiException ? err : null;
  }
}
