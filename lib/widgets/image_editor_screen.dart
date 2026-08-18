import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Édition d'une image avant envoi (chat) ou avant upload (avatar) :
/// recadrage/rotation + dessin libre (traits, flèches, formes) pour entourer
/// un élément — équivalent de l'éditeur pré-envoi de WhatsApp. Retourne les
/// bytes de l'image éditée via `Navigator.pop`, ou `null` si l'utilisateur
/// annule.
///
/// [forceSquareCrop] verrouille le recadrage sur un ratio 1:1 et masque le
/// sélecteur de ratio — utilisé pour les avatars (profil, groupe, communauté).
class ImageEditorScreen extends StatelessWidget {
  const ImageEditorScreen({super.key, required this.file, this.forceSquareCrop = false});

  final File file;
  final bool forceSquareCrop;

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      file,
      configs: forceSquareCrop
          ? const ProImageEditorConfigs(
              cropRotateEditor: CropRotateEditorConfigs(
                initAspectRatio: 1,
                aspectRatios: [AspectRatioItem(text: '1:1', value: 1)],
                tools: [CropRotateTool.rotate, CropRotateTool.flip, CropRotateTool.reset],
              ),
            )
          : const ProImageEditorConfigs(),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          Navigator.pop(context, bytes);
        },
      ),
    );
  }
}

/// Ouvre l'éditeur en mode recadrage carré imposé (avatar profil / groupe /
/// communauté) et retourne un fichier temporaire contenant le résultat, ou
/// `null` si l'utilisateur annule.
Future<File?> pickAndCropSquareAvatar(BuildContext context, File original) async {
  final edited = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => ImageEditorScreen(file: original, forceSquareCrop: true),
    ),
  );
  if (edited == null) return null;
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg')
      .writeAsBytes(edited);
}

/// Pré-charge un avatar tout juste uploadé avant de mettre à jour l'UI avec
/// sa nouvelle URL : juste après un upload, le fichier peut mettre un court
/// instant à être disponible en lecture côté CDN — sans ce pré-chargement,
/// le premier essai d'affichage peut échouer et rester bloqué sur le
/// fallback tant que le widget n'est pas reconstruit depuis zéro (redémarrage
/// de l'app). Quelques tentatives avec un court délai absorbent ce cas.
Future<void> precacheFreshAvatar(BuildContext context, String url) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    if (!context.mounted) return;
    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
      return;
    } catch (_) {
      if (attempt == 2) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
