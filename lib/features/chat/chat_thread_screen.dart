import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';


import '../../core/models/chat_model.dart';
import '../../core/providers/auth_provider.dart' show authNotifierProvider, AuthAuthenticated;
import '../../core/providers/chat_provider.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ChatThreadScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await ref.read(chatThreadProvider(widget.roomId).notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatThreadProvider(widget.roomId));
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final me = authState is AuthAuthenticated ? authState.user : null;

    // Auto-scroll quand de nouveaux messages arrivent
    ref.listen(chatThreadProvider(widget.roomId), (_, next) {
      if (next is AsyncData) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: context.tpBg,
      body: Column(
        children: [
          _buildNavBar(context),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Erreur de chargement',
                  style: TextStyle(color: context.tpInkSub)),
              ),
              data: (messages) => _buildMessageList(context, messages, me?.id),
            ),
          ),
          _buildComposer(context),
        ],
      ),
    );
  }

  // ── NavBar ────────────────────────────────────────────────────────────────
  Widget _buildNavBar(BuildContext context) {
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
              button: true,
              label: 'Retour',
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.chevron_left, color: context.tpInk, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const TpAvatar(name: 'Conversation', size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conversation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                        color: context.tpInk, letterSpacing: -0.3)),
                  Text('Chat TrackParty',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Options',
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.more_vert, color: context.tpInk, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Liste de messages ─────────────────────────────────────────────────────
  Widget _buildMessageList(BuildContext context, List<ChatMessage> messages, String? myId) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Commence la conversation !',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tpInkSub)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg     = messages[i];
        final isMe    = msg.sender.id == myId;
        final showDay = i == 0 ||
            !_sameDay(messages[i - 1].createdAt, msg.createdAt);

        return Column(
          children: [
            if (showDay) _buildDaySeparator(context, msg.createdAt),
            _MessageBubble(message: msg, isMe: isMe),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
          decoration: BoxDecoration(
              color: context.tpHair, borderRadius: BorderRadius.circular(999)),
          child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.tpInkSub)),
        ),
      ),
    );
  }

  // ── Composer ──────────────────────────────────────────────────────────────
  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(Sp.md, 10, Sp.md,
          10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.tpCard,
        border: Border(top: BorderSide(color: context.tpHair)),
      ),
      child: Row(
        children: [
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
                decoration: InputDecoration(
                  hintText: 'Écris un message…',
                  hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInkMute),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Envoyer le message',
            child: GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: Shadows.brand,
                ),
                child: Icon(Icons.send_outlined, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulle de message ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            TpAvatar(name: message.sender.displayName, size: 28),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(message.sender.displayName,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.68,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe ? trackpartyGradient : null,
                  color: isMe ? null : context.tpCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 20),
                  ),
                  boxShadow: isMe ? Shadows.brand : Shadows.sm,
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : context.tpInk,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Text(time,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.tpInkMute)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
