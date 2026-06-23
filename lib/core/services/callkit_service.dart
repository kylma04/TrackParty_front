import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Écran d'appel entrant type WhatsApp (plein écran, sonnerie système),
/// même quand l'app est en arrière-plan ou tuée. Affiché depuis le handler
/// FCM background à la réception d'un push d'appel haute priorité.
class CallKitService {
  /// Affiche l'appel entrant natif. [extra] est renvoyé tel quel dans
  /// l'événement « accepté » → on y met tout le nécessaire pour décrocher.
  static Future<void> showIncoming({
    required String callId,
    required String callType,
    required String callerName,
    required String roomId,
    String? callerId,
    String? callerAvatar,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'TrackParty',
      avatar: (callerAvatar != null && callerAvatar.isNotEmpty) ? callerAvatar : null,
      handle: callType == 'video' ? 'Appel vidéo' : 'Appel audio',
      type: callType == 'video' ? 1 : 0,
      duration: 45000,
      textAccept: 'Répondre',
      textDecline: 'Refuser',
      extra: <String, dynamic>{
        'call_id': callId,
        'call_type': callType,
        'room_id': roomId,
        'caller_id': callerId ?? '',
        'caller_name': callerName,
        'caller_avatar': callerAvatar ?? '',
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#4F46E5',
        actionColor: '#22A865',
        incomingCallNotificationChannelName: 'Appels entrants',
        isShowFullLockedScreen: true,
        isImportant: true,
      ),
      ios: const IOSParams(handleType: 'generic', supportsVideo: true),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static Future<void> end(String callId) => FlutterCallkitIncoming.endCall(callId);

  static Future<void> endAll() => FlutterCallkitIncoming.endAllCalls();
}
