import 'dart:async';

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
import '../providers/chat_provider.dart';
import '../providers/ticket_provider.dart';
import '../providers/promoter_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/co_organizer_provider.dart';
import '../services/billing_service.dart';
import '../services/biometric_service.dart';
import '../services/moderation_service.dart';
import '../services/support_service.dart';
import '../../features/event/boost_popup.dart';

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

/// Compte bloqué par la modération → l'utilisateur reste sur l'écran dédié.
class AuthBlocked extends AuthState {
  final String message;
  const AuthBlocked(this.message);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  Future<AuthState> build() async {
    // Force logout when Dio interceptor can't renew the access token.
    // Called before any await to ensure the listener is always registered.
    ref.listen<int>(forceLogoutSignalProvider, (prev, next) {
      state = const AsyncValue.data(AuthUnauthenticated());
    });

    // Compte bloqué (détecté par l'intercepteur Dio sur une requête en session).
    ref.listen<String?>(accountBlockedProvider, (prev, next) {
      if (next != null) state = AsyncValue.data(AuthBlocked(next));
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
    } on ApiException catch (e) {
      // Compte bloqué au démarrage (déjà connecté) → écran dédié.
      await TokenStorage.clear();
      if (e.code == 'account_blocked') return AuthBlocked(e.message);
      return const AuthUnauthenticated();
    } catch (_) {
      await TokenStorage.clear();
      return const AuthUnauthenticated();
    }
  }

  /// Bascule immédiatement sur l'écran « compte bloqué » (ex. refus au login).
  void markBlocked(String message) {
    TokenStorage.clear();
    state = AsyncValue.data(AuthBlocked(message));
  }

  // ── Email/password ──────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _applyResponse(_service.login(email, password)),
    );
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
    // _applyResponse purge déjà le cache user-scoped (cf. _resetUserScopedCaches).
    state = AsyncValue.data(await _applyResponse(Future.value(response)));
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _service.patchMe(data);
    await refreshUser();
  }

  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;
    final updated = await _service.getMe();
    state = AsyncValue.data(
      AuthAuthenticated(
        user: updated,
        accessToken: current.accessToken,
        refreshToken: current.refreshToken,
      ),
    );
  }

  Future<void> logout() async {
    final current = state.valueOrNull;
    if (current is AuthAuthenticated) {
      try {
        await _service.logout(current.refreshToken);
      } catch (_) {}
    }
    await TokenStorage.clear();
    // Efface les identifiants biométriques mémorisés : sur un appareil partagé,
    // un autre compte ne doit pas pouvoir reconnecter le précédent par biométrie.
    await ref.read(biometricServiceProvider).clearCredentials();
    state = const AsyncValue.data(AuthUnauthenticated());
    // Purge le cache de la session pour qu'aucune donnée/permission ne fuite
    // vers le prochain compte connecté sur le même appareil.
    _resetUserScopedCaches();
  }

  // ── Social auth ─────────────────────────────────────────────────────────────

  Future<void> googleLogin(String idToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _applyResponse(_service.googleAuth(idToken)),
    );
  }

  Future<void> appleLogin(String idToken, {String? displayName}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () =>
          _applyResponse(_service.appleAuth(idToken, displayName: displayName)),
    );
  }

  Future<void> facebookLogin(String accessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _applyResponse(_service.facebookAuth(accessToken)),
    );
  }

  Future<void> snapchatLogin(String accessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _applyResponse(_service.snapchatAuth(accessToken)),
    );
  }

  Future<void> instagramLogin(String accessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _applyResponse(_service.instagramAuth(accessToken)),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<AuthState> _applyResponse(Future<AuthResponse> future) async {
    final response = await future;
    await TokenStorage.save(access: response.access, refresh: response.refresh);
    _registerFcmToken();
    // Le token du NOUVEL utilisateur est déjà persisté → on purge tout le cache
    // de la session précédente pour éviter de montrer ses données/permissions.
    _resetUserScopedCaches();
    return AuthAuthenticated(
      user: response.user,
      accessToken: response.access,
      refreshToken: response.refresh,
    );
  }

  /// Invalide TOUS les providers qui mettent en cache des données ou des
  /// permissions propres à l'utilisateur. Appelé à chaque changement d'identité
  /// (connexion ET déconnexion) car, sur un même appareil, le state Riverpod
  /// survit à la déconnexion et exposerait sinon l'UI de la session précédente
  /// (ex. outils organisateur via `eventDetailProvider.isCoOrganizer`).
  ///
  /// ⚠️ Tout nouveau provider user-scoped DOIT être ajouté ici.
  void _resetUserScopedCaches() {
    // Événements
    ref.invalidate(nearbyEventsFeedProvider);
    ref.invalidate(trendingEventsFeedProvider);
    ref.invalidate(eventDetailProvider);
    ref.invalidate(myEventStatsProvider);
    ref.invalidate(myEventsProvider);
    ref.invalidate(eventStatsProvider);
    ref.invalidate(eventBoostProvider);
    ref.invalidate(boostedPopupProvider);
    ref.invalidate(savedEventsProvider);
    ref.invalidate(eventWaitlistProvider);
    // Chat & invitations
    ref.invalidate(chatRoomsProvider);
    ref.invalidate(chatThreadProvider);
    ref.invalidate(communityRoomProvider);
    ref.invalidate(chatPartnerReadAtProvider);
    ref.invalidate(chatPartnerOnlineProvider);
    ref.invalidate(invitationsProvider);
    // Billetterie / staff
    ref.invalidate(myTicketProvider);
    ref.invalidate(myTicketsProvider);
    ref.invalidate(myTransferredTicketsProvider);
    ref.invalidate(eventCheckinsProvider);
    ref.invalidate(eventStaffProvider);
    // Profil promoteur
    ref.invalidate(promoterProfileProvider);
    ref.invalidate(promoterEventsProvider);
    ref.invalidate(promoterTrustScoreProvider);
    ref.invalidate(promoterReviewsProvider);
    // Notifications & co-organisation
    ref.invalidate(notificationsProvider);
    ref.invalidate(coOrganizerInvitationsProvider);
    // Facturation (droits Pro/plafonds = permissions), modération, support
    ref.invalidate(entitlementsProvider);
    ref.invalidate(blockedUsersProvider);
    ref.invalidate(supportTicketsProvider);
    ref.invalidate(supportTicketProvider);
    ref.invalidate(supportUnreadProvider);

    // Suivi local du popup de boost (clés secure storage non liées au compte).
    unawaited(BoostPopupController.clearTracking());
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
