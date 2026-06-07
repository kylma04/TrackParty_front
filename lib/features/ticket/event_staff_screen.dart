import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/chat_model.dart';
import '../../core/models/ticket_model.dart';
import '../../core/providers/ticket_provider.dart';
import '../../core/services/invitation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_confirm_sheet.dart';
import '../../widgets/tp_toast.dart';

class EventStaffScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;
  const EventStaffScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<EventStaffScreen> createState() => _EventStaffScreenState();
}

class _EventStaffScreenState extends ConsumerState<EventStaffScreen> {
  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(eventStaffProvider(widget.eventId));

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // App bar
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
            child: Row(children: [
              Semantics(
                button: true,
                label: 'Retour',
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(Radii.md),
                        boxShadow: Shadows.sm),
                    child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Gestion du staff',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
                  Text(widget.eventTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                ]),
              ),
              Semantics(
                button: true,
                label: 'Ajouter un membre du staff',
                child: GestureDetector(
                  onTap: () => _showAddStaffSheet(context),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        gradient: trackpartyGradient,
                        borderRadius: BorderRadius.circular(Radii.tag),
                        boxShadow: Shadows.sm),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
          ),

          // Explication
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.18))),
              child: Row(children: [
                Icon(PhosphorIcons.info(PhosphorIconsStyle.fill), color: kPrimary, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Les membres du staff peuvent scanner les QR codes des participants à l\'entrée.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary),
                  ),
                ),
              ]),
            ),
          ),

          // Liste du staff
          Expanded(
            child: staffAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.warningCircle(), size: 40, color: context.tpInkMute),
                  const SizedBox(height: 12),
                  Text('Impossible de charger le staff',
                      style: TextStyle(fontSize: 14, color: context.tpInkSub)),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Réessayer',
                    child: GestureDetector(
                      onTap: () => ref.invalidate(eventStaffProvider(widget.eventId)),
                      child: Text('Réessayer',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
                    ),
                  ),
                ]),
              ),
              data: (staff) {
                if (staff.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PhosphorIcons.userCirclePlus(), size: 52, color: context.tpInkMute),
                      const SizedBox(height: 16),
                      Text('Aucun membre du staff',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.tpInk)),
                      const SizedBox(height: 8),
                      Text('Ajoute des membres pour t\'aider à scanner les entrées.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: context.tpInkSub)),
                      const SizedBox(height: 20),
                      Semantics(
                        button: true,
                        label: 'Ajouter un membre du staff',
                        child: GestureDetector(
                          onTap: () => _showAddStaffSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                                gradient: trackpartyGradient,
                                borderRadius: BorderRadius.circular(Radii.md)),
                            child: const Text('Ajouter un membre',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ),
                    ]),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      Sp.md, 0, Sp.md, MediaQuery.of(context).padding.bottom + 20),
                  itemCount: staff.length,
                  addAutomaticKeepAlives: false,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _StaffTile(
                    member: staff[i],
                    onRemove: () => _removeStaff(context, staff[i]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _removeStaff(BuildContext context, EventStaffModel member) async {
    final confirmed = await TpConfirmSheet.show(
      context,
      title: 'Retirer du staff ?',
      body: '${member.userName} ne pourra plus scanner les entrées.',
      confirmLabel: 'Retirer',
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(eventStaffProvider(widget.eventId).notifier).remove(member.userId);
    } catch (_) {
      if (!mounted) return;
      TpToast.error(context, 'Impossible de retirer ce membre');
    }
  }

  void _showAddStaffSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddStaffSheet(eventId: widget.eventId),
    );
  }
}

// ── Staff tile ─────────────────────────────────────────────────────────────────

class _StaffTile extends StatelessWidget {
  final EventStaffModel member;
  final VoidCallback onRemove;
  const _StaffTile({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: Shadows.sm),
      child: Row(children: [
        TpAvatar(name: member.userName, imageUrl: member.userAvatarUrl, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.userName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
            Row(children: [
              Icon(PhosphorIcons.qrCode(), color: kPrimary, size: 12),
              const SizedBox(width: 4),
              Text('Scanner autorisé',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary)),
            ]),
          ]),
        ),
        Semantics(
          button: true,
          label: 'Retirer du staff',
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: kError.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.tag)),
              child: Icon(PhosphorIcons.trash(), color: kError, size: 16),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Add staff bottom sheet ─────────────────────────────────────────────────────

class _AddStaffSheet extends ConsumerStatefulWidget {
  final String eventId;
  const _AddStaffSheet({required this.eventId});

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _ctrl = TextEditingController();
  List<UserSearchResult> _results = [];
  bool _loading = false;
  String? _adding;
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await ref.read(invitationServiceProvider).searchUsers(q.trim());
        if (mounted) setState(() { _results = res; _loading = false; });
      } catch (_) {
        if (mounted) setState(() { _results = []; _loading = false; });
      }
    });
  }

  Future<void> _add(UserSearchResult user) async {
    setState(() => _adding = user.id);
    try {
      await ref.read(eventStaffProvider(widget.eventId).notifier).add(user.id);
      if (!mounted) return;
      Navigator.pop(context);
      TpToast.success(context, '${user.displayName} ajouté au staff');
    } catch (_) {
      if (!mounted) return;
      setState(() => _adding = null);
      TpToast.error(context, 'Impossible d\'ajouter ce membre');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.tpBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      padding: EdgeInsets.fromLTRB(Sp.md, 20, Sp.md, bottomInset + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: context.tpHair, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Text('Ajouter un membre du staff',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.tpInk)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onSearch,
          style: TextStyle(fontSize: 14, color: context.tpInk),
          decoration: InputDecoration(
            hintText: 'Recherche par nom…',
            hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute),
            prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 18),
            filled: true,
            fillColor: context.tpCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: BorderSide(color: context.tpHair),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: BorderSide(color: context.tpHair),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.button),
              borderSide: BorderSide(color: kPrimary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_results.isEmpty && _ctrl.text.trim().length >= 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Aucun résultat',
                style: TextStyle(fontSize: 14, color: context.tpInkSub)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              addAutomaticKeepAlives: false,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final u = _results[i];
                final isAdding = _adding == u.id;
                return Semantics(
                  button: true,
                  label: 'Ajouter ${u.displayName} au staff',
                  child: GestureDetector(
                  onTap: isAdding ? null : () => _add(u),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: context.tpCard,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: context.tpHair)),
                    child: Row(children: [
                      TpAvatar(name: u.displayName, imageUrl: u.avatarUrl, size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(u.displayName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                color: context.tpInk)),
                      ),
                      isAdding
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  gradient: trackpartyGradient,
                                  borderRadius: BorderRadius.circular(Radii.sm)),
                              child: const Text('Ajouter',
                                  style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                    ]),
                  ),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}
