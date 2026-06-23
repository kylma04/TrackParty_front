import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/callkit_service.dart';

// Must be a top-level function annotated with @pragma for background isolate
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Push d'APPEL haute priorité → écran d'appel entrant plein écran (type
  // WhatsApp), même app en arrière-plan/tuée. Le reste rejoint le tray système.
  final data = message.data;
  final type = data['type'];
  if (type == 'call_invite') {
    await CallKitService.showIncoming(
      callId: (data['call_id'] ?? '').toString(),
      callType: (data['call_type'] ?? 'audio').toString(),
      callerName: (data['caller_name'] ?? 'Appel').toString(),
      roomId: (data['room_id'] ?? '').toString(),
      callerId: data['caller_id']?.toString(),
      callerAvatar: data['caller_avatar']?.toString(),
    );
  } else if (type == 'call_end') {
    await CallKitService.end((data['call_id'] ?? '').toString());
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('🔥 Firebase initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: TrackPartyApp()));
}
