import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/moderation_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class ReportSheet extends ConsumerStatefulWidget {
  final String targetType; // 'event' | 'user' | 'comment'
  final String targetId;
  final String? targetName;
  final String? blockUserId; // if provided, shows "also block" toggle

  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.blockUserId,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    String? targetName,
    String? blockUserId,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        blockUserId: blockUserId,
      ),
    );
  }

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  int _selected = 1;
  bool _block    = false;
  bool _loading  = false;

  static const _reasons = [
    (emoji: '⚠️', title: 'Événement frauduleux',     sub: 'Faux event, arnaque',           api: 'fraud'),
    (emoji: '🚫', title: 'Contenu inapproprié',       sub: 'Violence, haine, illégal',      api: 'inappropriate'),
    (emoji: '🔁', title: 'Spam ou duplicata',         sub: 'Publié plusieurs fois',         api: 'spam'),
    (emoji: '👤', title: "Usurpation d'identité",     sub: 'Se fait passer pour qqn',       api: 'other'),
    (emoji: '⛔', title: 'Mineurs en danger',          sub: 'Protection enfants',            api: 'inappropriate'),
    (emoji: '❓', title: 'Autre',                      sub: 'Décris dans le commentaire',    api: 'other'),
  ];

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(moderationServiceProvider);
      await svc.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reasons[_selected].api,
      );
      if (_block && widget.blockUserId != null) {
        await svc.block(widget.blockUserId!);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement envoyé. Merci !')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBlockToggle = widget.blockUserId != null;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: context.tpCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 5,
                decoration: BoxDecoration(color: context.tpHair, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(PhosphorIcons.warning(), color: kError, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Signaler ce contenu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                      color: context.tpInk, letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text('Aide-nous à garder TrackParty safe',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.tpInkSub)),
              ])),
            ]),
            if (widget.targetName != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const SizedBox(width: 4),
                  Icon(PhosphorIcons.flag(), color: context.tpInkSub, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.targetName!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tpInk))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            Text('CHOISIS UN MOTIF',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                  color: context.tpInkSub, letterSpacing: 0.3)),
            const SizedBox(height: 10),
            ...List.generate(_reasons.length, (i) {
              final r = _reasons[i];
              final active = i == _selected;
              return Semantics(
                button: true, selected: active, label: r.title,
                child: GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: active ? gradientSoft : null,
                      color: active ? null : context.tpCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? kPrimary : context.tpHair, width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: active ? Colors.white : context.tpBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(r.emoji, style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                        const SizedBox(height: 1),
                        Text(r.sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                      ])),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? kPrimary : null,
                          border: active ? null : Border.all(color: context.tpHair, width: 2),
                        ),
                        child: active ? Icon(PhosphorIcons.check(), color: Colors.white, size: 12) : null,
                      ),
                    ]),
                  ),
                ),
              );
            }),
            if (showBlockToggle) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: kError.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(PhosphorIcons.prohibit(), color: kError, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bloquer cet utilisateur',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.tpInk)),
                    const SizedBox(height: 1),
                    Text('Tu ne verras plus ses events',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkSub)),
                  ])),
                  Semantics(
                    toggled: _block,
                    label: 'Bloquer cet utilisateur',
                    child: GestureDetector(
                      onTap: () => setState(() => _block = !_block),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44, height: 26, padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _block ? kPrimary : context.tpHair,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: _block ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Annuler le signalement',
                  child: GestureDetector(
                    onTap: _loading ? null : () => Navigator.pop(context),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(color: context.tpBg, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: Text('Annuler',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.tpInk)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Envoyer le signalement',
                  child: GestureDetector(
                    onTap: _loading ? null : _submit,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [const BoxShadow(color: Color(0x59F43F5E), blurRadius: 20, offset: Offset(0, 8))],
                      ),
                      alignment: Alignment.center,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(PhosphorIcons.flag(), color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              const Text('Envoyer',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                            ]),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Center(
              child: Text('🔒 Anonyme · Notre équipe modération examine sous 24h',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tpInkMute, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
