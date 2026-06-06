import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/invitation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  final String userId;
  final String displayName;
  final String? avatarUrl;

  const NewChatScreen({
    super.key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  bool _redirecting = false;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    return roomsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _buildScreen(context),
      data: (rooms) {
        final existing = rooms.where((r) =>
            r.isPrivate &&
            r.membersPreview.any((m) => m.id == widget.userId)).firstOrNull;

        if (existing != null && !_redirecting) {
          _redirecting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.replace('/chat/${existing.id}');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildScreen(context);
      },
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(context),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TpAvatar(
                    name: widget.displayName,
                    imageUrl: widget.avatarUrl,
                    size: 72,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.displayName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                    child: Text(
                      'Vous n\'êtes pas encore en contact.\nEnvoyez une demande pour commencer à échanger.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.tpInkSub,
                        height: 1.55,
                      ),
                    ),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Sp.lg, vertical: 12),
                      decoration: BoxDecoration(
                        color: kSuccess.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: kSuccess, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Demande envoyée !',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kSuccess,
                          ),
                        ),
                      ]),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: kError),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_sent)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.lg),
                child: GestureDetector(
                  onTap: _sending ? null : _sendRequest,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: trackpartyGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: Shadows.brand,
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                PhosphorIcons.paperPlaneTilt(
                                    PhosphorIconsStyle.fill),
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Envoyer la demande',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(PhosphorIcons.caretLeft(),
                  color: context.tpInk, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Nouveau message',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.tpInk,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequest() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(invitationServiceProvider)
          .sendInvitation(receiverId: widget.userId);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Déjà connectés → ouvrir directement le DM
      if (e.message.contains('déjà connectés')) {
        try {
          final room = await ref
              .read(chatServiceProvider)
              .getOrCreatePrivateRoom(widget.userId);
          if (!mounted) return;
          context.replace('/chat/${room.id}');
        } on ApiException catch (e2) {
          setState(() {
            _sending = false;
            _error = e2.message;
          });
        }
      } else {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }
}
