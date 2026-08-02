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

/// Un autre participant de l'appel (jamais moi-même) — DM (1 seul) ou appel
/// de groupe (jusqu'à MAX_GROUP_CALL_PARTICIPANTS - 1 côté backend).
class CallParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final MediaStream? remoteStream;
  /// true dès que la RTCPeerConnection avec ce participant est connectée
  /// (flux média en cours), false pendant que ça sonne/négocie encore.
  final bool connected;

  const CallParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.remoteStream,
    this.connected = false,
  });

  CallParticipant copyWith({
    String? displayName,
    String? avatarUrl,
    MediaStream? remoteStream,
    bool? connected,
  }) =>
      CallParticipant(
        userId: userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        remoteStream: remoteStream ?? this.remoteStream,
        connected: connected ?? this.connected,
      );
}

class CallState {
  final CallStatus status;
  final String? callId;
  final String? callType;
  final String? roomId;
  final bool isGroup;
  /// DM : nom/avatar du partenaire. Groupe sortant : nom/avatar du groupe.
  /// Groupe entrant : nom/avatar de la personne qui a démarré l'appel (seule
  /// identité que CallKit sait afficher nativement).
  final String? remoteUserName;
  final String? remoteUserAvatarUrl;
  /// Les AUTRES participants (jamais moi) — pour un DM, toujours 0 ou 1 élément.
  final List<CallParticipant> participants;
  final MediaStream? localStream;
  final bool micEnabled;
  final bool videoEnabled;
  final bool isFrontCamera;
  final bool speakerEnabled;

  const CallState({
    required this.status,
    this.callId,
    this.callType,
    this.roomId,
    this.isGroup = false,
    this.remoteUserName,
    this.remoteUserAvatarUrl,
    this.participants = const [],
    this.localStream,
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
    bool? isGroup,
    String? remoteUserName,
    String? remoteUserAvatarUrl,
    List<CallParticipant>? participants,
    MediaStream? localStream,
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
        isGroup: isGroup ?? this.isGroup,
        remoteUserName: remoteUserName ?? this.remoteUserName,
        remoteUserAvatarUrl: remoteUserAvatarUrl ?? this.remoteUserAvatarUrl,
        participants: participants ?? this.participants,
        localStream: localStream ?? this.localStream,
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

  // Une RTCPeerConnection par AUTRE participant (maillage P2P) — pour un DM
  // il n'y en a qu'une, exactement comme avant.
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  final Map<String, bool> _remoteDescSet = {};

  MediaStream? _localStream;
  bool _initiating = false;
  bool _cleaningUp = false;
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

  /// [invitees] : les AUTRES membres de la salle (DM : le partenaire seul ;
  /// groupe : jusqu'à 3 autres) — pré-remplit `state.participants` en
  /// "sonnerie" avant même qu'ils rejoignent le maillage WebRTC.
  Future<void> initiateCall({
    required String roomId,
    required String callType,
    required String remoteUserName,
    String? remoteUserAvatarUrl,
    bool isGroup = false,
    List<CallParticipant> invitees = const [],
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
        isGroup: isGroup,
        remoteUserName: remoteUserName,
        remoteUserAvatarUrl: remoteUserAvatarUrl,
        participants: invitees,
        localStream: stream,
        speakerEnabled: isVideo,
      );

      _startRingTimer();
      _playRing('sounds/ringback.wav'); // tonalité « ça sonne » pour l'appelant
      // Se connecter à la signalisation : les invités qui rejoignent déclenchent
      // `participant_joined`, auquel on répond en leur envoyant une offre (cf
      // `_onSignal`). Aucune offre n'est envoyée avant que quelqu'un rejoigne.
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

      // Roster complet (appel de groupe) : le payload d'invitation ne connaît
      // que l'appelant, pas les autres invités — on les récupère ici pour que
      // l'écran d'appel actif affiche les bons noms/avatars dès la connexion.
      if (s.isGroup) await _fetchAndMergeRoster(s.callId!);

      await _connectSignaling(s.callId!);
      _sendSignal({'type': 'call_accepted'});
    } catch (e) {
      debugPrint('📞 ❌ acceptCall a échoué: $e');
      await _cleanup();
      rethrow;
    }
  }

  Future<void> _fetchAndMergeRoster(String callId) async {
    if (!_dioReady) return;
    try {
      final resp = await _dio.get('chat/calls/$callId/').timeout(const Duration(seconds: 5));
      final list = (resp.data['participants'] as List)
          .map((e) => CallParticipant(
                userId: e['id'] as String,
                displayName: e['name'] as String,
                avatarUrl: e['avatar_url'] as String?,
              ))
          .toList();
      // Fusionne : garde le flux/état déjà connu pour un participant déjà présent.
      final existingById = {for (final p in state.participants) p.userId: p};
      final merged = list
          .map((p) => existingById[p.userId]?.copyWith(displayName: p.displayName, avatarUrl: p.avatarUrl) ?? p)
          .toList();
      stateNotifier.value = state.copyWith(participants: merged);
    } catch (e) {
      debugPrint('📞 ⚠️ Roster de l\'appel injoignable: $e');
    }
  }

  // ─── Quitter l'appel (annuler / refuser / raccrocher — toujours réussit,
  // fire & forget depuis l'UI) ───────────────────────────────────────────────

  Future<void> leaveCall() async {
    if (_cleaningUp) return;

    final callId = state.callId;

    // Bip de fin dès qu'on raccroche un appel en cours (sortant ou connecté).
    if (state.status != CallStatus.idle) _playEndTone();

    // 1. Notifier le serveur (non bloquant) — couvre annuler/refuser/raccrocher,
    // que l'appel sonne encore ou ait déjà été rejoint.
    unawaited(
      _dio.post('chat/calls/${callId ?? ''}/leave/')
          .timeout(const Duration(seconds: 4))
          .catchError((_) => Response(requestOptions: RequestOptions())),
    );

    // 2. Signal WS (pour les pairs déjà connectés au maillage)
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
    bool isGroup = false,
    String? callerName,
    String? callerAvatarUrl,
  }) {
    if (state.status != CallStatus.idle) return;
    stateNotifier.value = CallState(
      status: CallStatus.incoming,
      callId: callId,
      callType: callType,
      roomId: roomId,
      isGroup: isGroup,
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
      if (state.status == CallStatus.outgoing) leaveCall();
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
      final sender = data['sender'] as String?;
      switch (data['type'] as String?) {
        case 'participant_joined':
          final peerId = (data['user_id'] ?? sender) as String?;
          if (peerId != null) await _offerTo(peerId);
        case 'offer':
          if (sender != null) await _handleOffer(sender, data);
        case 'answer':
          if (sender != null) await _handleAnswer(sender, data);
        case 'ice_candidate':
          if (sender != null) await _handleIceCandidate(sender, data);
        case 'call_accepted':
          // Au moins un invité a décroché : couper la tonalité de retour et
          // afficher « Connexion… » le temps que le média WebRTC s'établisse.
          if (state.status == CallStatus.outgoing) {
            await _stopRing();
            stateNotifier.value = state.copyWith(status: CallStatus.connecting);
          }
        case 'hangup':
          final peerId = (data['user_id'] ?? sender) as String?;
          if (peerId != null) await _removePeer(peerId);
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

  // ─── WebRTC (maillage : une RTCPeerConnection par autre participant) ──────

  Future<RTCPeerConnection> _ensurePeerConnection(String peerId) async {
    final existing = _peerConnections[peerId];
    if (existing != null) return existing;

    final pc = await createPeerConnection(await _getIceConfig());
    _localStream?.getTracks().forEach((t) => pc.addTrack(t, _localStream!));
    _peerConnections[peerId] = pc;
    _remoteDescSet[peerId] = false;
    _pendingCandidates[peerId] = [];

    pc.onIceCandidate = (c) {
      if (c.candidate?.isNotEmpty == true) {
        _sendSignal({'type': 'ice_candidate', 'target': peerId, 'candidate': c.toMap()});
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _updateParticipant(peerId, remoteStream: event.streams.first);
    };

    pc.onConnectionState = (s) {
      debugPrint('📞 PeerConnection[$peerId] state: $s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _stopRing(); // au moins un pair connecté → plus de sonnerie/tonalité
        _updateParticipant(peerId, connected: true);
        if (state.status != CallStatus.active) {
          stateNotifier.value = state.copyWith(status: CallStatus.active);
        }
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // 'failed' juste après la tentative = ICE n'a pas pu traverser le NAT
        // (manque un TURN). 'disconnected' = perte réseau en cours d'appel.
        debugPrint('📞 ❌ Connexion WebRTC vers $peerId $s '
            '(TURN configuré: ${Env.turnConfigured})');
        _removePeer(peerId);
      }
    };

    return pc;
  }

  /// Insère ou met à jour l'entrée d'un participant dans `state.participants`
  /// (créé à la volée s'il n'était pas déjà connu — ex. rejoint sans figurer
  /// dans la liste d'invités initiale).
  void _updateParticipant(String peerId, {MediaStream? remoteStream, bool? connected}) {
    final list = List<CallParticipant>.from(state.participants);
    final i = list.indexWhere((p) => p.userId == peerId);
    if (i >= 0) {
      list[i] = list[i].copyWith(remoteStream: remoteStream, connected: connected);
    } else {
      list.add(CallParticipant(
        userId: peerId,
        displayName: 'Participant',
        remoteStream: remoteStream,
        connected: connected ?? false,
      ));
    }
    stateNotifier.value = state.copyWith(participants: list);
  }

  /// Je suis déjà connecté au maillage et [peerId] vient de le rejoindre
  /// (`participant_joined`) → je lui envoie l'offre (lui ne fait que répondre).
  Future<void> _offerTo(String peerId) async {
    final pc = await _ensurePeerConnection(peerId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _sendSignal({'type': 'offer', 'target': peerId, 'sdp': offer.sdp, 'sdpType': offer.type});
  }

  Future<void> _handleOffer(String sender, Map<String, dynamic> data) async {
    final pc = await _ensurePeerConnection(sender);
    await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
    _remoteDescSet[sender] = true;
    await _flushPendingCandidates(sender);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _sendSignal({'type': 'answer', 'target': sender, 'sdp': answer.sdp, 'sdpType': answer.type});
  }

  Future<void> _handleAnswer(String sender, Map<String, dynamic> data) async {
    final pc = _peerConnections[sender];
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdpType']));
    _remoteDescSet[sender] = true;
    await _flushPendingCandidates(sender);
  }

  Future<void> _handleIceCandidate(String sender, Map<String, dynamic> data) async {
    final m = data['candidate'] as Map<String, dynamic>?;
    if (m == null) return;
    final c = RTCIceCandidate(m['candidate'], m['sdpMid'], m['sdpMLineIndex']);
    final pc = await _ensurePeerConnection(sender);
    if (_remoteDescSet[sender] == true) {
      await pc.addCandidate(c);
    } else {
      (_pendingCandidates[sender] ??= []).add(c);
    }
  }

  Future<void> _flushPendingCandidates(String peerId) async {
    final pc = _peerConnections[peerId];
    final pending = _pendingCandidates[peerId];
    if (pc == null || pending == null) return;
    for (final c in pending) {
      await pc.addCandidate(c);
    }
    pending.clear();
  }

  /// [peerId] a raccroché/refusé/été déconnecté : ferme sa RTCPeerConnection
  /// et le retire de la liste. Si plus aucun participant ne reste, l'appel
  /// est terminé pour moi aussi (sauf s'il sonne encore côté serveur : le
  /// backend décide de la fin réelle, mais côté client un maillage vide n'a
  /// plus de raison d'occuper l'écran d'appel actif).
  Future<void> _removePeer(String peerId) async {
    final pc = _peerConnections.remove(peerId);
    _remoteDescSet.remove(peerId);
    _pendingCandidates.remove(peerId);
    try { await pc?.close(); } catch (_) {}

    final remaining = state.participants.where((p) => p.userId != peerId).toList();
    if (remaining.isEmpty) {
      if (state.status != CallStatus.idle) _playEndTone();
      await _cleanup();
    } else {
      stateNotifier.value = state.copyWith(participants: remaining);
    }
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

    for (final pc in _peerConnections.values) {
      try { await pc.close().timeout(_kCleanupTimeout); } catch (_) {}
    }
    _peerConnections.clear();
    _remoteDescSet.clear();
    _pendingCandidates.clear();

    _localStream?.getTracks().forEach((t) => t.stop());
    try { await _localStream?.dispose().timeout(_kCleanupTimeout); } catch (_) {}
    _localStream = null;

    _initiating = false;
    _cleaningUp = false;
  }
}
