import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/invitation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_toast.dart';

/// Écran d'invitation en masse à un événement PRIVÉ (organisateur / co-org) :
///  • sélection depuis des listes (abonnés / communauté / anciens participants)
///    avec « tout sélectionner » — sans rechercher chaque nom ;
///  • lien / code d'invitation partageable.
class EventInviteScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;
  const EventInviteScreen({super.key, required this.eventId, required this.eventTitle});

  @override
  ConsumerState<EventInviteScreen> createState() => _EventInviteScreenState();
}

const _sources = [
  ('followers', 'Abonnés'),
  ('community', 'Communauté'),
  ('participants', 'Anciens'),
];

class _EventInviteScreenState extends ConsumerState<EventInviteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Map<String, List<InviteCandidate>> _bySource = {};
  final Set<String> _loadingSources = {};
  final Set<String> _selected = {};
  bool _sending = false;

  EventInviteLink? _link;
  bool _linkLoading = true;
  bool _linkBusy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _sources.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _loadSource(_sources[_tabs.index].$1);
    });
    _loadSource(_sources.first.$1);
    _loadLink();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadSource(String source) async {
    if (_bySource.containsKey(source) || _loadingSources.contains(source)) return;
    setState(() => _loadingSources.add(source));
    try {
      final list = await ref.read(invitationServiceProvider).getInviteCandidates(
            eventId: widget.eventId,
            source: source,
          );
      if (mounted) setState(() => _bySource[source] = list);
    } catch (_) {
      if (mounted) setState(() => _bySource[source] = []);
    } finally {
      if (mounted) setState(() => _loadingSources.remove(source));
    }
  }

  Future<void> _loadLink() async {
    try {
      final link = await ref.read(invitationServiceProvider).getInviteLink(widget.eventId);
      if (mounted) setState(() => _link = link);
    } catch (_) {
      // pas de lien → on laissera proposer la création
    } finally {
      if (mounted) setState(() => _linkLoading = false);
    }
  }

  void _toggle(InviteCandidate c) {
    if (!c.isInvitable) return;
    setState(() {
      if (!_selected.remove(c.id)) _selected.add(c.id);
    });
  }

  void _selectAll(String source) {
    final invitables =
        (_bySource[source] ?? []).where((c) => c.isInvitable).map((c) => c.id).toList();
    final allSelected = invitables.isNotEmpty && invitables.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(invitables);
      } else {
        _selected.addAll(invitables);
      }
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await ref.read(invitationServiceProvider).bulkInviteToEvent(
            eventId: widget.eventId,
            userIds: _selected.toList(),
          );
      if (!mounted) return;
      final buf = StringBuffer('🎉 ${res.invitedCount} invitation(s) envoyée(s)');
      if (res.upgradeRequired) {
        buf.write(' · plafond atteint, passe au Pro pour inviter plus');
      }
      TpToast.success(context, buf.toString());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      TpToast.error(context, e is ApiException ? e.message : 'Invitation impossible.');
    }
  }

  // ── Lien d'invitation ────────────────────────────────────────────────────────
  Future<void> _createOrRegenerate({bool regenerate = false}) async {
    setState(() => _linkBusy = true);
    try {
      final link = await ref
          .read(invitationServiceProvider)
          .createInviteLink(widget.eventId, regenerate: regenerate);
      if (mounted) setState(() => _link = link);
    } catch (e) {
      if (mounted) {
        TpToast.error(context, e is ApiException ? e.message : 'Action impossible.');
      }
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _deactivate() async {
    setState(() => _linkBusy = true);
    try {
      await ref.read(invitationServiceProvider).deactivateInviteLink(widget.eventId);
      if (mounted) setState(() => _link = null);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  void _copyLink() {
    if (_link == null) return;
    Clipboard.setData(ClipboardData(text: _link!.webUrl));
    TpToast.success(context, 'Lien copié !');
  }

  Future<void> _shareLink() async {
    if (_link == null) return;
    await Share.share(
      'Rejoins « ${widget.eventTitle} » sur TrackParty :\n${_link!.webUrl}',
      subject: widget.eventTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        title: const Text('Inviter'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final s in _sources) Tab(text: s.$2)],
          labelColor: kPrimary,
          indicatorColor: kPrimary,
        ),
      ),
      body: Column(
        children: [
          _linkCard(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [for (final s in _sources) _candidateList(s.$1)],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 8),
              child: TpButton(
                label: 'Inviter (${_selected.length})',
                fullWidth: true,
                state: _sending ? TpButtonState.loading : TpButtonState.idle,
                onPressed: _sending ? null : _send,
              ),
            ),
    );
  }

  Widget _linkCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.tpHair),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.link(), color: kPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: _linkLoading
                ? Text('Lien d\'invitation…',
                    style: TextStyle(fontSize: 13, color: context.tpInkSub))
                : (_link == null
                    ? Text('Crée un lien à partager (WhatsApp, story…)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInk))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lien actif · ${_link!.usesCount} utilisation(s)',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.tpInk)),
                          Text(_link!.webUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: context.tpInkSub)),
                        ],
                      )),
          ),
          const SizedBox(width: 8),
          if (_linkBusy)
            const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else if (_link == null)
            _miniBtn('Créer', () => _createOrRegenerate())
          else ...[
            _iconBtn(PhosphorIcons.copy(), _copyLink, 'Copier'),
            _iconBtn(PhosphorIcons.shareNetwork(), _shareLink, 'Partager'),
            _iconBtn(PhosphorIcons.arrowsClockwise(),
                () => _createOrRegenerate(regenerate: true), 'Régénérer'),
            _iconBtn(PhosphorIcons.trash(), _deactivate, 'Désactiver'),
          ],
        ],
      ),
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.tag)),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap, String tip) => IconButton(
        icon: Icon(icon, size: 18, color: context.tpInkSub),
        onPressed: onTap,
        tooltip: tip,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );

  Widget _candidateList(String source) {
    if (_loadingSources.contains(source) && !_bySource.containsKey(source)) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = _bySource[source] ?? [];
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            switch (source) {
              'followers' => 'Aucun abonné pour le moment.',
              'community' => 'Aucun membre dans ta communauté.',
              _ => 'Aucun ancien participant.',
            },
            textAlign: TextAlign.center,
            style: TextStyle(color: context.tpInkSub, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    final invitables = list.where((c) => c.isInvitable).map((c) => c.id).toList();
    final allSelected = invitables.isNotEmpty && invitables.every(_selected.contains);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: list.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return ListTile(
            dense: true,
            title: Text('${invitables.length} personne(s) invitables',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub)),
            trailing: invitables.isEmpty
                ? null
                : GestureDetector(
                    onTap: () => _selectAll(source),
                    child: Text(allSelected ? 'Tout désélectionner' : 'Tout sélectionner',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800, color: kPrimary)),
                  ),
          );
        }
        final c = list[i - 1];
        final selected = _selected.contains(c.id);
        return ListTile(
          onTap: c.isInvitable ? () => _toggle(c) : null,
          leading: TpAvatar(name: c.displayName, imageUrl: c.avatarUrl, size: 40),
          title: Text(c.displayName,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.isInvitable ? context.tpInk : context.tpInkMute)),
          subtitle: c.statusLabel == null
              ? null
              : Text(c.statusLabel!, style: TextStyle(fontSize: 11, color: context.tpInkSub)),
          trailing: c.isInvitable
              ? Icon(
                  selected ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
                  color: selected ? kPrimary : context.tpHair,
                  size: 24,
                )
              : Icon(PhosphorIcons.minusCircle(), color: context.tpHair, size: 22),
        );
      },
    );
  }
}
