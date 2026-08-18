import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/chat_model.dart';
import '../../core/providers/chat_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_button.dart';

/// Sélection multiple de contacts (personnes avec qui une conversation privée
/// existe déjà) — utilisé pour créer un groupe ou y ajouter des membres.
/// Retourne la liste des IDs sélectionnés via `Navigator.pop`, ou `null` si annulé.
class ContactPickerScreen extends ConsumerStatefulWidget {
  const ContactPickerScreen({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.excludeIds = const {},
  });

  final String title;
  final String confirmLabel;
  final Set<String> excludeIds;

  @override
  ConsumerState<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final Set<String> _selected = {};
  String _query = '';

  List<ChatMemberPreview> _contacts(List<ChatRoomModel> rooms) {
    final seen = <String>{};
    final contacts = <ChatMemberPreview>[];
    for (final r in rooms) {
      if (!r.isPrivate || r.membersPreview.isEmpty) continue;
      final partner = r.membersPreview.first;
      if (widget.excludeIds.contains(partner.id) || seen.contains(partner.id)) continue;
      seen.add(partner.id);
      contacts.add(partner);
    }
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    return contacts;
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchField(context),
            Expanded(
              child: roomsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Impossible de charger tes contacts',
                      style: TextStyle(color: context.tpInkSub)),
                ),
                data: (rooms) {
                  final all = _contacts(rooms);
                  final filtered = _query.isEmpty
                      ? all
                      : all.where((c) => c.displayName.toLowerCase().contains(_query.toLowerCase())).toList();
                  if (all.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          "Tu n'as pas encore de contact. Démarre une conversation privée d'abord.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.tpInkSub, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('Aucun résultat', style: TextStyle(color: context.tpInkSub)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(height: 1, indent: 68, color: context.tpHair),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final checked = _selected.contains(c.id);
                      return _ContactRow(
                        contact: c,
                        checked: checked,
                        onTap: () => setState(() {
                          if (checked) {
                            _selected.remove(c.id);
                          } else {
                            _selected.add(c.id);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.sm),
                child: TpButton(
                  label: '${widget.confirmLabel} (${_selected.length})',
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).pop(_selected.toList()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 8),
      child: Row(children: [
        Semantics(
          button: true, label: 'Retour',
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 44, height: 44,
              child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(widget.title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.tpInk)),
      ]),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
      child: Container(
        decoration: BoxDecoration(
          color: context.tpCard,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: context.tpHair),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Icon(PhosphorIcons.magnifyingGlass(), color: context.tpInkMute, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tpInk),
              decoration: InputDecoration(
                hintText: 'Rechercher un contact…',
                hintStyle: TextStyle(fontSize: 14, color: context.tpInkMute, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final ChatMemberPreview contact;
  final bool checked;
  final VoidCallback onTap;

  const _ContactRow({required this.contact, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: checked,
      label: contact.displayName,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
          child: Row(children: [
            TpAvatar(name: contact.displayName, imageUrl: contact.avatarUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(contact.displayName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.tpInk)),
            ),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? kPrimary : Colors.transparent,
                border: checked ? null : Border.all(color: context.tpHair, width: 2),
              ),
              child: checked ? Icon(PhosphorIconsBold.check, color: Colors.white, size: 16) : null,
            ),
          ]),
        ),
      ),
    );
  }
}
