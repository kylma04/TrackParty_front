import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/notification_provider.dart';
import 'core/router/app_router.dart';
import 'theme/app_theme.dart';

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
  }

  void _setupFcmListeners() {
    // Foreground: app is open, message arrives → refresh the in-app list silently
    FirebaseMessaging.onMessage.listen((_) {
      ref.invalidate(notificationsProvider);
    });

    // Background: user taps a notification from the system tray → navigate + refresh
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      ref.invalidate(notificationsProvider);
      _navigateFromMessage(message);
    });

    // Terminated: user tapped the notification that launched the app
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      ref.invalidate(notificationsProvider);
      // Use addPostFrameCallback to ensure the router is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromMessage(message);
      });
    });
  }

  void _navigateFromMessage(RemoteMessage message) {
    final router = ref.read(routerProvider);
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'new_message') {
      final roomId = data['room_id'];
      if (roomId != null) {
        router.push('/chat/$roomId');
        return;
      }
    }

    if (type != null && data['event_id'] != null) {
      router.push('/event/${data['event_id']}');
      return;
    }

    router.push('/notifications');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TrackParty',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
