import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:trackparty/theme/app_theme.dart';
import 'package:trackparty/theme/colors.dart';
import 'package:trackparty/theme/gradients.dart';
import 'package:trackparty/widgets/tp_badge.dart';
import 'package:trackparty/widgets/tp_button.dart';
import 'package:trackparty/widgets/tp_chip.dart';
import 'package:trackparty/widgets/tp_icons.dart';
import 'package:trackparty/widgets/tp_logo.dart';
import 'package:trackparty/widgets/tp_pro_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;

    const fakeFontAssets = <String>[
      'assets/google_fonts/NotoSansDisplay-Regular.ttf',
      'assets/google_fonts/NotoSansDisplay-Medium.ttf',
      'assets/google_fonts/NotoSansDisplay-SemiBold.ttf',
      'assets/google_fonts/NotoSansDisplay-Bold.ttf',
      'assets/google_fonts/NotoSansDisplay-ExtraBold.ttf',
      'assets/google_fonts/NotoSansDisplay-Black.ttf',
      'assets/google_fonts/Lato-Regular.ttf',
      'assets/google_fonts/Lato-Bold.ttf',
      'assets/google_fonts/Lato-Black.ttf',
    ];
    final manifestBytes = const StandardMessageCodec().encodeMessage(
      <Object?, Object?>{
        for (final asset in fakeFontAssets)
          asset: <Object?>[
            <Object?, Object?>{'asset': asset},
          ],
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(message.buffer.asUint8List());
      if (key == 'AssetManifest.bin') {
        return manifestBytes;
      }
      if (key.endsWith('.ttf')) {
        return ByteData(16);
      }
      return null;
    });
  });

  group('TrackParty Brand Palette & Theme', () {
    test('uses Orange Corail accent and Nuit Ardoise / Lin Chaud surfaces',
        () async {
      expect(kPrimary, const Color(0xFFFF4B26));
      expect(kBgLight, const Color(0xFFF5F4EF));
      expect(kBgDark, const Color(0xFF0B1118));
      expect(kCardDark, const Color(0xFF131C27));

      final light = AppTheme.light;
      expect(light.colorScheme.primary, kPrimary);
      expect(light.scaffoldBackgroundColor, kBgLight);

      final dark = AppTheme.dark;
      expect(dark.colorScheme.primary, kPrimary);
      expect(dark.scaffoldBackgroundColor, kBgDark);
      expect(dark.cardColor, kCardDark);

      await GoogleFonts.pendingFonts();
    });

    test('brand gradients stay flat single-hue coral/amber (no neon rainbow)', () {
      expect(trackpartyGradient.colors, everyElement(kPrimary));
      expect(goldGradient.colors, everyElement(kTertiary));
    });
  });

  group('TpLogo & TpWordmark (Ticket Tombola)', () {
    testWidgets('renders Ticket Tombola logo across sizes without exceptions',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TpLogo(size: 24),
                  TpLogo(size: 88),
                  TpWordmark(iconSize: 36, fontSize: 20),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TpLogo), findsNWidgets(3));
      expect(find.byType(TpWordmark), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TpIcons & Category Registry', () {
    test('normalizes category aliases cleanly', () {
      expect(normalizeTpCategory('Soirée'), 'soiree');
      expect(normalizeTpCategory('MUSIC'), 'musique');
      expect(normalizeTpCategory('culture'), 'art');
      expect(normalizeTpCategory('food'), 'cuisine');
      expect(normalizeTpCategory('unknown_slug'), 'autre');
    });

    test('treats legacy sparkle emoji fallback as non-custom', () {
      expect(hasCustomUserEmoji(null), isFalse);
      expect(hasCustomUserEmoji(''), isFalse);
      expect(hasCustomUserEmoji('✨'), isFalse);
      expect(hasCustomUserEmoji('🎷'), isTrue);
    });

    testWidgets(
        'renders vector icons for standard categories and keeps real user emojis on autre',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Column(
              children: [
                TpCategoryIcon(category: 'soiree'),
                TpCategoryIcon(category: 'autre', customEmoji: '✨'),
                TpCategoryIcon(category: 'autre', customEmoji: '🎷'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Icon), findsNWidgets(2));
      expect(find.text('🎷'), findsOneWidget);
      expect(find.text('✨'), findsNothing);
    });

    test('drawTpCategoryGlyph paints all categories on ui.Canvas cleanly', () {
      for (final cat in [
        'musique',
        'soiree',
        'cuisine',
        'sport',
        'art',
        'plage',
        'autre',
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        drawTpCategoryGlyph(
          canvas,
          cat,
          const Offset(24, 24),
          22,
          Colors.white,
        );
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
        picture.dispose();
      }
    });
  });

  group('Core Rebranded Shared Widgets', () {
    testWidgets('TpBadge and TpProBadge render cleanly with vector icons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                TpBadge.category('musique'),
                TpBadge.contrib('monetaire'),
                TpBadge.contrib('gratuit'),
                TpBadge.visibility(true),
                TpBadge.promoter(),
                const TpProBadge(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Icon), findsNWidgets(6));
      expect(find.text('MUSIQUE'), findsOneWidget);
      expect(find.text('PAYANT'), findsOneWidget);
      expect(find.text('GRATUIT'), findsOneWidget);
      expect(find.text('PRIVÉ'), findsOneWidget);
      expect(find.text('PROMOTEUR'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('TpFilterChip supports vector icon and active state',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TpFilterChip(
              label: 'Musique',
              icon: PhosphorIcons.musicNotes(PhosphorIconsStyle.fill),
              active: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Musique'));
      expect(tapped, isTrue);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('TpButton handles primary action across states', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                TpButton(
                  label: 'Continuer',
                  onPressed: () => pressed++,
                ),
                TpButton(
                  label: 'Désactivé',
                  state: TpButtonState.disabled,
                  onPressed: () => pressed++,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continuer'));
      await tester.tap(find.text('Désactivé'));
      expect(pressed, 1);
    });
  });
}
