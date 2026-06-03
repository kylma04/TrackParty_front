import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import 'token_storage.dart';

const _kRingTimeout    = Duration(seconds: 60);
const _kCleanupTimeout = Duration(seconds: 3);

enum CallStatus { idle, outgoing, incoming, active }

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

  static const _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

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

      stateNotifier.value = CallState(
        status: CallStatus.outgoing,
        callId: callId,
        callType: callType,
        roomId: roomId,
        remoteUserName: remoteUserName,
        remoteUserAvatarUrl: remoteUserAvatarUrl,
        localStream: stream,
      );

      _isOfferer = true;
      _startRingTimer();
      await _connectSignaling(callId);
      await _setupPeerConnection();
    } catch (e) {
      // Réinitialiser complètement si quelque chose échoue
      await _cleanup();
      rethrow;
    }
  }

  // ─── Appelé : accepter ────────────────────────────────────────────────────

  Future<void> acceptCall() async {
    final s = state;
    if (s.status != CallStatus.incoming || s.callId == null) return;

    try {
      final stream = await _getLocalStream(s.callType ?? 'audio');
      _localStream = stream;
      stateNotifier.value = s.copyWith(localStream: stream);

      _isOfferer = false;
      await _connectSignaling(s.callId!);
      await _setupPeerConnection();
      _sendSignal({'type': 'call_accepted'});
    } catch (e) {
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
    _sigWs = WebSocketChannel.connect(uri);
    _sigSub = _sigWs!.stream.listen(
      _onSignal,
      onDone:  _onSignalingClosed,
      onError: (_) => _cleanup(),
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
        case 'ice_candidate':
          await _handleIceCandidate(data);
        case 'call_rejected':
        case 'hangup':
          await _cleanup();
      }
    } catch (_) {}
  }

  void _onSignalingClosed() {
    if (state.status != CallStatus.idle) _cleanup();
  }

  // ─── WebRTC ───────────────────────────────────────────────────────────────

  Future<void> _setupPeerConnection() async {
    _pc = await createPeerConnection(_iceConfig);
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
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        stateNotifier.value = state.copyWith(status: CallStatus.active);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
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
