import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import 'token_storage.dart';

const _kRingTimeout    = Duration(seconds: 60);
const _kCleanupTimeout = Duration(seconds: 3);

enum CallStatus { idle, outgoing, incoming, connecting, active }

class CallState {
  final CallStatus status;
  final String? callId;
  final String? callType;
  final String? roomId;
  final String? remoteUserName;
  final String? remoteUserAvatarUrl;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final bool micEnabled;
  final bool videoEnabled;
  final bool isFrontCamera;
  final bool speakerEnabled;

  const CallState({
    required this.status,
    this.callId,
    this.callType,
    this.roomId,
    this.remoteUserName,
    this.remoteUserAvatarUrl,
    this.localStream,
    this.remoteStream,
    this.micEnabled = true,
    this.videoEnabled = true,
    this.isFrontCamera = true,
    this.speakerEnabled = false,
  });

  static const idle = CallState(status: CallStatus.idle);

  CallState copyWith({
    CallStatus? status,
    String? callId,
    String? callType,
    String? roomId,
    String? remoteUserName,
    String? remoteUserAvatarUrl,
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool? micEnabled,
    bool? videoEnabled,
    bool? isFrontCamera,
    bool? speakerEnabled,
  }) =>
      CallState(
        status: status ?? this.status,
        callId: callId ?? this.callId,
        callType: callType ?? this.callType,
        roomId: roomId ?? this.roomId,
        remoteUserName: remoteUserName ?? this.remoteUserName,
        remoteUserAvatarUrl: remoteUserAvatarUrl ?? this.remoteUserAvatarUrl,
        localStream: localStream ?? this.localStream,
        remoteStream: remoteStream ?? this.remoteStream,
        micEnabled: micEnabled ?? this.micEnabled,
        videoEnabled: videoEnabled ?? this.videoEnabled,
        isFrontCamera: isFrontCamera ?? this.isFrontCamera,
        speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      );
}

class CallService {
  static final CallService _instance = CallService._();
  factory CallService() => _instance;
  CallService._();

  late Dio _dio;
  bool _dioReady = false;

  void init(Dio dio) {
    _dio = dio;
    _dioReady = true;
  }

  final ValueNotifier<CallState> stateNotifier = ValueNotifier(CallState.idle);
  CallState get state => stateNotifier.value;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _isOfferer = false;
  bool _initiating = false;
  bool _cleaningUp = false;
  bool _remoteDescSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];
  Timer? _ringTimer;
  WebSocketChannel? _sigWs;
  StreamSubscription? _sigSub;

  // Lecteur de sonnerie (entrante) / tonalité de retour (sortante).
  final AudioPlayer _ringPlayer = AudioPlayer();
  bool _ringing = false;

  // true quand la sonnerie active est celle du système (appel entrant), false
  // quand c'est la tonalité de retour asset (appel sortant).
  bool _systemRing = false;

  Future<void> _playRing(String asset) async {
    try {
      _ringing = true;
      _systemRing = false;
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource(asset), volume: 1.0);
    } catch (_) {}
  }

  /// Sonnerie d'appel ENTRANT = sonnerie par défaut du téléphone (comme un
  /// vrai appel), pas un asset. En arrière-plan/tuée, c'est CallKit qui sonne
  /// (`system_ringtone_default`) ; ici on couvre le cas app au 1er plan.
  Future<void> _playSystemRingtone() async {
    try {
      _ringing = true;
      _systemRing = true;
      FlutterRingtonePlayer().playRingtone(looping: true, asAlarm: false);
    } catch (_) {}
  }

  Future<void> _stopRing() async {
    if (!_ringing) return;
    _ringing = false;
    if (_systemRing) {
      try { FlutterRingtonePlayer().stop(); } catch (_) {}
    } else {
      try { await _ringPlayer.stop(); } catch (_) {}
    }
  }

  // Lecteur dédié au bip de fin : persistant et SÉPARÉ de `_ringPlayer` pour ne
  // pas être coupé par `_stopRing()` pendant le `_cleanup()`.
  final AudioPlayer _endPlayer = AudioPlayer();

  /// Bip de fin d'appel (joué une fois).
  Future<void> _playEndTone() async {
    try {
      await _endPlayer.stop();
      await _endPlayer.setReleaseMode(ReleaseMode.stop);
      await _endPlayer.play(AssetSource('sounds/call_end.wav'), volume: 1.0);
    } catch (_) {}
  }

  // Config ICE récupérée du backend (TURN éphémère Cloudflare), mise en cache
  // jusqu'à ~80% du TTL pour éviter un identifiant périmé en plein appel.
  Map<String, dynamic>? _cachedIceConfig;
  DateTime? _iceConfigExpiry;

  /// Récupère la config ICE (STUN + TURN) depuis le backend, qui génère des
  /// identifiants TURN éphémères. Sans TURN, les appels échouent sur réseau
  /// mobile à NAT strict. Repli sur la config statique (dart-define) si le
  /// backend est injoignable ou pas encore initialisé (ex: accept CallKit à froid).
  Future<Map<String, dynamic>> _getIceConfig() async {
    final cached = _cachedIceConfig;
    final expiry = _iceConfigExpiry;
    if (cached != null && expiry != null && DateTime.now().isBefore(expiry)) {
      return cached;
    }
    if (!_dioReady) return _staticIceConfig;
    try {
      final resp = await _dio
          .get('chat/calls/turn-credentials/')
          .timeout(const Duration(seconds: 6));
      final servers = (resp.data['iceServers'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final ttl = (resp.data['ttl'] as num?)?.toInt() ?? 3600;
      final config = {'iceServers': servers, 'sdpSemantics': 'unified-plan'};
      _cachedIceConfig  = config;
      _iceConfigExpiry  = DateTime.now().add(Duration(seconds: (ttl * 0.8).round()));
      final hasTurn = servers.any((s) {
        final u = s['urls'];
        final str = u is List ? u.join(',') : u.toString();
        return str.contains('turn:') || str.contains('turns:');
      });
      debugPrint('📞 Config ICE backend: ${servers.length} serveur(s) — TURN: $hasTurn');
      return config;
    } catch (e) {
      debugPrint('📞 ⚠️ turn-credentials injoignable → repli statique: $e');
      return _staticIceConfig;
    }
  }

  // Repli local : STUN Google (P2P direct) + TURN si fourni via dart-define.
  // Utilisé seulement si le backend est injoignable — sans TURN, les appels
  // coupent sur les réseaux mobiles à NAT strict.
  static Map<String, dynamic> get _staticIceConfig {
    final servers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];
    if (Env.turnConfigured) {
      servers.add({
        'urls': Env.turnUrl,
        if (Env.turnUsername.isNotEmpty)   'username':   Env.turnUsername,
        if (Env.turnCredential.isNotEmpty) 'credential': Env.turnCredential,
      });
    } else {
      debugPrint('📞 ⚠️ Aucun TURN statique (STUN seul) — les appels peuvent '
          'couper sur réseau mobile à NAT strict.');
    }
    return {'iceServers': servers, 'sdpSemantics': 'unified-plan'};
  }

  // ─── Appelant : initier ───────────────────────────────────────────────────

  Future<void> initiateCall({
    required String roomId,
    required String callType,
    required String remoteUserName,
    String? remoteUserAvatarUrl,
  }) async {
    if (state.status != CallStatus.idle || _initiating) {
      throw Exception('Appel déjà en cours.');
    }
    _initiating = true;

    try {
      if (!_dioReady) throw Exception('CallService non initialisé.');

      final stream = await _getLocalStream(callType);
      _localStream = stream;

      final response = await _dio.post('chat/calls/', data: {
        'room_id':   roomId,
        'call_type': callType,
      });
      final callId = response.data['call_id'] as String;

      final isVideo = callType == 'video';
      if (isVideo) Helper.setSpeakerphoneOn(true);
      stateNotifier.value = CallState(
        status: CallStatus.outgoing,
        callId: callId,
        callType: callType,
        roomId: roomId,
        remoteUserName: remoteUserName,
        remoteUserAvatarUrl: remoteUserAvatarUrl,
        localStream: stream,
        speakerEnabled: isVideo,
      );

      _isOfferer = true;
      _startRingTimer();
      _playRing('sounds/ringback.wav'); // tonalité « ça sonne » pour l'appelant
      // La peer connection doit exister AVANT de rejoindre la signalisation :
      // si l'appelé rejoint dans la foulée, son `participant_joined` déclenche
      // l'envoi de l'offre, or `_createAndSendOffer` exige `_pc != null`. Même
      // logique de sûreté que côté `acceptCall`.
      await _setupPeerConnection();
      await _connectSignaling(callId);
    } catch (e) {
      // Réinitialiser complètement si quelque chose échoue (ex: getUserMedia
      // refusé = permission micro/caméra non accordée → l'appel coupe aussitôt).
      debugPrint('📞 ❌ initiateCall a échoué: $e');
      await _cleanup();
      rethrow;
    }
  }

  // ─── Appelé : accepter ────────────────────────────────────────────────────

  Future<void> acceptCall() async {
    final s = state;
    if (s.status != CallStatus.incoming || s.callId == null) return;
    await _stopRing(); // l'appelé décroche → on coupe la sonnerie
    // Feedback immédiat : « Connexion… » pendant toute la négociation WebRTC
    // (setup PC + signalisation + ICE), au lieu d'un bouton figé sans retour.
    stateNotifier.value = s.copyWith(status: CallStatus.connecting);

    try {
      final stream = await _getLocalStream(s.callType ?? 'audio');
      _localStream = stream;
      final isVideo = (s.callType ?? 'audio') == 'video';
      if (isVideo) Helper.setSpeakerphoneOn(true);
      // state (pas s) pour conserver le statut `connecting` déjà posé ci-dessus.
      stateNotifier.value = state.copyWith(localStream: stream, speakerEnabled: isVideo);

      _isOfferer = false;
      // IMPORTANT : la peer connection doit être PRÊTE avant de rejoindre la
      // signalisation. Sinon, en rejoignant, le serveur prévient l'appelant
      // (participant_joined) qui envoie son offre immédiatement — et si _pc
      // n'existe pas encore, l'offre est perdue → l'appel ne décroche jamais.
      await _setupPeerConnection();
      await _connectSignaling(s.callId!);
      _sendSignal({'type': 'call_accepted'});
    } catch (e) {
      debugPrint('📞 ❌ acceptCall a échoué: $e');
      await _cleanup();
      rethrow;
    }
  }

  // ─── Appelé : refuser ─────────────────────────────────────────────────────

  Future<void> rejectCall() async {
    final callId = state.callId;
    await _cleanup(); // Reset state immédiatement
    if (callId == null) return;
    try {
      await _dio.post('chat/calls/$callId/reject/')
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ─── Raccrocher (toujours réussit — fire & forget depuis l'UI) ───────────

  Future<void> hangup() async {
    if (_cleaningUp) return;

    final callId = state.callId;

    // Bip de fin dès qu'on raccroche un appel en cours (sortant ou connecté).
    if (state.status != CallStatus.idle) _playEndTone();

    // 1. Notifier le serveur (non bloquant)
    unawaited(
      _dio.post('chat/calls/${callId ?? ''}/cancel/')
          .timeout(const Duration(seconds: 4))
          .catchError((_) => Response(requestOptions: RequestOptions())),
    );

    // 2. Signal WS
    _sendSignal({'type': 'hangup'});

    // 3. Cleanup (réinitialise l'état → déclenche pop dans les écrans)
    await _cleanup();
  }

  // ─── Contrôles ────────────────────────────────────────────────────────────

  void toggleMic() {
    final track = _localStream?.getAudioTracks().firstOrNull;
    if (track == null) return;
    final next = !state.micEnabled;
    track.enabled = next;
    stateNotifier.value = state.copyWith(micEnabled: next);
  }

  void toggleVideo() {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track == null) return;
    final next = !state.videoEnabled;
    track.enabled = next;
    stateNotifier.value = state.copyWith(videoEnabled: next);
  }

  Future<void> switchCamera() async {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track == null) return;
    await Helper.switchCamera(track);
    stateNotifier.value = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  void toggleSpeaker() {
    final next = !state.speakerEnabled;
    Helper.setSpeakerphoneOn(next);
    stateNotifier.value = state.copyWith(speakerEnabled: next);
  }

  // ─── Appel entrant ────────────────────────────────────────────────────────

  void notifyIncomingCall({
    required String callId,
    required String callType,
    required String roomId,
    String? callerName,
    String? callerAvatarUrl,
  }) {
    if (state.status != CallStatus.idle) return;
    stateNotifier.value = CallState(
      status: CallStatus.incoming,
      callId: callId,
      callType: callType,
      roomId: roomId,
      remoteUserName: callerName,
      remoteUserAvatarUrl: callerAvatarUrl,
    );
    _playSystemRingtone(); // sonnerie du téléphone pour l'appelé
  }

  void cancelIncomingCall(String callId) {
    if (state.status == CallStatus.incoming && state.callId == callId) {
      _cleanup();
    }
  }

  // ─── Timer sonnerie ───────────────────────────────────────────────────────

  void _startRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = Timer(_kRingTimeout, () {
      if (state.status == CallStatus.outgoing) hangup();
    });
  }

  // ─── Signalisation ────────────────────────────────────────────────────────

  Future<void> _connectSignaling(String callId) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Non authentifié');
    final uri = Uri.parse('${Env.wsBaseUrl}/call/$callId/?token=$token');
    debugPrint('📞 Signaling: connexion à $uri');
    _sigWs = WebSocketChannel.connect(uri);
    await _sigWs!.ready; // lève si le handshake échoue (403, DNS) → remonte au catch appelant
    _sigSub = _sigWs!.stream.listen(
      _onSignal,
      onDone:  _onSignalingClosed,
      onError: (e) {
        debugPrint('📞 ❌ Signaling erreur: $e');
        _cleanup();
      },
    );
  }

  void _onSignal(dynamic raw) async {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (data['type'] as String?) {
        case 'participant_joined':
          if (_isOfferer && _pc != null) await _createAndSendOffer();
        case 'offer':
          if (!_isOfferer) await _handleOffer(data);
        case 'answer':
          if (_isOfferer) await _handleAnswer(data);
        case 'call_accepted':
          // L'appelé a décroché : couper la tonalité de retour et afficher
          // « Connexion… » le temps que le média WebRTC s'établisse.
          if (_isOfferer && state.status == CallStatus.outgoing) {
            await _stopRing();
            stateNotifier.value = state.copyWith(status: CallStatus.connecting);
          }
        case 'ice_candidate':
          await _handleIceCandidate(data);
        case 'hangup':
          // L'interlocuteur a raccroché : bip de fin si un appel était en cours.
          if (state.status != CallStatus.idle) _playEndTone();
          await _cleanup();
        case 'call_rejected':
          await _cleanup();
      }
    } catch (_) {}
  }

  void _onSignalingClosed() {
    // Code de close utile au diagnostic : 4001 = token invalide/expiré ou user
    // bloqué ; 4003 = pas participant de l'appel ; 1006/null = coupure réseau.
    debugPrint('📞 Signaling fermé: code=${_sigWs?.closeCode} '
        'reason=${_sigWs?.closeReason}');
    if (state.status != CallStatus.idle) _cleanup();
  }

  // ─── WebRTC ───────────────────────────────────────────────────────────────

  Future<void> _setupPeerConnection() async {
    _pc = await createPeerConnection(await _getIceConfig());
    _localStream?.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

    _pc!.onIceCandidate = (c) {
      if (c.candidate?.isNotEmpty == true) {
        _sendSignal({'type': 'ice_candidate', 'candidate': c.toMap()});
      }
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        stateNotifier.value = state.copyWith(remoteStream: event.streams.first);
      }
    };

    _pc!.onConnectionState = (s) {
      debugPrint('📞 PeerConnection state: $s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _stopRing(); // connecté → plus de sonnerie/tonalité
        stateNotifier.value = state.copyWith(status: CallStatus.active);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // 'failed' juste après la tentative = ICE n'a pas pu traverser le NAT
        // (manque un TURN). 'disconnected' = perte réseau en cours d'appel.
        debugPrint('📞 ❌ Connexion WebRTC $s → fin de l\'appel '
            '(TURN configuré: ${Env.turnConfigured})');
        _cleanup();
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    if (_pc == null) return;
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _sendSignal({'type': 'offer', 'sdp': offer.sdp, 'sdpType': offer.type});
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    if (_pc == null) return;
    await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
    _remoteDescSet = true;
    await _flushPendingCandidates();
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _sendSignal({'type': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    if (_pc == null) return;
    await _pc!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
    _remoteDescSet = true;
    await _flushPendingCandidates();
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    final m = data['candidate'] as Map<String, dynamic>?;
    if (m == null) return;
    final c = RTCIceCandidate(m['candidate'], m['sdpMid'], m['sdpMLineIndex']);
    if (_remoteDescSet && _pc != null) {
      await _pc!.addCandidate(c);
    } else {
      _pendingCandidates.add(c);
    }
  }

  Future<void> _flushPendingCandidates() async {
    if (_pc == null) return;
    for (final c in _pendingCandidates) {
      await _pc!.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  void _sendSignal(Map<String, dynamic> data) {
    try { _sigWs?.sink.add(jsonEncode(data)); } catch (_) {}
  }

  Future<MediaStream> _getLocalStream(String callType) =>
      navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': callType == 'video'
            ? {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}}
            : false,
      });

  // ─── Nettoyage ────────────────────────────────────────────────────────────

  Future<void> _cleanup() async {
    if (_cleaningUp) return;
    _cleaningUp = true;

    _ringTimer?.cancel(); _ringTimer = null;
    await _stopRing();

    // Réinitialiser l'état en PREMIER → les écrans peuvent naviguer immédiatement
    stateNotifier.value = CallState.idle;

    // Nettoyage avec timeouts pour ne pas bloquer
    _sigSub?.cancel(); _sigSub = null;
    try { await _sigWs?.sink.close().timeout(_kCleanupTimeout); } catch (_) {}
    _sigWs = null;

    try { await _pc?.close().timeout(_kCleanupTimeout); } catch (_) {}
    _pc = null;

    _localStream?.getTracks().forEach((t) => t.stop());
    try { await _localStream?.dispose().timeout(_kCleanupTimeout); } catch (_) {}
    _localStream = null;

    _remoteDescSet = false;
    _pendingCandidates.clear();
    _isOfferer = false;
    _initiating = false;
    _cleaningUp = false;
  }
}
