import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/content_model.dart';
import '../../core/services/content_service.dart';
import '../../theme/colors.dart';
import '../../theme/gradients.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(supportProvider);

    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Aide & support',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        centerTitle: true,
      ),
      body: support.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (_, _) =>
            _ErrorView(onRetry: () => ref.invalidate(supportProvider)),
        data: (s) => _HelpBody(support: s),
      ),
    );
  }
}

class _HelpBody extends StatelessWidget {
  final SupportContent support;
  const _HelpBody({required this.support});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Aucune application disponible pour cette action.')));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir ce lien.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = <Widget>[];
    if (support.whatsapp.isNotEmpty) {
      channels.add(_ContactRow(
        icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
        color: kSuccess,
        label: 'WhatsApp',
        sub: 'Réponse rapide par message',
        onTap: () =>
            _launch(context, Uri.parse('https://wa.me/${support.whatsapp}')),
      ));
    }
    if (support.email.isNotEmpty) {
      channels.add(_ContactRow(
        icon: PhosphorIcons.envelopeSimple(),
        color: kPrimary,
        label: 'Email',
        sub: support.email,
        onTap: () =>
            _launch(context, Uri(scheme: 'mailto', path: support.email)),
      ));
    }
    if (support.phone.isNotEmpty) {
      channels.add(_ContactRow(
        icon: PhosphorIcons.phone(),
        color: kAccent,
        label: 'Téléphone',
        sub: support.phone,
        onTap: () => _launch(context, Uri(scheme: 'tel', path: support.phone)),
      ));
    }

    final grouped = _groupByCategory(support.faq);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.md, 20, Sp.md, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: trackpartyGradient,
              borderRadius: BorderRadius.circular(Radii.cardLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.lifebuoy(PhosphorIconsStyle.fill),
                    color: Colors.white, size: 34),
                const SizedBox(height: 12),
                Text(
                  support.intro.isNotEmpty
                      ? support.intro
                      : "L'équipe TrackParty est là pour t'aider.",
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (support.responseTime.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PhosphorIcons.clock(), color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(support.responseTime,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // ── Support in-app (tickets) ───────────────────────────────────
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/support'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.tag)),
                  child: Icon(PhosphorIcons.chatsCircle(),
                      color: kPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Contacter le support',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.tpInk)),
                      Text('Ouvre une demande, on te répond dans l’app',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: context.tpInkSub)),
                    ])),
                Icon(PhosphorIcons.caretRight(),
                    color: context.tpInkMute, size: 16),
              ]),
            ),
          ),

          // ── Canaux de contact ──────────────────────────────────────────
          if (channels.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(label: 'NOUS CONTACTER'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.tpCard,
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: Column(children: [
                for (var i = 0; i < channels.length; i++) ...[
                  channels[i],
                  if (i != channels.length - 1)
                    Divider(height: 1, color: context.tpHair),
                ],
              ]),
            ),
          ],

          // ── FAQ ────────────────────────────────────────────────────────
          if (support.faq.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(label: 'QUESTIONS FRÉQUENTES'),
            const SizedBox(height: 8),
            for (final entry in grouped.entries) ...[
              if (entry.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8, left: 2),
                  child: Text(entry.key,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.tpInk)),
                ),
              Container(
                decoration: BoxDecoration(
                  color: context.tpCard,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Column(children: [
                  for (var i = 0; i < entry.value.length; i++) ...[
                    _FaqTile(item: entry.value[i]),
                    if (i != entry.value.length - 1)
                      Divider(height: 1, color: context.tpHair),
                  ],
                ]),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Map<String, List<FaqItem>> _groupByCategory(List<FaqItem> items) {
    final map = <String, List<FaqItem>>{};
    for (final it in items) {
      map.putIfAbsent(it.category, () => []).add(it);
    }
    return map;
  }
}

// ── Ligne de contact ──────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.tag)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.tpInk)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.tpInkSub)),
            ])),
            Icon(PhosphorIcons.arrowUpRight(), color: context.tpInkMute, size: 16),
          ]),
        ),
      );
}

// ── Tuile FAQ expansible ──────────────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  final FaqItem item;
  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(widget.item.question,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: context.tpInk)),
              ),
              const SizedBox(width: 10),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(PhosphorIcons.caretDown(),
                    color: context.tpInkMute, size: 16),
              ),
            ]),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState:
                  _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(widget.item.answer,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                        color: context.tpInkSub)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets communs ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: context.tpInkSub,
          letterSpacing: 0.4));
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
              Text('Impossible de charger l’aide.',
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
