import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:record/record.dart';

import '../../core/models/chat_model.dart';
import '../../core/providers/auth_provider.dart' show authNotifierProvider, AuthAuthenticated;
import '../../core/providers/chat_provider.dart';
import '../../core/services/call_service.dart';
import '../../core/services/chat_websocket_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/invitation_service.dart';
import '../../core/services/moderation_service.dart';
import '../profile/report_sheet.dart';
import 'contact_picker_screen.dart';
import 'image_viewer_screen.dart';
import 'multi_image_preview_screen.dart';
import 'room_members_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/image_editor_screen.dart';
import '../../widgets/tp_action_sheet.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_toast.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ChatThreadScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _ctrl        = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _picker      = ImagePicker();
  final _recorder    = AudioRecorder();

  // Recherche dans la conversation : les résultats sont surlignés en place
  // dans le fil (pas d'écran séparé) — on garde le contexte (heure, expéditeur,
  // messages autour). Navigation au clavier ▲▼ + compteur "n/N".
  final _searchCtrl  = TextEditingController();
  bool   _searching  = false;
  String _searchQuery = '';
  String? _activeMatchId;
  List<ChatMessage> _messages = [];
  final Map<String, GlobalKey> _msgKeys = {};

  // Typing indicator
  Timer? _typingTimer;
  bool  _isTyping = false;
  String? _typingUserName;
  Timer? _typingClearTimer;
  StreamSubscription<TypingEvent>? _typingSub;

  // Indicateur « enregistre une note vocale »
  String? _recordingUserName;
  Timer? _recordingClearTimer;
  StreamSubscription<RecordingEvent>? _recordingSub;

  // Mode événement (annonce + carte événement) — admin de groupe événement uniquement
  bool _attachEvent = true;

  // DM « collant » : une fois qu'on sait que la salle est un DM, on le garde vrai
  // pour toute la durée de l'écran. Sinon, un rechargement de `chatRoomsProvider`
  // rend `room` momentanément null → les accusés de lecture disparaîtraient.
  bool _isDm = false;

  // Mon id « collant » : un rechargement de l'auth (resync identité…) rendrait
  // `me` null un instant → `isMe` faux → coches disparues. On le mémorise.
  String? _myId;

  // Voice recording — style WhatsApp
  _VoiceMode _voiceMode   = _VoiceMode.idle;
  bool       _recordPaused = false;
  int        _recordSecs  = 0;
  Timer?     _recordTimer;
  // Drag tracking pendant le hold
  double _holdDragX    = 0;
  double _holdDragY    = 0;
  bool   _holdCancelled = false;
  bool   _holdLocked    = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _scrollCtrl.addListener(_onScroll);

    // Écouter les events de typing du WS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(chatWebSocketServiceProvider(widget.roomId));
      _typingSub = ws.typing.listen((e) {
        if (!mounted) return;
        setState(() => _typingUserName = e.userName);
        _typingClearTimer?.cancel();
        _typingClearTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _typingUserName = null);
        });
      });
      _recordingSub = ws.recording.listen((e) {
        if (!mounted) return;
        _recordingClearTimer?.cancel();
        if (e.state) {
          setState(() => _recordingUserName = e.userName);
          // Filet de sécurité si le « stop » se perd.
          _recordingClearTimer = Timer(const Duration(seconds: 30), () {
            if (mounted) setState(() => _recordingUserName = null);
          });
        } else {
          setState(() => _recordingUserName = null);
        }
      });
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    // Liste inversée : le HAUT (messages plus anciens) est du côté maxScrollExtent.
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      ref.read(chatThreadProvider(widget.roomId).notifier).loadOlderMessages();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _scrollCtrl.removeListener(_onScroll);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _typingTimer?.cancel();
    _typingClearTimer?.cancel();
    _typingSub?.cancel();
    _recordingClearTimer?.cancel();
    _recordingSub?.cancel();
    _recordTimer?.cancel();
    if (_voiceMode != _VoiceMode.idle) _recorder.stop().catchError((_) => null);
    _recorder.dispose();
    ref.read(chatRoomsProvider.notifier).refresh();
    super.dispose();
  }

  void _onTextChanged() {
    if (_ctrl.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref.read(chatWebSocketServiceProvider(widget.roomId)).sendTyping();
    }
    if (_ctrl.text.isEmpty) _isTyping = false;

    // Re-envoyer l'indicateur de saisie toutes les 3 secondes
    _typingTimer?.cancel();
    if (_ctrl.text.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isTyping = false;
      });
    }
  }

  // Liste inversée : l'offset 0 = le bas (dernier message). « Près du bas » =
  // offset proche de 0.
  bool _isNearBottom() {
    if (!_scrollCtrl.hasClients) return true;
    return _scrollCtrl.position.pixels <= 200;
  }

  /// Ramène la vue au dernier message. En mode `reverse:true`, le bas correspond
  /// à l'offset 0 — un simple saut/animation vers 0 suffit (pas besoin des sauts
  /// échelonnés qu'imposait la construction paresseuse en mode normal).
  void _scrollToBottom({bool animate = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (animate) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scrollCtrl.jumpTo(0);
    }
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await ref.read(chatThreadProvider(widget.roomId).notifier)
        .sendTextMessage(text, attachEvent: _attachEvent);

    ref.invalidate(chatThreadProvider(widget.roomId));
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiImagePreviewScreen(
          roomId: widget.roomId,
          files: picked.map((f) => File(f.path)).toList(),
          attachEvent: _attachEvent,
        ),
      ),
    );
    _scrollToBottom();
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Démarrer l'enregistrement (commun tap + hold) ─────────────────────────

  Future<bool> _beginRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          TpToast.warning(context, 'Permission micro refusée — autorise le micro dans les réglages.');
        }
        return false;
      }
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      // Prévient l'autre membre qu'on enregistre une note vocale.
      ref.read(chatWebSocketServiceProvider(widget.roomId)).sendRecording(true);
      if (mounted) {
        setState(() { _recordSecs = 0; _recordPaused = false; });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && !_recordPaused) setState(() => _recordSecs++);
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        TpToast.error(context, 'Erreur micro : $e');
      }
      return false;
    }
  }

  // ── Tap unique → mode verrouillé ─────────────────────────────────────────

  Future<void> _onMicTap() async {
    if (_voiceMode != _VoiceMode.idle) return;
    setState(() => _voiceMode = _VoiceMode.locked);
    final ok = await _beginRecording();
    if (!ok && mounted) setState(() => _voiceMode = _VoiceMode.idle);
  }

  // ── Hold → mode maintenu ─────────────────────────────────────────────────

  Future<void> _onHoldStart(LongPressStartDetails _) async {
    if (_voiceMode != _VoiceMode.idle) return;
    _holdDragX = 0; _holdDragY = 0;
    _holdCancelled = false; _holdLocked = false;
    setState(() => _voiceMode = _VoiceMode.holding);
    final ok = await _beginRecording();
    if (!ok && mounted) setState(() => _voiceMode = _VoiceMode.idle);
  }

  void _onHoldMove(LongPressMoveUpdateDetails d) {
    if (_voiceMode != _VoiceMode.holding) return;
    setState(() {
      _holdDragX = d.offsetFromOrigin.dx;
      _holdDragY = d.offsetFromOrigin.dy;
    });
    // Seuils de déclenchement
    if (_holdDragX < -80 && !_holdCancelled && !_holdLocked) {
      _holdCancelled = true;
      _cancelVoice();
    } else if (_holdDragY < -60 && !_holdLocked && !_holdCancelled) {
      _holdLocked = true;
      setState(() => _voiceMode = _VoiceMode.locked);
    }
  }

  Future<void> _onHoldEnd(LongPressEndDetails _) async {
    if (_voiceMode != _VoiceMode.holding) return;
    if (!_holdCancelled && !_holdLocked) await _sendVoice();
  }

  // ── Contrôles en mode verrouillé ─────────────────────────────────────────

  Future<void> _togglePause() async {
    if (_recordPaused) {
      await _recorder.resume();
      setState(() => _recordPaused = false);
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_recordPaused) setState(() => _recordSecs++);
      });
    } else {
      await _recorder.pause();
      setState(() => _recordPaused = true);
    }
  }

  Future<void> _sendVoice() async {
    _recordTimer?.cancel();
    ref.read(chatWebSocketServiceProvider(widget.roomId)).sendRecording(false);
    final path = await _recorder.stop();
    final secs  = _recordSecs;
    setState(() { _voiceMode = _VoiceMode.idle; _recordPaused = false; });
    if (path != null && secs >= 1) {
      await ref.read(chatThreadProvider(widget.roomId).notifier)
          .sendVoiceMessage(path, secs, attachEvent: _attachEvent);

      ref.invalidate(chatThreadProvider(widget.roomId));
      _scrollToBottom();
    }
  }

  Future<void> _cancelVoice() async {
    _recordTimer?.cancel();
    ref.read(chatWebSocketServiceProvider(widget.roomId)).sendRecording(false);
    await _recorder.stop();
    if (mounted) setState(() { _voiceMode = _VoiceMode.idle; _recordPaused = false; });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync    = ref.watch(chatThreadProvider(widget.roomId));
    if (messagesAsync.hasValue) {
      _messages = messagesAsync.value!;
      // Purge les GlobalKey des messages qui ne sont plus dans la fenêtre
      // chargée (au-delà de _msgKeys.length, ça grossirait indéfiniment sur
      // une session longue).
      if (_msgKeys.length > _messages.length) {
        final ids = _messages.map((m) => m.id).toSet();
        _msgKeys.removeWhere((id, _) => !ids.contains(id));
      }
    }
    final room             = ref.watch(chatRoomByIdProvider(widget.roomId));
    final me = ref.watch(authNotifierProvider.select(
      (s) => s.valueOrNull is AuthAuthenticated ? (s.valueOrNull as AuthAuthenticated).user : null,
    ));
    if (me?.id != null) _myId = me!.id;
    // DM collant : ne repasse jamais à false même si `room` devient null pendant
    // un rechargement → les accusés de lecture restent affichés en continu.
    if (room?.isPrivate == true) _isDm = true;
    // On observe toujours les providers (défaut null/false) : leur valeur ne
    // s'efface pas au rechargement de la salle, donc les coches ne clignotent pas.
    final partnerReadAt    = ref.watch(chatPartnerReadAtProvider(widget.roomId));
    final partnerOnline    = ref.watch(chatPartnerOnlineProvider(widget.roomId));

    final canWrite = room == null ||
        room.isPrivate ||
        room.isAdmin ||
        room.groupMode == 'open';

    ref.listen(chatThreadProvider(widget.roomId), (_, next) {
      if (next is! AsyncData) return;
      // Liste inversée (reverse:true) : elle s'ouvre déjà tout en bas, aucun saut
      // initial nécessaire. On ne suit un nouveau message que si l'utilisateur est
      // déjà en bas — sinon on ne le tire pas pendant qu'il lit l'historique.
      if (_isNearBottom()) _scrollToBottom();
    });

    return PopScope(
      // En mode recherche, le retour ferme la recherche au lieu de quitter la conv.
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) _closeSearch();
      },
      child: Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildNavBar(context, room),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Erreur de chargement',
                  style: TextStyle(color: context.tpInkSub)),
              ),
              data: (msgs) => _buildMessageList(
                  context, msgs, _myId, partnerReadAt, partnerOnline, _isDm, canWrite),
            ),
          ),
          if (_recordingUserName != null && _voiceMode == _VoiceMode.idle)
            _RecordingIndicator(userName: _recordingUserName!)
          else if (_typingUserName != null && _voiceMode == _VoiceMode.idle)
            _TypingIndicator(userName: _typingUserName!),
          if (!canWrite)
            _BroadcastBanner()
          else ...[
            if (_voiceMode == _VoiceMode.holding)
              _buildLockIndicator(context),
            if (_voiceMode == _VoiceMode.locked || _voiceMode == _VoiceMode.paused)
              _buildLockedBar(context)
            else
              Stack(
                children: [
                  _buildComposer(context, isAdmin: room?.isAdmin == true && room?.isEvent == true),
                  if (_voiceMode == _VoiceMode.holding)
                    IgnorePointer(child: _buildHoldingOverlay(context)),
                ],
              ),
          ],
        ],
      ),
      ),
    );
  }

  // Plafond appel de groupe (maillage P2P) — doit rester aligné avec
  // MAX_GROUP_CALL_PARTICIPANTS côté backend (apps/chat/models.py).
  static const _kMaxGroupCallParticipants = 4;

  Future<void> _startCall(BuildContext ctx, ChatRoomModel room, String callType) async {
    if (room.isGroup && room.membersCount > _kMaxGroupCallParticipants) {
      TpToast.error(ctx,
          'Ce groupe compte plus de $_kMaxGroupCallParticipants membres, trop pour un appel.');
      return;
    }

    final invitees = room.membersPreview
        .map((m) => CallParticipant(userId: m.id, displayName: m.displayName, avatarUrl: m.avatarUrl))
        .toList();
    final name = room.isGroup ? room.displayName : (invitees.firstOrNull?.displayName ?? room.displayName);
    final avatarUrl = room.isGroup ? room.roomAvatarUrl : invitees.firstOrNull?.avatarUrl;

    try {
      await CallService().initiateCall(
        roomId: room.id,
        callType: callType,
        remoteUserName: name,
        remoteUserAvatarUrl: avatarUrl,
        isGroup: room.isGroup,
        invitees: invitees,
      );
      if (ctx.mounted) {
        ctx.push('/call/outgoing', extra: {
          'callType': callType,
          'remoteUserName': name,
          'remoteUserAvatarUrl': avatarUrl,
        });
      }
    } catch (e) {
      if (ctx.mounted) {
        TpToast.error(ctx, 'Impossible de lancer l\'appel : $e');
      }
    }
  }

  // ── Menu ⋮ d'un DM (recherche / sourdine / signaler / bloquer) ─────────────

  void _showDmMenu(BuildContext ctx, ChatRoomModel room, ChatMemberPreview? other) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: ctx.tpCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(
                color: ctx.tpHair, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            _menuTile(ctx,
              icon: PhosphorIcons.magnifyingGlass(),
              label: 'Rechercher dans la conversation',
              onTap: () { Navigator.pop(sheetCtx); _openSearch(); }),
            _menuTile(ctx,
              icon: room.isMuted ? PhosphorIcons.bell() : PhosphorIcons.bellSlash(),
              label: room.isMuted ? 'Réactiver les notifications' : 'Couper les notifications',
              onTap: () { Navigator.pop(sheetCtx); _toggleMute(room); }),
            if (other != null) ...[
              _menuTile(ctx,
                icon: PhosphorIcons.flag(),
                label: 'Signaler',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ReportSheet.show(ctx, targetType: 'user', targetId: other.id,
                      targetName: other.displayName, blockUserId: other.id);
                }),
              _menuTile(ctx,
                icon: PhosphorIcons.prohibit(),
                label: 'Bloquer',
                danger: true,
                onTap: () { Navigator.pop(sheetCtx); _confirmBlock(ctx, other); }),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext ctx, {required IconData icon, required String label,
      required VoidCallback onTap, bool danger = false}) {
    final color = danger ? kError : ctx.tpInk;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
      onTap: onTap,
    );
  }

  Future<void> _toggleMute(ChatRoomModel room) async {
    final newMuted = !room.isMuted;
    try {
      await ref.read(chatServiceProvider).setRoomMuted(room.id, newMuted);
      await ref.read(chatRoomsProvider.notifier).refresh();
      if (mounted) {
        TpToast.success(context, newMuted
            ? 'Notifications coupées pour cette conversation'
            : 'Notifications réactivées');
      }
    } catch (e) {
      debugPrint('Chat: échec _toggleMute — $e');
      if (mounted) TpToast.error(context, 'Action impossible pour le moment');
    }
  }

  Future<void> _confirmBlock(BuildContext ctx, ChatMemberPreview other) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: dCtx.tpCard,
        title: Text('Bloquer ${other.displayName} ?',
            style: TextStyle(color: dCtx.tpInk, fontWeight: FontWeight.w800)),
        content: Text("Cette personne ne pourra plus t'envoyer de message ni t'appeler.",
            style: TextStyle(color: dCtx.tpInkSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Bloquer', style: TextStyle(color: kError))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(moderationServiceProvider).block(other.id);
      if (mounted) {
        TpToast.success(context, '${other.displayName} a été bloqué');
        context.pop();
      }
    } catch (e) {
      debugPrint('Chat: échec _confirmBlock — $e');
      if (mounted) TpToast.error(context, 'Impossible de bloquer');
    }
  }

  // ── Recherche dans la conversation ─────────────────────────────────────────

  void _openSearch() =>
      setState(() { _searching = true; _searchQuery = ''; _activeMatchId = null; _searchCtrl.clear(); });

  void _closeSearch() =>
      setState(() { _searching = false; _searchQuery = ''; _activeMatchId = null; _searchCtrl.clear(); });

  List<ChatMessage> _matchesForQuery(String query) {
    if (query.isEmpty) return const [];
    final q = query.toLowerCase();
    return [for (final m in _messages) if (m.isText && m.content.toLowerCase().contains(q)) m];
  }

  List<ChatMessage> get _searchMatches => _matchesForQuery(_searchQuery);

  void _onSearchChanged(String v) {
    final query = v.trim();
    final matches = _matchesForQuery(query);
    final stillValid = matches.any((m) => m.id == _activeMatchId);
    setState(() {
      _searchQuery = query;
      if (!stillValid) {
        _activeMatchId = matches.isNotEmpty ? matches.last.id : null;
      }
    });
    if (!stillValid && _activeMatchId != null) {
      final id = _activeMatchId!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMessage(id));
    }
  }

  // Navigue vers le résultat précédent (delta -1, plus ancien) ou suivant
  // (delta +1, plus récent).
  void _goToMatch(int delta) {
    final matches = _searchMatches;
    if (matches.isEmpty) return;
    final currentIdx = matches.indexWhere((m) => m.id == _activeMatchId);
    final newIdx = (currentIdx < 0 ? matches.length - 1 : currentIdx + delta)
        .clamp(0, matches.length - 1);
    final id = matches[newIdx].id;
    setState(() => _activeMatchId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMessage(id));
  }

  // Fait défiler jusqu'au message ciblé et le laisse visible à l'écran. Si le
  // message n'est pas encore construit (hors de la zone de cache de la liste),
  // on saute d'abord approximativement selon sa position relative dans
  // l'historique chargé, puis on affine une fois le widget monté.
  void _scrollToMessage(String id) {
    final ctx = _msgKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), alignment: 0.5, curve: Curves.easeOut);
      return;
    }
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx < 0 || !_scrollCtrl.hasClients || _messages.length < 2) return;
    final fraction = 1 - (idx / (_messages.length - 1)); // liste inversée : bas = fraction 0
    final target = (_scrollCtrl.position.maxScrollExtent * fraction)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final retryCtx = _msgKeys[id]?.currentContext;
      if (retryCtx != null) {
        Scrollable.ensureVisible(retryCtx,
            duration: const Duration(milliseconds: 200), alignment: 0.5, curve: Curves.easeOut);
      }
    });
  }

  // ── Membres du groupe ─────────────────────────────────────────────────────

  void _showMembersSheet(BuildContext context, ChatRoomModel room) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RoomMembersSheet(room: room),
    );
  }

  // ── Groupe personnalisé ────────────────────────────────────────────────────

  Future<void> _toggleBroadcast(ChatRoomModel room) async {
    final newMode = room.isBroadcast ? 'open' : 'broadcast';
    await ref.read(groupModeUpdateProvider)(room.id, newMode);
    if (!mounted) return;
    await ref.read(chatRoomsProvider.notifier).refresh();
  }

  Future<void> _showGroupSettingsSheet(ChatRoomModel room) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TpActionSheet(items: [
        if (room.isAdmin) ...[
          TpActionSheetItem(
            icon: PhosphorIcons.userPlus(),
            label: 'Ajouter des membres',
            onTap: () => _addGroupMembers(room),
          ),
          TpActionSheetItem(
            icon: PhosphorIcons.textAa(),
            label: 'Renommer le groupe',
            onTap: () => _renameGroup(room),
          ),
          TpActionSheetItem(
            icon: PhosphorIcons.image(),
            label: 'Changer la photo',
            onTap: () => _changeGroupAvatar(room),
          ),
          TpActionSheetItem(
            icon: room.isBroadcast ? PhosphorIcons.lockKeyOpen() : PhosphorIcons.lock(),
            label: room.isBroadcast ? 'Ouvrir aux membres' : 'Seuls les admins écrivent',
            subtitle: room.isBroadcast ? 'Les membres pourront écrire' : "Personne d'autre ne pourra écrire",
            onTap: () => _toggleBroadcast(room),
          ),
        ],
        TpActionSheetItem(
          icon: PhosphorIcons.signOut(),
          label: 'Quitter le groupe',
          danger: true,
          dividerBefore: room.isAdmin,
          onTap: () => _leaveGroup(room),
        ),
      ]),
    );
  }

  // ── Événement (organisateur uniquement) ────────────────────────────────────

  Future<void> _showEventSettingsSheet(ChatRoomModel room) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TpActionSheet(items: [
        TpActionSheetItem(
          icon: PhosphorIcons.textAa(),
          label: 'Renommer la conversation',
          onTap: () => _renameGroup(
            room,
            title: 'Renommer la conversation',
            hint: 'Nom de la conversation',
            errorMsg: 'Impossible de renommer la conversation',
          ),
        ),
        TpActionSheetItem(
          icon: PhosphorIcons.image(),
          label: 'Changer la photo',
          onTap: () => _changeGroupAvatar(room),
        ),
        TpActionSheetItem(
          icon: room.isBroadcast ? PhosphorIcons.lockKeyOpen() : PhosphorIcons.lock(),
          label: room.isBroadcast ? 'Ouvrir aux participants' : 'Seuls les organisateurs écrivent',
          subtitle: room.isBroadcast ? 'Les participants pourront écrire' : "Personne d'autre ne pourra écrire",
          onTap: () => _toggleBroadcast(room),
        ),
      ]),
    );
  }

  Future<void> _addGroupMembers(ChatRoomModel room) async {
    List<RoomMemberModel> members;
    try {
      members = await ref.read(chatServiceProvider).getRoomMembers(room.id);
    } catch (e) {
      debugPrint('Chat: échec _addGroupMembers (chargement) — $e');
      if (mounted) TpToast.error(context, 'Impossible de charger les membres');
      return;
    }
    if (!mounted) return;

    final excludeIds = {?_myId, ...members.map((m) => m.id)};
    final memberIds = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          title: 'Ajouter des membres',
          confirmLabel: 'Ajouter',
          excludeIds: excludeIds,
        ),
      ),
    );
    if (memberIds == null || memberIds.isEmpty || !mounted) return;

    try {
      await ref.read(chatServiceProvider).addGroupMembers(room.id, memberIds);
      if (mounted) TpToast.success(context, 'Membres ajoutés');
    } catch (e) {
      debugPrint('Chat: échec _addGroupMembers (ajout) — $e');
      if (mounted) TpToast.error(context, "Impossible d'ajouter ces membres");
    }
  }

  Future<void> _renameGroup(
    ChatRoomModel room, {
    String title = 'Renommer le groupe',
    String hint = 'Nom du groupe',
    String errorMsg = 'Impossible de renommer le groupe',
  }) async {
    final newName = await _showRenameGroupSheet(context, room.displayName, title: title, hint: hint);
    if (newName == null || newName.trim().isEmpty || !mounted) return;
    try {
      await ref.read(chatServiceProvider).updateCommunityName(room.id, newName.trim());
      await ref.read(chatRoomsProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Chat: échec _renameGroup — $e');
      if (mounted) TpToast.error(context, errorMsg);
    }
  }

  Future<void> _changeGroupAvatar(ChatRoomModel room) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    final cropped = await pickAndCropSquareAvatar(context, File(picked.path));
    if (cropped == null || !mounted) return;
    try {
      final url = await ref.read(chatServiceProvider).updateCommunityAvatar(room.id, XFile(cropped.path));
      if (!mounted) return;
      await precacheFreshAvatar(context, url);
      if (!mounted) return;
      ref.read(chatRoomsProvider.notifier).updateRoomAvatarLocally(room.id, url);
    } catch (e) {
      debugPrint('Chat: échec _changeGroupAvatar — $e');
      if (mounted) TpToast.error(context, 'Impossible de mettre à jour la photo');
    }
  }

  Future<void> _leaveGroup(ChatRoomModel room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: dCtx.tpCard,
        title: Text('Quitter le groupe ?',
            style: TextStyle(color: dCtx.tpInk, fontWeight: FontWeight.w800)),
        content: Text('Tu ne recevras plus les messages de « ${room.displayName} ».',
            style: TextStyle(color: dCtx.tpInkSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Quitter', style: TextStyle(color: kError))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(chatServiceProvider).leaveGroup(room.id);
      await ref.read(chatRoomsProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('Chat: échec _leaveGroup — $e');
      if (mounted) TpToast.error(context, 'Impossible de quitter le groupe');
    }
  }

  // ── NavBar ────────────────────────────────────────────────────────────────

  Widget _buildNavBar(BuildContext context, ChatRoomModel? room) {
    if (_searching) return _buildSearchBar(context);
    final name    = room?.displayName ?? 'Conversation';
    final other   = room?.membersPreview.isNotEmpty == true
        ? room!.membersPreview.first
        : null;

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 10),
        decoration: BoxDecoration(
          color: context.tpCard,
          border: Border(bottom: BorderSide(color: context.tpHair)),
        ),
        child: Row(
          children: [
            Semantics(
              button: true, label: 'Retour',
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                  child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            TpAvatar(
              name: other?.displayName ?? name,
              imageUrl: room?.roomAvatarUrl ?? other?.avatarUrl,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                        color: context.tpInk, letterSpacing: -0.3)),
                  if (room?.isEvent == true && room?.eventTitle != null)
                    Text(room!.eventTitle!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Boutons appel DM : audio + vidéo séparés.
            if (room?.isPrivate == true) ...[
              _CallIconBtn(
                icon: PhosphorIcons.phone(),
                label: 'Appel audio',
                onTap: () => _startCall(context, room!, 'audio'),
              ),
              const SizedBox(width: 4),
              _CallIconBtn(
                icon: PhosphorIcons.videoCamera(),
                label: 'Appel vidéo',
                onTap: () => _startCall(context, room!, 'video'),
              ),
              const SizedBox(width: 4),
            ],
            // Bouton appel groupe (sous le plafond du maillage P2P) : menu
            // déroulant unique pour choisir audio/vidéo.
            if (room?.isGroup == true && room!.membersCount <= _kMaxGroupCallParticipants) ...[
              _CallMenuButton(
                onAudio: () => _startCall(context, room, 'audio'),
                onVideo: () => _startCall(context, room, 'video'),
              ),
              const SizedBox(width: 4),
            ],
            if (room?.isEvent == true || room?.isGroup == true) ...[
              Semantics(
                button: true, label: 'Voir les membres',
                child: GestureDetector(
                  onTap: () => _showMembersSheet(context, room!),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                    child: Icon(PhosphorIcons.usersThree(), color: context.tpInk, size: 20),
                  ),
                ),
              ),
              if (room?.isGroup == true || room?.isAdmin == true) ...[
                const SizedBox(width: 4),
                Semantics(
                  button: true, label: 'Paramètres du groupe',
                  child: GestureDetector(
                    onTap: () => room!.isGroup
                        ? _showGroupSettingsSheet(room)
                        : _showEventSettingsSheet(room),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                      child: Icon(PhosphorIcons.dotsThreeVertical(), color: context.tpInk, size: 20),
                    ),
                  ),
                ),
              ],
            ] else
              Semantics(
                button: true, label: "Plus d'options",
                child: GestureDetector(
                  onTap: room == null ? null : () => _showDmMenu(context, room, other),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md)),
                    child: Icon(PhosphorIcons.dotsThreeVertical(), color: context.tpInk, size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final matches   = _searchMatches;
    final activeIdx = matches.indexWhere((m) => m.id == _activeMatchId);
    final hasQuery  = _searchQuery.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 10),
        decoration: BoxDecoration(
          color: context.tpCard,
          border: Border(bottom: BorderSide(color: context.tpHair)),
        ),
        child: Row(
          children: [
            Semantics(
              button: true, label: 'Fermer la recherche',
              child: GestureDetector(
                onTap: _closeSearch,
                child: SizedBox(
                  width: 44, height: 44,
                  child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: TextStyle(color: context.tpInk, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Rechercher un message…',
                  hintStyle: TextStyle(color: context.tpInkMute),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (hasQuery) ...[
              Text(
                matches.isEmpty ? '0 résultat' : '${activeIdx + 1}/${matches.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub),
              ),
              Semantics(
                button: true, label: 'Résultat précédent (plus ancien)',
                child: IconButton(
                  icon: Icon(PhosphorIcons.caretUp(), size: 16),
                  color: context.tpInk,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: matches.isEmpty || activeIdx <= 0 ? null : () => _goToMatch(-1),
                ),
              ),
              Semantics(
                button: true, label: 'Résultat suivant (plus récent)',
                child: IconButton(
                  icon: Icon(PhosphorIcons.caretDown(), size: 16),
                  color: context.tpInk,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: matches.isEmpty || activeIdx >= matches.length - 1 ? null : () => _goToMatch(1),
                ),
              ),
              Semantics(
                button: true, label: 'Effacer la recherche',
                child: IconButton(
                  icon: Icon(PhosphorIcons.x(), size: 18),
                  color: context.tpInkSub,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(() { _searchQuery = ''; _activeMatchId = null; _searchCtrl.clear(); }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Liste ──────────────────────────────────────────────────────────────────

  Widget _buildMessageList(BuildContext context, List<ChatMessage> messages, String? myId, DateTime? partnerReadAt, bool partnerOnline, bool isDm, bool canWrite) {
    final notifier     = ref.read(chatThreadProvider(widget.roomId).notifier);
    final isLoadingOld = notifier.loadingOlder;
    final hasMoreOld   = notifier.hasMoreOlder;

    if (messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Commence la conversation !',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInkSub)),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      // Liste INVERSÉE (façon WhatsApp) : l'offset 0 correspond au BAS, donc à
      // l'ouverture on est déjà sur le dernier message — aucun saut ni défilement
      // visible. index 0 = message le plus récent ; l'en-tête passe tout en haut.
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      // +1 pour l'en-tête "charger plus / début" (dernier index = tout en haut)
      itemCount: messages.length + 1,
      itemBuilder: (_, i) {
        // Dernier index (mode reverse) = tout en haut : "charger plus" / "début"
        if (i == messages.length) {
          if (isLoadingOld) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
            );
          }
          if (!hasMoreOld) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Début de la conversation',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkMute))),
            );
          }
          return const SizedBox.shrink();
        }

        final idx  = messages.length - 1 - i;   // i=0 → message le plus récent (bas)
        final msg  = messages[idx];
        final isMe = msg.sender.id == myId;

        // Rafale d'images du même expéditeur envoyées à quelques secondes
        // d'intervalle → regroupées en un seul bloc (grille). Seule l'ancre
        // (message le plus récent du groupe) est rendue ; les autres index
        // du groupe sont sautés.
        final groupRange = _imageGroupRange(messages, idx);
        if (groupRange != null && idx != groupRange.$2) {
          return const SizedBox.shrink();
        }
        final imageGroup = groupRange != null
            ? messages.sublist(groupRange.$1, groupRange.$2 + 1)
            : null;

        // Séparateur de jour au-dessus du 1er message de chaque journée (comparé
        // au message plus ancien, donc idx-1 dans le tableau oldest→newest).
        // Pour un groupe d'images, la base de comparaison est le 1er message
        // du groupe (pas l'ancre) pour ne pas manquer un changement de jour.
        final dayBaseIdx = groupRange?.$1 ?? idx;
        final showDay = dayBaseIdx == 0 || !_sameDay(messages[dayBaseIdx - 1].createdAt, messages[dayBaseIdx].createdAt);
        // Accusé de lecture par message (DM uniquement) : lu (2 bleus) / livré
        // = partenaire en ligne mais pas encore lu (2 gris) / envoyé = hors
        // ligne (1 gris).
        _MsgStatus? status;
        if (isDm && isMe) {
          if (partnerReadAt != null && !partnerReadAt.isBefore(msg.createdAt)) {
            status = _MsgStatus.read;
          } else if (partnerOnline) {
            status = _MsgStatus.delivered;
          } else {
            status = _MsgStatus.sent;
          }
        }
        final msgKey = _msgKeys.putIfAbsent(msg.id, () => GlobalKey());
        return KeyedSubtree(
          key: msgKey,
          child: Column(children: [
            if (showDay) _buildDaySeparator(context, msg.createdAt),
            _MessageBubble(
              message: msg, isMe: isMe, roomId: widget.roomId, status: status,
              canReact: canWrite, imageGroup: imageGroup,
              isActiveSearchMatch: _searching && msg.id == _activeMatchId,
            ),
          ]),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Fenêtre de rafale : des images du même expéditeur envoyées à moins de
  /// [_kImageGroupWindow] d'écart sont regroupées en un seul bloc.
  static const _kImageGroupWindow = Duration(seconds: 20);

  /// Bornes [start, end] (inclus, indices chronologiques dans `messages`) du
  /// groupe d'images auquel appartient `idx`, ou `null` si `idx` n'est pas
  /// une image ou forme un groupe de taille 1 (pas de bloc à faire).
  (int, int)? _imageGroupRange(List<ChatMessage> messages, int idx) {
    final msg = messages[idx];
    if (!msg.isImage) return null;
    var start = idx;
    while (start > 0 &&
        messages[start - 1].isImage &&
        messages[start - 1].sender.id == msg.sender.id &&
        messages[start].createdAt.difference(messages[start - 1].createdAt) <= _kImageGroupWindow) {
      start--;
    }
    var end = idx;
    while (end < messages.length - 1 &&
        messages[end + 1].isImage &&
        messages[end + 1].sender.id == msg.sender.id &&
        messages[end + 1].createdAt.difference(messages[end].createdAt) <= _kImageGroupWindow) {
      end++;
    }
    if (start == end) return null;
    return (start, end);
  }

  Widget _buildDaySeparator(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    String label;
    if (_sameDay(dt, now)) {
      label = "Aujourd'hui";
    } else if (_sameDay(dt, now.subtract(const Duration(days: 1)))) {
      label = 'Hier';
    } else {
      label = DateFormat('d MMMM', 'fr_FR').format(dt);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
        ),
      ),
    );
  }

  // ── Composer ──────────────────────────────────────────────────────────────

  Widget _buildComposer(BuildContext context, {bool isAdmin = false}) {
    final hintText = isAdmin
        ? (_attachEvent ? 'Poster une annonce…' : 'Écris un message…')
        : 'Écris un message…';

    return Container(
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bandeau "Mode événement" (admin d'un groupe événement uniquement)
          if (isAdmin) _buildEventModeBanner(context),
          Padding(
            padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
                10 + MediaQuery.of(context).padding.bottom),
            // Scopé au ValueListenableBuilder pour ne reconstruire que la barre
            // de saisie (icône image / envoyer-micro) à chaque frappe, plutôt
            // que tout l'écran via un setState() global.
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ctrl,
              builder: (context, value, _) {
                final hasText = value.text.isNotEmpty;
                return Row(
                  children: [
                    // Image picker
                    if (!hasText)
                      Semantics(
                        button: true, label: 'Joindre une image',
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: context.tpBg,
                                borderRadius: BorderRadius.circular(Radii.button),
                                border: Border.all(color: context.tpHair),
                              ),
                              child: Icon(PhosphorIcons.image(), color: context.tpInkSub, size: 20),
                            ),
                          ),
                        ),
                      ),

                    // Champ de texte
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: context.tpBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 4),
                        child: TextField(
                          controller: _ctrl,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkMute),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendText(),
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Envoyer ou micro
                    hasText
                        ? Semantics(
                            button: true, label: 'Envoyer le message',
                            child: GestureDetector(
                              onTap: _sendText,
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  gradient: trackpartyGradient,
                                  borderRadius: BorderRadius.circular(Radii.button),
                                  boxShadow: Shadows.brand,
                                ),
                                child: Icon(PhosphorIcons.paperPlaneTilt(), color: Colors.white, size: 20),
                              ),
                            ),
                          )
                        : Semantics(
                            button: true, label: 'Enregistrer un message vocal',
                            child: GestureDetector(
                              onTap:                  _onMicTap,
                              onLongPressStart:       _onHoldStart,
                              onLongPressMoveUpdate:  _onHoldMove,
                              onLongPressEnd:         _onHoldEnd,
                            // onLongPressCancel fire aussi après un tap simple → ne cancel que si
                            // on est vraiment en mode hold (pas en mode locked déclenché par tap)
                            onLongPressCancel: () {
                              if (_voiceMode == _VoiceMode.holding) _cancelVoice();
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: context.tpBg,
                                borderRadius: BorderRadius.circular(Radii.button),
                                border: Border.all(color: context.tpHair),
                              ),
                              child: Icon(PhosphorIcons.microphone(), color: context.tpInkSub, size: 20),
                            ),
                          ),
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventModeBanner(BuildContext context) {
    return EventModeBanner(
      attachEvent: _attachEvent,
      onToggle: () => setState(() => _attachEvent = !_attachEvent),
    );
  }

  // ── Indicateur verrouillage (au-dessus, mode hold) ───────────────────────

  Widget _buildLockIndicator(BuildContext context) {
    final nearLock = _holdDragY < -30;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(right: Sp.md, bottom: 4),
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: nearLock ? kPrimary : context.tpCard,
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: Shadows.sm,
          border: Border.all(color: nearLock ? kPrimary : context.tpHair),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              nearLock ? PhosphorIcons.lock(PhosphorIconsStyle.fill) : PhosphorIcons.lock(),
              color: nearLock ? Colors.white : kPrimary,
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              '↑',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: nearLock ? Colors.white : kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Overlay hold (par-dessus le composer, IgnorePointer → gestes passent) ─

  Widget _buildHoldingOverlay(BuildContext context) {
    final cancelHighlight = _holdDragX < -40;

    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
          10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        children: [
          // Bouton micro visuel (rouge, pas de GestureDetector — celui du
          // composer sous-jacent gère les gestes)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kError,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: kError.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)],
            ),
            child: Icon(PhosphorIcons.microphone(), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),

          _RecordingDots(),
          const SizedBox(width: 6),
          Text(
            _fmtDuration(_recordSecs),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kError),
          ),

          Expanded(
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: cancelHighlight ? kError : context.tpInkMute,
                ),
                child: const Text('← Glisse pour annuler'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode verrouillé / pause (tap ou lock) ─────────────────────────────────

  Widget _buildLockedBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
          10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        children: [
          _VoiceActionBtn(
            label: 'Annuler l\'enregistrement',
            icon: PhosphorIcons.trash(),
            iconColor: kError,
            onTap: _cancelVoice,
            decoration: BoxDecoration(
              color: kError.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
          const SizedBox(width: 8),
          _RecordingDots(),
          const SizedBox(width: 6),
          Text(
            _fmtDuration(_recordSecs),
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: _recordPaused ? context.tpInkSub : kError,
            ),
          ),
          if (_recordPaused)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('En pause',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            ),
          const Spacer(),
          _VoiceActionBtn(
            label: _recordPaused ? 'Reprendre l\'enregistrement' : 'Mettre en pause',
            icon: _recordPaused ? PhosphorIcons.play() : PhosphorIcons.pause(),
            iconColor: context.tpInk,
            onTap: _togglePause,
            decoration: BoxDecoration(
              color: context.tpBg,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: context.tpHair),
            ),
          ),
          const SizedBox(width: 8),
          _VoiceActionBtn(
            label: 'Envoyer la note vocale',
            icon: PhosphorIcons.paperPlaneTilt(),
            iconColor: Colors.white,
            onTap: _sendVoice,
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.button),
              boxShadow: Shadows.brand,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton action vocale (barre verrouillée) ──────────────────────────────────

class _VoiceActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final BoxDecoration decoration;

  const _VoiceActionBtn({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: decoration,
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

enum _VoiceMode { idle, holding, locked, paused }

/// Accusé de lecture d'un message envoyé (DM), style WhatsApp.
/// [sent] = partenaire hors ligne (1 coche) · [delivered] = en ligne mais pas
/// encore lu (2 coches grises) · [read] = lu (2 coches bleues).
enum _MsgStatus { sent, delivered, read }

// ── Bouton appel DM (navbar) ───────────────────────────────────────────────────

class _CallIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CallIconBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(icon, color: kPrimary, size: 18),
      ),
      ),
    );
  }
}

// ── Bouton appel groupe (navbar) — menu déroulant audio/vidéo ─────────────────

class _CallMenuButton extends StatelessWidget {
  final VoidCallback onAudio;
  final VoidCallback onVideo;
  const _CallMenuButton({required this.onAudio, required this.onVideo});

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      topLeft.dx, topLeft.dy,
      overlay.size.width - topLeft.dx - box.size.width, 0,
    );

    final choice = await showMenu<String>(
      context: context,
      position: position,
      color: context.tpCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      items: [
        PopupMenuItem(
          value: 'audio',
          child: Row(children: [
            Icon(PhosphorIcons.phone(), color: kPrimary, size: 18),
            const SizedBox(width: 10),
            Text('Appel audio',
              style: TextStyle(color: context.tpInk, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        PopupMenuItem(
          value: 'video',
          child: Row(children: [
            Icon(PhosphorIcons.videoCamera(), color: kPrimary, size: 18),
            const SizedBox(width: 10),
            Text('Appel vidéo',
              style: TextStyle(color: context.tpInk, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ],
    );

    if (choice == 'audio') onAudio();
    if (choice == 'video') onVideo();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Lancer un appel',
      child: GestureDetector(
        onTap: () => _openMenu(context),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.phone(), color: kPrimary, size: 18),
              const SizedBox(width: 2),
              Icon(PhosphorIcons.caretDown(), color: kPrimary, size: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final String userName;
  const _TypingIndicator({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md + 34, 0, Sp.md, 4),
        child: Text(
          '$userName est en train d\'écrire…',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: context.tpInkMute, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final String userName;
  const _RecordingIndicator({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md + 34, 0, Sp.md, 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(PhosphorIcons.microphone(PhosphorIconsStyle.fill),
            size: 13, color: kError),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$userName enregistre une note vocale…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kError,
                fontStyle: FontStyle.italic),
          ),
        ),
      ]),
      ),
    );
  }
}

// ── Recording dots animation ──────────────────────────────────────────────────

class _RecordingDots extends StatefulWidget {
  @override
  State<_RecordingDots> createState() => _RecordingDotsState();
}

class _RecordingDotsState extends State<_RecordingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final opacity = ((_ctrl.value - delay) % 1.0).abs();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: kError.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Bulle de message ──────────────────────────────────────────────────────────

// Coin pointu du côté de l'expéditeur (bas-gauche pour l'autre, bas-droite
// pour moi), partagé par tous les types de contenu de bulle.
BorderRadius bubbleBorderRadius(bool isMe) => BorderRadius.only(
      topLeft: const Radius.circular(Radii.card),
      topRight: const Radius.circular(Radii.card),
      bottomLeft: Radius.circular(isMe ? 20 : 6),
      bottomRight: Radius.circular(isMe ? 6 : 20),
    );

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;
  final String roomId;
  final _MsgStatus? status;
  final bool canReact;
  final List<ChatMessage>? imageGroup;
  final bool isActiveSearchMatch;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.roomId,
    this.status,
    this.canReact = true,
    this.imageGroup,
    this.isActiveSearchMatch = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    // Les annonces admin sont affichées pleine largeur
    if (message.isAnnouncement) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AnnouncementBubble(message: message, roomId: roomId, time: time),
      );
    }

    Widget content;
    if (message.isImage) {
      final urls = (imageGroup ?? [message]).map((m) => m.imageUrl).whereType<String>().toList();
      content = _ImageContent(
        imageUrls: urls,
        isMe: isMe,
        onTapIndex: (i) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ImageViewerScreen(images: urls, initialIndex: i)),
        ),
      );
    } else if (message.isVoice) {
      content = _VoiceContent(
        voiceUrl: message.voiceUrl,
        duration: message.voiceDuration ?? 0,
        isMe: isMe,
        seed: message.id,
      );
    } else if (message.isEventInvite) {
      content = message.invitationId != null
          ? _InvitationDmBubble(message: message, roomId: roomId, isMe: isMe)
          : _EventInviteContent(eventId: message.eventInviteId, isMe: isMe);
    } else {
      content = _TextContent(text: message.content, isMe: isMe);
    }

    // Résultat de recherche actif dans la conversation : anneau + halo
    // pour le repérer d'un coup d'œil sans quitter le fil (heure/expéditeur
    // restent visibles autour, contrairement à une liste de résultats séparée).
    // Même forme (coins asymétriques) que la bulle elle-même pour épouser son
    // contour exact plutôt qu'un rectangle générique autour.
    if (isActiveSearchMatch) {
      final bubbleRadius = bubbleBorderRadius(isMe);
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: bubbleRadius,
          border: Border.all(color: kAccent, width: 2.5),
          boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.35), blurRadius: 10)],
        ),
        child: content,
      );
    }

    // Réactions existantes sous la bulle
    final hasReactions = message.reactions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            TpAvatar(name: message.sender.displayName, imageUrl: message.sender.avatarUrl, size: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(message.sender.displayName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                  ),
                Semantics(
                  label: 'Message de ${message.sender.displayName}',
                  child: GestureDetector(
                  onLongPress: canReact ? () => _showReactionPicker(context, ref, message.id, roomId) : null,
                  child: content,
                  ),
                ),
                if (hasReactions && canReact)
                  _InlineReactionRow(message: message, roomId: roomId, isMe: isMe),
                Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                      child: Text(time,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 3),
                      Icon(
                        // Envoyé (hors ligne) = 1 coche ; livré / lu = 2 coches.
                        status == _MsgStatus.sent
                            ? PhosphorIcons.check(PhosphorIconsStyle.bold)
                            : PhosphorIcons.checks(PhosphorIconsStyle.bold),
                        size: 14,
                        // Lu = bleu plein ; envoyé / livré = gris.
                        color: status == _MsgStatus.read ? kInfo : context.tpInkMute,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showReactionPicker(BuildContext context, WidgetRef ref, String messageId, String roomId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReactionPickerSheet(messageId: messageId, roomId: roomId),
    );
  }
}

// ── Contenu texte ─────────────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  final String text;
  final bool isMe;
  const _TextContent({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? kPrimary : context.tpCard,
        borderRadius: bubbleBorderRadius(isMe),
        boxShadow: Shadows.sm,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: isMe ? Colors.white : context.tpInk,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Contenu image ─────────────────────────────────────────────────────────────

class _ImageContent extends StatelessWidget {
  final List<String> imageUrls;
  final bool isMe;
  final ValueChanged<int> onTapIndex;
  const _ImageContent({required this.imageUrls, required this.isMe, required this.onTapIndex});

  static const _maxTiles = 4;

  BorderRadius get _radius => bubbleBorderRadius(isMe);

  Widget _tile(BuildContext context, String url, {double? width, double? height}) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        // Un seul des deux memCacheWidth/Height doit être fourni : si on borne
        // les deux à la taille (carrée) de la case, le décodeur redimensionne
        // l'image source à ces dimensions exactes et la déforme quand son ratio
        // natif n'est pas 1:1 — BoxFit.cover ne peut rien corriger après coup
        // puisque le bitmap est déjà étiré. En ne bornant que la largeur, le
        // ratio d'origine est préservé au décodage et le crop carré reste net.
        memCacheWidth: width == null ? null : (width * dpr).round(),
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: width, height: height, color: context.tpHair,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, _, _) => Container(
          width: width, height: height, color: context.tpHair,
          child: Icon(PhosphorIcons.imageBroken(), color: context.tpInkMute),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.of(context).size.width * 0.6;

    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: _radius,
        child: Semantics(
          button: true,
          label: 'Voir l\'image',
          child: GestureDetector(
            onTap: () => onTapIndex(0),
            child: _AutoAspectImage(url: imageUrls[0], maxWidth: width),
          ),
        ),
      );
    }

    final shown = imageUrls.length > _maxTiles ? _maxTiles : imageUrls.length;
    final extra = imageUrls.length - _maxTiles;
    // Taille réelle d'une cellule de la grille (2 colonnes, ratio carré) —
    // sert à borner memCacheWidth/Height dans _tile plutôt que de décoder
    // chaque miniature à sa résolution native.
    final cellSize = (width - 2) / 2;

    return ClipRRect(
      borderRadius: _radius,
      child: SizedBox(
        width: width,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: shown,
          itemBuilder: (_, i) {
            final isLastVisibleTile = i == shown - 1 && extra > 0;
            return Semantics(
              button: true,
              label: isLastVisibleTile
                  ? 'Voir $extra image${extra > 1 ? 's' : ''} de plus'
                  : 'Voir l\'image ${i + 1}/${imageUrls.length}',
              child: GestureDetector(
                onTap: () => onTapIndex(i),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _tile(context, imageUrls[i], width: cellSize, height: cellSize),
                    if (isLastVisibleTile)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Text('+$extra',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Image de chat à ratio automatique (évite le recadrage en boîte fixe) ────
// Le backend ne fournit pas les dimensions de l'image dans le message : on
// résout le ratio réel via l'ImageStream avant de figer width/height.

class _AutoAspectImage extends StatefulWidget {
  static const _minHeight = 120.0;

  final String url;
  final double maxWidth;
  final double maxHeight;
  const _AutoAspectImage({
    required this.url,
    required this.maxWidth,
    this.maxHeight = 280,
  });

  @override
  State<_AutoAspectImage> createState() => _AutoAspectImageState();
}

class _AutoAspectImageState extends State<_AutoAspectImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _ratio;

  @override
  void initState() {
    super.initState();
    final stream = CachedNetworkImageProvider(widget.url).resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted && h > 0) setState(() => _ratio = w / h);
    }, onError: (_, _) {
      if (mounted) setState(() => _ratio = 4 / 3);
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final ratio = _ratio ?? 4 / 3;
    var width = widget.maxWidth;
    var height = width / ratio;
    if (height > widget.maxHeight) {
      height = widget.maxHeight;
      width = height * ratio;
    }
    if (height < _AutoAspectImage._minHeight) {
      height = _AutoAspectImage._minHeight;
      width = (height * ratio).clamp(0, widget.maxWidth);
    }
    return CachedNetworkImage(
      imageUrl: widget.url,
      width: width,
      height: height,
      memCacheWidth: (width * dpr).round(),
      memCacheHeight: (height * dpr).round(),
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        width: width, height: height, color: context.tpHair,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => Container(
        width: width, height: height, color: context.tpHair,
        child: Icon(PhosphorIcons.imageBroken(), color: context.tpInkMute),
      ),
    );
  }
}

// ── Contenu note vocale ───────────────────────────────────────────────────────

class _VoiceContent extends StatefulWidget {
  final String? voiceUrl;
  final int duration;
  final bool isMe;
  /// Sert de graine stable pour générer la forme d'onde décorative (même
  /// message → même dessin à chaque reconstruction). On n'a pas les vraies
  /// amplitudes audio côté serveur, donc le tracé n'est pas fidèle au son.
  final String seed;

  const _VoiceContent({
    required this.voiceUrl,
    required this.duration,
    required this.isMe,
    required this.seed,
  });

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  static const _barCount = 28;

  final _player   = AudioPlayer();
  bool  _playing  = false;
  bool  _loading  = false;
  bool  _hasStarted = false;
  Duration _current = Duration.zero;
  Duration? _total;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;
  late final List<double> _bars = _generateBars(widget.seed, _barCount);

  static List<double> _generateBars(String seed, int count) {
    final rnd = Random(seed.hashCode);
    return List.generate(count, (_) => 0.25 + rnd.nextDouble() * 0.75);
  }

  @override
  void initState() {
    super.initState();
    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _current = pos);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      if (s == PlayerState.completed) {
        setState(() { _playing = false; _current = Duration.zero; });
      }
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _total = d);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  int get _totalSeconds =>
      _total?.inSeconds ?? (widget.duration > 0 ? widget.duration : 1);

  double get _progress {
    final total = _totalSeconds;
    return total == 0 ? 0 : (_current.inSeconds / total).clamp(0.0, 1.0);
  }

  Future<void> _toggle() async {
    if (widget.voiceUrl == null) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _playFrom(_progress);
    }
  }

  /// Démarre (ou reprend) la lecture à la fraction [0, 1] donnée — utilisé à
  /// la fois par le bouton lecture et par le tap/glissé sur la forme d'onde.
  Future<void> _playFrom(double fraction) async {
    if (widget.voiceUrl == null) return;
    final target = Duration(milliseconds: (_totalSeconds * 1000 * fraction).round());
    setState(() => _loading = !_hasStarted);
    try {
      if (!_hasStarted) {
        await _player.play(UrlSource(widget.voiceUrl!), position: target);
        _hasStarted = true;
      } else {
        await _player.seek(target);
        await _player.resume();
      }
      if (mounted) setState(() { _playing = true; _loading = false; _current = target; });
    } catch (e) {
      // Lecture impossible (URL injoignable, format non supporté…) : ne pas
      // rester bloqué en « lecture », et prévenir l'utilisateur.
      if (mounted) {
        setState(() { _playing = false; _loading = false; });
        TpToast.error(context, 'Impossible de lire la note vocale.');
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fg     = widget.isMe ? Colors.white : context.tpInk;
    final track  = widget.isMe ? Colors.white38 : context.tpHair;
    final active = widget.isMe ? Colors.white : kPrimary;

    return Container(
      width: MediaQuery.of(context).size.width * 0.68,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMe ? kPrimary : context.tpCard,
        borderRadius: bubbleBorderRadius(widget.isMe),
        boxShadow: Shadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: _playing ? 'Pause' : 'Lecture',
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: widget.isMe ? Colors.white24 : kPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: _loading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: active),
                      )
                    : Icon(
                        _playing
                            ? PhosphorIcons.pause(PhosphorIconsStyle.fill)
                            : PhosphorIcons.play(PhosphorIconsStyle.fill),
                        color: active,
                        size: 18,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VoiceWaveform(
                  bars: _bars,
                  progress: _progress,
                  activeColor: active,
                  trackColor: track,
                  onSeek: widget.voiceUrl == null ? null : _playFrom,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(_current)} / ${_fmt(Duration(seconds: _totalSeconds))}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Forme d'onde interactive (tap/glissé pour avancer la lecture) ─────────────

class _VoiceWaveform extends StatelessWidget {
  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final ValueChanged<double>? onSeek;

  const _VoiceWaveform({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void handleSeek(double dx) {
            final fraction = constraints.maxWidth == 0 ? 0.0 : (dx / constraints.maxWidth).clamp(0.0, 1.0);
            onSeek?.call(fraction);
          }
          return Semantics(
            slider: onSeek != null,
            label: 'Position de lecture',
            value: '${(progress * 100).round()}%',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onSeek == null ? null : (d) => handleSeek(d.localPosition.dx),
              onHorizontalDragUpdate: onSeek == null ? null : (d) => handleSeek(d.localPosition.dx),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < bars.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: (bars[i] * 18).clamp(4, 18),
                        decoration: BoxDecoration(
                          color: (i / bars.length) <= progress ? activeColor : trackColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Contenu invitation événement (simple lien) ────────────────────────────────

class _EventInviteContent extends StatelessWidget {
  final String? eventId;
  final bool isMe;

  const _EventInviteContent({required this.eventId, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.72,
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: bubbleBorderRadius(isMe),
        boxShadow: Shadows.sm,
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimary.withValues(alpha: 0.12), kAccent.withValues(alpha: 0.08)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
            ),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('Invitation à un événement',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Semantics(
              button: true,
              label: 'Voir l\'événement',
              child: GestureDetector(
              onTap: eventId != null ? () => context.push('/event/$eventId') : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: Shadows.brand,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.arrowRight(), color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const Text('Voir l\'événement',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte d'invitation dans un DM (Accept / Refuser) ─────────────────────────

class _InvitationDmBubble extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;
  final bool isMe;

  const _InvitationDmBubble({
    required this.message,
    required this.roomId,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data   = message.eventInviteData;
    final status = message.invitationStatus;
    final isPending = status == 'pending' || status == null;

    final catLabel = data != null ? EventInviteData.categoryLabel(data.category) : 'SOIRÉE';
    final dateStr  = data != null
        ? DateFormat('EEE d MMM · HH\'h\'', 'fr_FR').format(data.startAt.toLocal())
        : '';
    final location = data != null
        ? '${data.addressLabel}${data.quartier.isNotEmpty ? ' · ${data.quartier}' : ''}'
        : '';
    final contrib = data?.contributionItems.isNotEmpty == true
        ? 'Apporte ${data!.contributionItems.first['emoji']} ${data.contributionItems.first['name']}'
        : null;

    return Container(
      width: MediaQuery.of(context).size.width * 0.78,
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
        boxShadow: Shadows.sm,
        border: Border.all(color: context.tpHair),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header gradient
          Container(
            height: 80,
            decoration: BoxDecoration(gradient: trackpartyGradient),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  child: Text(catLabel,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                      child: Text(
                        'Invitation · ${message.sender.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: kPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Event info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              data?.title ?? 'Événement',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk),
            ),
          ),
          if (location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
              child: Text('📍 $location',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: Row(
              children: [
                Text('🗓 $dateStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub)),
                if (contrib != null) ...[
                  const SizedBox(width: 8),
                  Text('·', style: TextStyle(color: context.tpInkMute)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(contrib,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Buttons or status
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: isPending && !isMe
                ? Row(
                    children: [
                      Expanded(
                        child: _InviteActionBtn(
                          label: 'Refuser',
                          isPrimary: false,
                          onTap: () => _respond(context, ref, 'refuse'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InviteActionBtn(
                          label: '✓  Accepter',
                          isPrimary: true,
                          onTap: () => _respond(context, ref, 'accept'),
                        ),
                      ),
                    ],
                  )
                : _StatusChip(status: status ?? 'pending', isMe: isMe),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, String action) async {
    if (message.invitationId == null) return;
    try {
      await ref.read(invitationServiceProvider).respondToInvitation(message.invitationId!, action);
      ref.read(chatThreadProvider(roomId).notifier).updateInvitationStatus(message.invitationId!, action == 'accept' ? 'accepted' : 'refused');
    } catch (e) {
      if (context.mounted) {
        TpToast.error(context, 'Erreur : $e');
      }
    }
  }
}

class _InviteActionBtn extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _InviteActionBtn({required this.label, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isPrimary ? trackpartyGradient : null,
          color: isPrimary ? null : context.tpBg,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: isPrimary ? Shadows.brand : null,
          border: isPrimary ? null : Border.all(color: context.tpHair),
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isPrimary ? Colors.white : context.tpInk,
            )),
        ),
      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isMe;

  const _StatusChip({required this.status, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isAccepted = status == 'accepted';
    final label = isAccepted ? '✓ Acceptée' : (status == 'refused' ? '✗ Refusée' : 'En attente…');
    final color = isAccepted ? kSuccess : (status == 'refused' ? kError : context.tpInkMute);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}

// ── Bulle d'annonce admin (texte + carte événement + réactions) ───────────────

class _AnnouncementBubble extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;
  final String time;

  const _AnnouncementBubble({
    required this.message,
    required this.roomId,
    required this.time,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = message.eventInviteData;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: Shadows.sm,
        border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sender row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                TpAvatar(
                  name: message.sender.displayName,
                  imageUrl: message.sender.avatarUrl,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(message.sender.displayName,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('ADMIN',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimary)),
                          ),
                        ],
                      ),
                      Text(time,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.tpInkMute)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Message text
          if (message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(message.content,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk, height: 1.45)),
            ),
          // Image attachée
          if (message.imageUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.button),
                child: LayoutBuilder(
                  builder: (context, constraints) => _AutoAspectImage(
                    url: message.imageUrl!,
                    maxWidth: constraints.maxWidth,
                    maxHeight: 320,
                  ),
                ),
              ),
            ),
          // Note vocale attachée
          if (message.voiceUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _VoiceContent(
                voiceUrl: message.voiceUrl,
                duration: message.voiceDuration ?? 0,
                isMe: false,
                seed: message.id,
              ),
            ),
          // Event mini-card
          if (data != null)
            Semantics(
              button: true,
              label: 'Voir l\'événement ${data.title}',
              child: GestureDetector(
              onTap: () => context.push('/event/${data.id}'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary.withValues(alpha: 0.08), kAccent.withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Radii.button),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.title,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.tpInk),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            '${data.quartier.isNotEmpty ? data.quartier : data.addressLabel} · ${DateFormat('EEE d MMM', 'fr_FR').format(data.startAt.toLocal())}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tpInkSub),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(PhosphorIcons.caretRight(), color: context.tpInkMute, size: 14),
                  ],
                ),
              ),
              ),
            ),
          // Réactions
          if (message.reactions.isNotEmpty || true) // toujours montrer pour permettre de réagir
            _ReactionRow(message: message, roomId: roomId),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Ligne de réactions ────────────────────────────────────────────────────────

class _ReactionRow extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;

  const _ReactionRow({required this.message, required this.roomId});

  static const _emojis = ['🔥', '❤️', '🎉'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          // Comptes des réactions existantes
          for (final r in message.reactions)
            _ReactionChip(
              emoji: r.emoji,
              count: r.count,
              onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                  .reactToMessage(message.id, r.emoji),
            ),
          const Spacer(),
          // Boutons pour réagir
          for (final emoji in _emojis)
            Semantics(
              button: true,
              label: 'Réagir avec $emoji',
              child: GestureDetector(
              onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                  .reactToMessage(message.id, emoji),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final VoidCallback onTap;

  const _ReactionChip({required this.emoji, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true, label: 'Réaction $emoji · $count',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Picker de réactions (long-press) ─────────────────────────────────────────

class _ReactionPickerSheet extends ConsumerWidget {
  final String messageId;
  final String roomId;

  const _ReactionPickerSheet({required this.messageId, required this.roomId});

  static const _emojis = ['🔥', '❤️', '🎉', '😂', '👏', '😮', '😢', '👍'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, bottom + 12),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(2)),
          ),
          Text('Réagir',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.tpInk)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _emojis.map((emoji) => Semantics(
              button: true, label: 'Réagir avec $emoji',
              child: GestureDetector(
                onTap: () {
                  ref.read(chatThreadProvider(roomId).notifier).reactToMessage(messageId, emoji);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: context.tpBg,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: context.tpHair),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Réactions inline sous une bulle normale ───────────────────────────────────

class _InlineReactionRow extends ConsumerWidget {
  final ChatMessage message;
  final String roomId;
  final bool isMe;

  const _InlineReactionRow({
    required this.message,
    required this.roomId,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Wrap(
        spacing: 4,
        children: message.reactions.map((r) => Semantics(
          button: true, label: 'Réaction ${r.emoji} · ${r.count}',
          child: GestureDetector(
            onTap: () => ref.read(chatThreadProvider(roomId).notifier)
                .reactToMessage(message.id, r.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text('${r.count}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimary)),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Bannière mode broadcast ───────────────────────────────────────────────────

class _BroadcastBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Sp.md, 14, Sp.md, 14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.megaphone(), color: context.tpInkSub, size: 16),
          const SizedBox(width: 8),
          Text(
            'Seuls les organisateurs peuvent envoyer des messages',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub),
          ),
        ],
      ),
    );
  }
}

// ── Bandeau toggle mode événement ─────────────────────────────────────────────

class EventModeBanner extends StatelessWidget {
  final bool attachEvent;
  final VoidCallback onToggle;

  const EventModeBanner({
    super.key,
    required this.attachEvent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: attachEvent ? 'Désactiver le mode annonce' : 'Activer le mode annonce',
      toggled: attachEvent,
      child: GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 6),
        decoration: BoxDecoration(
          gradient: attachEvent
              ? LinearGradient(
                  colors: [kPrimary.withValues(alpha: 0.12), kAccent.withValues(alpha: 0.08)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: attachEvent ? null : context.tpBg,
          border: Border(bottom: BorderSide(color: context.tpHair)),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: attachEvent ? kPrimary : context.tpHair,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(
              attachEvent
                  ? PhosphorIcons.megaphone(PhosphorIconsStyle.fill)
                  : PhosphorIcons.megaphone(),
              color: attachEvent ? Colors.white : context.tpInkMute,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachEvent ? 'Mode annonce activé' : 'Mode annonce désactivé',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: attachEvent ? kPrimary : context.tpInkMute,
                  ),
                ),
                Text(
                  attachEvent
                      ? 'Les messages seront des annonces officielles'
                      : 'Messages envoyés en mode conversation normale',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: attachEvent ? kPrimary.withValues(alpha: 0.7) : context.tpInkMute,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            attachEvent
                ? PhosphorIcons.toggleRight(PhosphorIconsStyle.fill)
                : PhosphorIcons.toggleLeft(PhosphorIconsStyle.fill),
            color: attachEvent ? kPrimary : context.tpInkMute,
            size: 28,
          ),
        ]),
      ),
      ),
    );
  }
}


// ── Bottom sheet renommage groupe ────────────────────────────────────────────

Future<String?> _showRenameGroupSheet(
  BuildContext context,
  String initialName, {
  String title = 'Renommer le groupe',
  String hint = 'Nom du groupe',
}) {
  final ctrl = TextEditingController(text: initialName);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom +
          MediaQuery.of(ctx).padding.bottom + 20;
      return Container(
        decoration: BoxDecoration(
          color: ctx.tpCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: ctx.tpHair,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 80,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.tag)),
                  ),
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ),
      );
    },
  );
}
