import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/ticket_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/call_readiness_service.dart';
import 'core/services/call_service.dart';
import 'core/services/user_channel_service.dart';
import 'theme/app_theme.dart';

/// Écrans (sans paramètre) qu'une annonce admin `broadcast` peut cibler.
/// Toute autre valeur de `screen` est ignorée → on ouvre les notifications.
const Set<String> _allowedBroadcastScreens = {
  'notifications',
  'feed',
  'my-events',
  'my-tickets',
  'saved-events',
  'plans',
  'help',
  'support',
  'settings',
};

class TrackPartyApp extends ConsumerStatefulWidget {
  const TrackPartyApp({super.key});

  @override
  ConsumerState<TrackPartyApp> createState() => _TrackPartyAppState();
}

class _TrackPartyAppState extends ConsumerState<TrackPartyApp> {
  @override
  void initState() {
    super.initState();
    _setupFcmListeners();
    _setupCallService();
    _setupCallListener();
    _setupCallKitListener();
    _requestCallPermissions();
    _setupDeepLinks();
  }

  /// Autorisations nécessaires pour qu'un appel entrant s'affiche en plein écran
  /// même app en arrière-plan / tuée / écran verrouillé.
  /// NB : sur certains constructeurs (Xiaomi/MIUI, Oppo/ColorOS, Samsung…), le
  /// réveil d'un appel quand l'app est TOTALEMENT fermée exige en plus que
  /// l'utilisateur retire l'app de l'optimisation batterie — non demandable de
  /// façon fiable par programme (restriction OS), à documenter dans l'onboarding.
  Future<void> _requestCallPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterCallkitIncoming.requestNotificationPermission({
        'rationaleMessagePermission':
            'TrackParty a besoin des notifications pour t\'avertir des appels et messages.',
        'postNotificationMessageRequired':
            'Autorise les notifications dans les réglages pour recevoir les appels.',
      });
      // Android 14+ : autorisation d'affichage plein écran (full-screen intent).
      final canFull = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (canFull == false) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (_) {}
  }

  /// Réagit aux actions de l'écran d'appel natif (CallKit) : décrocher / refuser.
  void _setupCallKitListener() {
    FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;
      final body = event.body;
      final extra = (body is Map && body['extra'] is Map)
          ? Map<String, dynamic>.from(body['extra'] as Map)
          : <String, dynamic>{};
      final callId = (extra['call_id'] ?? '').toString();
      final callType = (extra['call_type'] ?? 'audio').toString();
      final roomId = (extra['room_id'] ?? '').toString();
      final callerName = extra['caller_name']?.toString();
      final avatar = extra['caller_avatar']?.toString();

      switch (event.event) {
        case Event.actionCallAccept:
          if (callId.isEmpty) return;
          CallService().notifyIncomingCall(
            callId: callId, callType: callType, roomId: roomId,
            callerName: callerName,
            callerAvatarUrl: (avatar?.isNotEmpty ?? false) ? avatar : null,
          );
          try { await CallService().acceptCall(); } catch (_) {}
        case Event.actionCallDecline:
          if (callId.isEmpty) return;
          CallService().notifyIncomingCall(
            callId: callId, callType: callType, roomId: roomId,
            callerName: callerName,
          );
          await CallService().rejectCall();
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          if (CallService().state.status == CallStatus.incoming) {
            await CallService().rejectCall();
          }
        default:
          break;
      }
    });
  }

  void _setupCallService() {
    // Injecter le Dio dans le CallService singleton
    final dio = ref.read(dioProvider);
    CallService().init(dio);
  }

  void _setupCallListener() {
    // Connecter le canal utilisateur dès que l'auth est confirmée
    ref.listenManual(authNotifierProvider, (_, next) {
      next.whenData((state) {
        if (state is AuthAuthenticated) {
          UserChannelService().connect();
          // Uniquement pour un compte vérifié : sinon la redirection force
          // /verify-email et le prompt unique serait « consommé » sans s'afficher.
          if (state.user.isVerified) _maybePromptCallReadiness();
        } else {
          UserChannelService().disconnect();
        }
      });
    });

    // Afficher l'écran appel entrant quand le statut passe à 'incoming'
    CallService().stateNotifier.addListener(_onCallStateChanged);
  }

  /// Après login : propose UNE fois l'écran « Appels en arrière-plan » si le
  /// téléphone n'est pas encore exempté d'optimisation batterie (Android, et
  /// tant que l'utilisateur n'a pas désactivé le rappel).
  Future<void> _maybePromptCallReadiness() async {
    if (!await CallReadinessService.shouldAutoPrompt()) return;
    await CallReadinessService.markAutoPrompted();
    // Laisser la redirection post-login atterrir (sur /feed) avant de pousser.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    ref.read(routerProvider).push('/calls/background');
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    final s = CallService().state;
    if (s.status == CallStatus.incoming) {
      final router = ref.read(routerProvider);
      router.push('/call/incoming');
    }
  }

  @override
  void dispose() {
    CallService().stateNotifier.removeListener(_onCallStateChanged);
    super.dispose();
  }

  // Canal natif Android pour afficher une notif locale au premier plan.
  static const _androidNotif = MethodChannel('trackparty/notifications');

  /// Android : FCM n'affiche PAS les notifications quand l'app est au premier
  /// plan → on poste une notif locale (bannière + son) nous-mêmes. iOS est géré
  /// par `setForegroundNotificationPresentationOptions` (cf main.dart).
  void _showForegroundNotification(RemoteMessage message) {
    if (!Platform.isAndroid) return;
    final n = message.notification;
    if (n == null) return; // messages data-only (appels, contrôle) → pas de bannière
    _androidNotif.invokeMethod('show', {
      'title': n.title ?? 'TrackParty',
      'body': n.body ?? '',
    }).catchError((_) {});
  }

  void _setupFcmListeners() {
    // Foreground: app is open, message arrives → notif locale + refresh in-app
    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(message);
      ref.invalidate(notificationsProvider);
      _maybeRefreshUser(message);
      _maybeRefreshTickets(message);
    });

    // Background: user taps a notification from the system tray → navigate + refresh
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      ref.invalidate(notificationsProvider);
      _maybeRefreshUser(message);
      _maybeRefreshTickets(message);
      _navigateFromMessage(message);
    });

    // Terminated: user tapped the notification that launched the app
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      ref.invalidate(notificationsProvider);
      _maybeRefreshUser(message);
      _maybeRefreshTickets(message);
      // Use addPostFrameCallback to ensure the router is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromMessage(message);
      });
    });
  }

  /// Resynchronise l'utilisateur en live quand une notification le concernant
  /// arrive (ex. décision de vérification d'identité par l'admin OU par n8n).
  /// Les écrans qui observent `authNotifierProvider` (profil, vérification) se
  /// mettent alors à jour immédiatement, sans quitter l'app.
  void _maybeRefreshUser(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    if (category == 'identity' || type.startsWith('identity_')) {
      ref.read(authNotifierProvider.notifier).refreshUser();
    }
  }

  /// Quand un push lié aux billets arrive (transfert reçu, promotion liste
  /// d'attente…), on purge le cache des billets : le destinataire d'un transfert
  /// doit récupérer le NOUVEAU token, sinon son QR (ancien token) échoue au scan.
  void _maybeRefreshTickets(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    if (type == 'ticket_transferred' || type == 'waitlist_promoted') {
      ref.invalidate(myTicketsProvider);
      final eventId = data['event_id'];
      if (eventId is String && eventId.isNotEmpty) {
        ref.invalidate(myTicketProvider(eventId));
      }
    }
  }

  void _setupDeepLinks() async {
    final appLinks = AppLinks();

    // App lancée depuis un deeplink (cold start)
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink(initial));
      }
    } catch (_) {}

    // App déjà en cours (foreground / background)
    appLinks.uriLinkStream.listen(_handleDeepLink, onError: (_) {});
  }

  void _handleDeepLink(Uri uri) {
    if (!mounted) return;
    final router = ref.read(routerProvider);
    final segments = uri.pathSegments;

    // trackparty://event/{id}  ou  https://trackparty.ci/event/{id}
    if (segments.length >= 2 && segments[0] == 'event') {
      router.push('/event/${segments[1]}');
    }
    // trackparty://event/{id}/scan
    else if (segments.length >= 3 && segments[0] == 'event' && segments[2] == 'scan') {
      router.push('/event/${segments[1]}/scan');
    }
  }

  void _navigateFromMessage(RemoteMessage message) {
    final router = ref.read(routerProvider);
    final data   = message.data;
    final type   = data['type'] as String?;

    switch (type) {
      case 'new_message':
      case 'missed_call':
        final roomId = data['room_id'];
        if (roomId != null) { router.push('/chat/$roomId'); return; }

      case 'co_org_invite':
        router.push('/co-organizer-invitations'); return;

      case 'invitation':
      case 'invitation_accepted':
        router.push('/invitations'); return;

      case 'broadcast':
        // Annonce admin : ouvre l'écran ciblé si fourni ET autorisé, sinon les notifs.
        // Whitelist : on ne route jamais vers une route arbitraire issue du payload.
        final screen = (data['screen'] ?? '').toString();
        router.push(
          _allowedBroadcastScreens.contains(screen) ? '/$screen' : '/notifications',
        );
        return;

      case 'new_follower':
        final followerId = data['follower_id'];
        if (followerId != null) { router.push('/promoter/$followerId'); return; }
        router.push('/notifications'); return;

      case 'co_org_accepted':
        final eventId = data['event_id'];
        if (eventId != null) {
          router.push('/event/$eventId/dashboard', extra: {'title': ''});
          return;
        }

      case 'ticket_transferred':
      case 'waitlist_promoted':
        router.push('/my-tickets'); return;
    }

    // Types avec event_id : event_reminder, event_updated, event_cancelled,
    // participation_confirmed, waitlist_promoted, new_review, review_reply, review_request, checkin_review
    final eventId = data['event_id'];
    if (eventId != null) {
      final screen = data['screen'] as String?;
      if (screen == 'event_rate') {
        router.push('/event/$eventId/rate');
      } else {
        router.push('/event/$eventId');
      }
      return;
    }

    router.push('/notifications');
  }

  @override
  Widget build(BuildContext context) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'TrackParty',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
    );
  }
}
