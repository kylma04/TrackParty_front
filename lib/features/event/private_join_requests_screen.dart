
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/event_model.dart';
import '../../core/services/event_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../theme/shadows.dart';
import '../../widgets/tp_avatar.dart';
import '../../core/providers/event_provider.dart';

class PrivateJoinRequestsScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const PrivateJoinRequestsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<PrivateJoinRequestsScreen> createState() =>
      _PrivateJoinRequestsScreenState();
}

class _PrivateJoinRequestsScreenState
    extends ConsumerState<PrivateJoinRequestsScreen> {
  bool _loading = true;
  List<PrivateJoinRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(eventServiceProvider)
          .getPrivateJoinRequests(widget.eventId);

      if (!mounted) return;

      setState(() {
        _requests = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(
    PrivateJoinRequestModel req,
    bool accept,
  ) async {
    try {
      await ref.read(eventServiceProvider).respondPrivateJoinRequest(
            widget.eventId,
            req.id,
            accept: accept,
          );

      if (!mounted) return;

      setState(() {
        _requests.removeWhere((e) => e.id == req.id);
      });
      ref.invalidate(eventDetailProvider(widget.eventId));
      ref.invalidate(nearbyEventsFeedProvider);
      ref.invalidate(trendingEventsFeedProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Demande acceptée' : 'Demande refusée',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur'),
          backgroundColor: kError,
        ),
      );
    }
  }

  void _showRequesterProfile(PrivateJoinRequestModel req) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.cardLg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TpAvatar(
              name: req.userName,
              imageUrl: req.userAvatarUrl,
              size: 72,
            ),
            const SizedBox(height: 12),
            Text(
              'Profil utilisateur',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Nom'),
              subtitle: Text(req.userName),
            ),
            const SizedBox(height: 8),
            Text(
              'Demande de participation à cet événement privé',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        title: const Text('Demandes privées'),
        backgroundColor: context.tpCard,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.usersThree(),
                        size: 48,
                        color: context.tpInkMute,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune demande en attente',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.tpInkSub,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Sp.md),
                  itemCount: _requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final req = _requests[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A1B1A2E),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar cliquable → profil
                          Semantics(
                            button: true,
                            label: 'Voir le profil de ${req.userName}',
                            child: GestureDetector(
                              onTap: () =>
                                  _showRequesterProfile(req),
                              child: TpAvatar(
                                name: req.userName,
                                imageUrl: req.userAvatarUrl,
                                size: 52,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Nom + date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  button: true,
                                  label: 'Voir le profil de ${req.userName}',
                                  child: GestureDetector(
                                    onTap: () => context
                                        .push('/promoter/${req.userId}'),
                                    child: Text(
                                      req.userName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: context.tpInk,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Demande envoyée le ${DateFormat('d MMM à HH\'h\'mm', 'fr_FR').format(req.createdAt.toLocal())}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.tpInkSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Boutons Refuser / Accepter
                          Column(
                            children: [
                              Semantics(
                                button: true,
                                label: 'Refuser ${req.userName}',
                                child: GestureDetector(
                                  onTap: () => _respond(req, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kError.withValues(alpha: 0.10),
                                      borderRadius:
                                          BorderRadius.circular(Radii.tag),
                                      border: Border.all(
                                        color: kError.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: const Text(
                                      'Refuser',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: kError,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Semantics(
                                button: true,
                                label: 'Accepter ${req.userName}',
                                child: GestureDetector(
                                  onTap: () => _respond(req, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kSuccess.withValues(alpha: 0.10),
                                      borderRadius:
                                          BorderRadius.circular(Radii.tag),
                                      border: Border.all(
                                        color: kSuccess.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: const Text(
                                      'Accepter',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: kSuccess,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}