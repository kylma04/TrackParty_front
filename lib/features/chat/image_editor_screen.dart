import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Édition d'une image avant envoi en chat : recadrage/rotation + dessin
/// libre (traits, flèches, formes) pour entourer un élément — équivalent de
/// l'éditeur pré-envoi de WhatsApp. Retourne les bytes de l'image éditée via
/// `Navigator.pop`, ou `null` si l'utilisateur annule.
class ImageEditorScreen extends StatelessWidget {
  const ImageEditorScreen({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      file,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          Navigator.pop(context, bytes);
        },
      ),
    );
  }
}
