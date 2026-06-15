import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme_ext.dart';

/// Rendu d'un markdown léger maison (sans dépendance externe) :
/// `## Titre`, `- puce`, paragraphes séparés par une ligne vide, et `**gras**`
/// en ligne. Couvre les besoins des documents légaux et réponses de FAQ.
class MarkdownLite extends StatelessWidget {
  final String text;

  /// Taille de base du corps de texte.
  final double fontSize;

  const MarkdownLite(this.text, {super.key, this.fontSize = 14.5});

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final base = TextStyle(
      fontSize: fontSize,
      height: 1.6,
      fontWeight: FontWeight.w600,
      color: context.tpInkSub,
    );

    final blocks = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        i++;
        continue;
      }

      // ── Sous-titre : ## Titre ───────────────────────────────────────────
      if (line.startsWith('## ')) {
        blocks.add(Padding(
          padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 24, bottom: 10),
          child: Text(
            line.substring(3).trim(),
            style: TextStyle(
              fontSize: fontSize + 2.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: context.tpInk,
            ),
          ),
        ));
        i++;
        continue;
      }

      // ── Liste à puces : groupe de lignes « - … » ────────────────────────
      if (line.startsWith('- ')) {
        final items = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('- ')) {
          items.add(lines[i].trim().substring(2).trim());
          i++;
        }
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8, right: 10, left: 2),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(children: _inline(context, it, base)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ));
        continue;
      }

      // ── Paragraphe : lignes consécutives jusqu'à une rupture ────────────
      final buf = <String>[line];
      i++;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].trim().startsWith('## ') &&
          !lines[i].trim().startsWith('- ')) {
        buf.add(lines[i].trim());
        i++;
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: RichText(
          text: TextSpan(children: _inline(context, buf.join(' '), base)),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  /// Découpe `**gras**` en TextSpans.
  List<TextSpan> _inline(BuildContext context, String text, TextStyle base) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: base.copyWith(fontWeight: FontWeight.w900, color: context.tpInk),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans.isEmpty ? [TextSpan(text: text, style: base)] : spans;
  }
}
