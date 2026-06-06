import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/event_model.dart';
import '../../core/services/event_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_avatar.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class EventParticipantsScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventParticipantsScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventParticipantsScreen> createState() => _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends ConsumerState<EventParticipantsScreen> {
  int _tab = 0;

  EventModel? _event;
  List<ParticipantModel>? _participants;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = ref.read(eventServiceProvider);
      final results = await Future.wait([
        svc.getEvent(widget.eventId),
        svc.getParticipants(widget.eventId),
      ]);
      if (mounted) {
        setState(() {
          _event        = results[0] as EventModel;
          _participants = results[1] as List<ParticipantModel>;
          _loading      = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Dérivés ───────────────────────────────────────────────────────────────

  List<ParticipantModel> get _confirmed =>
      (_participants ?? []).where((p) => p.isConfirmed).toList();

  List<ParticipantModel> get _pending =>
      (_participants ?? []).where((p) => p.isPending).toList();

  List<ParticipantModel> get _allSorted {
    final list = List<ParticipantModel>.from(_participants ?? []);
    list.sort((a, b) => a.userName.compareTo(b.userName));
    return list;
  }

  // Groups: participants grouped by contribution item, then a fallback "no item" group
  List<_Group> get _groups {
    final event = _event;
    final participants = _participants;
    if (event == null || participants == null) return [];

    // Index confirmed participants by item id
    final Map<String?, List<ParticipantModel>> byItem = {};
    for (final p in participants) {
      byItem.putIfAbsent(p.contributionItemId, () => []).add(p);
    }

    final groups = <_Group>[];
    const groupColors = [
      kAccent, kTertiary, kSecondary,
      kInfo, kCategoryArt, kWarning,
    ];

    // Known contribution items from event
    for (int i = 0; i < event.contributionItems.length; i++) {
      final item = event.contributionItems[i];
      final itemPeople = byItem[item.id] ?? [];
      byItem.remove(item.id);
      groups.add(_Group(
        label: '${item.emoji} ${item.name}',
        current: item.quantityTaken,
        total: item.quantityTotal,
        color: groupColors[i % groupColors.length],
        done: item.quantityTaken >= item.quantityTotal,
        people: itemPeople,
      ));
    }

    // Participants without a contribution item
    final noItem = byItem[null] ?? [];
    for (final extra in byItem.entries) {
      if (extra.key != null) noItem.addAll(extra.value);
    }
    if (noItem.isNotEmpty) {
      groups.add(_Group(
        label: '🎟 Participants',
        current: noItem.length,
        total: event.maxParticipants ?? noItem.length,
        color: kPrimary,
        done: false,
        people: noItem,
      ));
    }

    return groups;
  }

  int get _totalContribCurrent =>
      (_event?.contributionItems ?? []).fold(0, (s, i) => s + i.quantityTaken);

  int get _totalContribTotal =>
      (_event?.contributionItems ?? []).fold(0, (s, i) => s + i.quantityTotal);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Erreur de chargement', style: TextStyle(color: context.tpInkSub, fontSize: 14)),
          const SizedBox(height: 12),
          Semantics(
            button: true, label: 'Réessayer',
            child: GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(gradient: trackpartyGradient, borderRadius: BorderRadius.circular(Radii.md)),
              child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            ),
          ),
        ]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(children: [
        _buildStatsBanner(),
        _buildTabs(context),
        _buildContent(),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
      child: Row(
        children: [
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
                  boxShadow: Shadows.sm,
                ),
                child: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Participants',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                      color: context.tpInk, letterSpacing: -0.4)),
                if (_event != null)
                  Text(_event!.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Actualiser',
            child: GestureDetector(
              onTap: _load,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: trackpartyGradient,
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: const [BoxShadow(color: Color(0x4D7C3AED), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Icon(PhosphorIcons.arrowsClockwise(), color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats banner ──────────────────────────────────────────────────────────

  Widget _buildStatsBanner() {
    final total     = _participants?.length ?? 0;
    final maxP      = _event?.maxParticipants ?? total;
    final contribC  = _totalContribCurrent;
    final contribT  = _totalContribTotal;
    final pct       = contribT > 0 ? '${(contribC / contribT * 100).round()}% rempli' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 14),
        decoration: BoxDecoration(
          gradient: trackpartyGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x4D7C3AED), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40, right: -20,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INSCRITS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '$total',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -1, height: 1),
                        ),
                        TextSpan(
                          text: ' / $maxP',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: Colors.white70, height: 1),
                        ),
                      ]),
                    ),
                  ],
                ),
                if (contribT > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('CONTRIBUTIONS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 0.3)),
                      const SizedBox(height: 4),
                      Text('$contribC / $contribT',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -0.8, height: 1)),
                      const SizedBox(height: 2),
                      Text(pct,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget _buildTabs(BuildContext context) {
    final tabs = [
      ('Par item',   _confirmed.length),
      ('A-Z',        _participants?.length ?? 0),
      ('En attente', _pending.length),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 0),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final (label, count) = tabs[i];
          final active = i == _tab;
          return Semantics(
            label: label,
            selected: active,
            button: true,
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? context.tpCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.tag),
                  border: Border.all(
                    color: active ? context.tpHair : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: active ? Shadows.sm : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: active ? context.tpInk : context.tpInkSub,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: active ? kPrimary.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text('$count',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: active ? kPrimary : context.tpInkMute,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 0),
      child: switch (_tab) {
        0 => _buildGroupsTab(),
        1 => _buildAzTab(),
        2 => _buildPendingTab(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildGroupsTab() {
    final gs = _groups;
    if (gs.isEmpty) {
      return _buildEmpty('Aucun participant confirmé');
    }
    return Column(
      children: gs.map((g) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _ContribGroup(group: g),
      )).toList(),
    );
  }

  Widget _buildAzTab() {
    final list = _allSorted;
    if (list.isEmpty) return _buildEmpty('Aucun participant');
    return _ParticipantList(people: list);
  }

  Widget _buildPendingTab() {
    final list = _pending;
    if (list.isEmpty) {
      return _buildEmpty('Aucune inscription en attente');
    }
    return _ParticipantList(people: list);
  }

  Widget _buildEmpty(String msg) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Center(
      child: Text(msg,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tpInkMute)),
    ),
  );
}

// ── Group model ───────────────────────────────────────────────────────────────

class _Group {
  final String label;
  final int current;
  final int total;
  final Color color;
  final bool done;
  final List<ParticipantModel> people;
  const _Group({
    required this.label, required this.current, required this.total,
    required this.color, this.done = false, required this.people,
  });
}

// ── ContribGroup ──────────────────────────────────────────────────────────────

class _ContribGroup extends StatelessWidget {
  final _Group group;
  const _ContribGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    final pct = group.total > 0 ? group.current / group.total : 0.0;
    final statusColor = group.done ? kSuccess : group.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: const [BoxShadow(color: Color(0x0F1B1A2E), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(group.label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.tpInk)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  group.done ? '✓ Complet' : '${group.current}/${group.total}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: context.tpHair,
              valueColor: AlwaysStoppedAnimation(statusColor),
              minHeight: 4,
            ),
          ),
          if (group.people.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Aucun participant pour l\'instant',
                style: TextStyle(fontSize: 12, color: context.tpInkMute)),
            )
          else ...[
            const SizedBox(height: 12),
            ...group.people.asMap().entries.map((e) => _PersonRow(
              person: e.value, isFirst: e.key == 0,
            )),
          ],
        ],
      ),
    );
  }
}

// ── Flat list ─────────────────────────────────────────────────────────────────

class _ParticipantList extends StatelessWidget {
  final List<ParticipantModel> people;
  const _ParticipantList({required this.people});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: const [BoxShadow(color: Color(0x0F1B1A2E), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        children: people.asMap().entries.map((e) =>
          _PersonRow(person: e.value, isFirst: e.key == 0),
        ).toList(),
      ),
    );
  }
}

// ── Person row ────────────────────────────────────────────────────────────────

class _PersonRow extends StatelessWidget {
  final ParticipantModel person;
  final bool isFirst;
  const _PersonRow({required this.person, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final confirmed = person.isConfirmed;
    return Column(
      children: [
        if (!isFirst) Divider(height: 1, color: context.tpHair),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              TpAvatar(
                name: person.userName,
                imageUrl: person.userAvatarUrl,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.userName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                    if (person.contributionItemName != null)
                      Text(
                        '${person.contributionItemEmoji ?? ''} ${person.contributionItemName}'
                        '${person.quantity > 1 ? ' ×${person.quantity}' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confirmed
                      ? kSuccess.withValues(alpha: 0.10)
                      : kWarning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  confirmed ? '✓ OK' : 'En attente',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: confirmed ? kSuccess : kWarning,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: context.tpBg,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(PhosphorIcons.chatCircle(), color: context.tpInkSub, size: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
