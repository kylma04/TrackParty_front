import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/blocked_user_model.dart';
import '../../core/models/chat_model.dart';
import '../../core/services/invitation_service.dart';
import '../../core/services/moderation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_confirm_sheet.dart';
import '../../widgets/tp_field.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
      BuildContext context, WidgetRef ref, BlockedUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await TpConfirmSheet.show(
      context,
      title: 'Débloquer ${user.displayName} ?',
      body: 'Vous pourrez de nouveau voir vos événements, profils et messages '
          'mutuels.',
      confirmLabel: 'Débloquer',
      confirmColor: kPrimary,
      icon: PhosphorIcons.lockKeyOpen(),
    );
    if (!confirmed) return;

    try {
      await ref.read(moderationServiceProvider).unblock(user.blockedId);
      ref.invalidate(blockedUsersProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${user.displayName} débloqué.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Échec du déblocage. Réessaie.')),
      );
    }
  }

  Future<void> _openBlockSheet(BuildContext context, WidgetRef ref) async {
    final blocked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BlockUserSheet(),
    );
    if (blocked == true) ref.invalidate(blockedUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Utilisateurs bloqués',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Bloquer un utilisateur',
            icon: Icon(PhosphorIcons.userPlus(), color: kPrimary, size: 22),
            onPressed: () => _openBlockSheet(context, ref),
          ),
        ],
      ),
      body: blocked.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (_, _) =>
            _ErrorView(onRetry: () => ref.invalidate(blockedUsersProvider)),
        data: (users) {
          if (users.isEmpty) {
            return _EmptyView(onBlock: () => _openBlockSheet(context, ref));
          }
          return RefreshIndicator(
            color: kPrimary,
            onRefresh: () async => ref.invalidate(blockedUsersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Sp.md, 16, Sp.md, 40),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _BlockedRow(
                user: users[i],
                onUnblock: () => _unblock(context, ref, users[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Ligne utilisateur bloqué ──────────────────────────────────────────────────

class _BlockedRow extends StatelessWidget {
  final BlockedUser user;
  final VoidCallback onUnblock;
  const _BlockedRow({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(children: [
        _Avatar(url: user.avatarUrl, name: user.displayName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.tpInk)),
            if (user.blockedAt != null)
              Text('Bloqué le ${_fmtDate(user.blockedAt!)}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkSub)),
          ]),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onUnblock,
          style: TextButton.styleFrom(
            backgroundColor: kPrimary.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.button)),
          ),
          child: const Text('Débloquer',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
        ),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(),
          errorWidget: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration:
          const BoxDecoration(gradient: trackpartyGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }
}

// ── États ─────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onBlock;
  const _EmptyView({required this.onBlock});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kSuccess.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(PhosphorIcons.userCheck(), color: kSuccess, size: 34),
              ),
              const SizedBox(height: 18),
              Text('Personne de bloqué',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk)),
              const SizedBox(height: 6),
              Text(
                  'Quand tu bloques un membre, il apparaît ici. '
                  'Vous ne voyez plus vos événements, profils et messages mutuels.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: context.tpInkSub)),
              const SizedBox(height: 22),
              TextButton.icon(
                onPressed: onBlock,
                icon: Icon(PhosphorIcons.userPlus(), size: 18, color: kPrimary),
                label: const Text('Bloquer un utilisateur',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: kPrimary)),
                style: TextButton.styleFrom(
                  backgroundColor: kPrimary.withValues(alpha: 0.10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.button)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Feuille de recherche pour bloquer un nouvel utilisateur ───────────────────

class _BlockUserSheet extends ConsumerStatefulWidget {
  const _BlockUserSheet();

  @override
  ConsumerState<_BlockUserSheet> createState() => _BlockUserSheetState();
}

class _BlockUserSheetState extends ConsumerState<_BlockUserSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _busyUserId;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final res = await ref.read(invitationServiceProvider).searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
        _searched = true;
      });
    }
  }

  Future<void> _block(UserSearchResult user) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await TpConfirmSheet.show(
      context,
      title: 'Bloquer ${user.displayName} ?',
      body: 'Vous ne verrez plus vos événements, profils et messages mutuels. '
          'Tu pourras le débloquer à tout moment.',
      confirmLabel: 'Bloquer',
      icon: PhosphorIcons.prohibit(),
    );
    if (!confirmed) return;

    setState(() => _busyUserId = user.id);
    try {
      await ref.read(moderationServiceProvider).block(user.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text('${user.displayName} bloqué.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyUserId = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Échec du blocage. Réessaie.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
        ),
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: context.tpHair,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(PhosphorIcons.prohibit(), color: kError, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Bloquer un utilisateur',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: context.tpInk)),
            ]),
            const SizedBox(height: 16),
            TpField(
              label: 'Rechercher par nom',
              prefixIcon: PhosphorIcons.magnifyingGlass(),
              controller: _ctrl,
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: _buildResults(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    if (!_searched) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Saisis au moins 2 caractères pour rechercher.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub)),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Aucun utilisateur trouvé.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.tpInkSub)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = _results[i];
        final busy = _busyUserId == u.id;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.tpCard,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(children: [
            _Avatar(url: u.avatarUrl, name: u.displayName),
            const SizedBox(width: 12),
            Expanded(
              child: Text(u.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.tpInk)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: busy ? null : () => _block(u),
              style: TextButton.styleFrom(
                backgroundColor: kError.withValues(alpha: 0.10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.button)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kError))
                  : const Text('Bloquer',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kError)),
            ),
          ]),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.cloudSlash(), color: context.tpInkMute, size: 48),
              const SizedBox(height: 16),
              Text('Impossible de charger la liste.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkSub)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('Réessayer',
                    style:
                        TextStyle(color: kPrimary, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _fmtDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}
