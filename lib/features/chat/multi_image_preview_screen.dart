import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/providers/chat_provider.dart';
import '../../theme/spacing.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_toast.dart';
import 'image_editor_screen.dart';

/// Revue des images sélectionnées avant envoi en chat : chaque image peut
/// être éditée (recadrage/dessin) ou retirée individuellement, puis toutes
/// sont envoyées comme messages successifs — équivalent du sélecteur
/// multi-photos de WhatsApp.
class MultiImagePreviewScreen extends ConsumerStatefulWidget {
  const MultiImagePreviewScreen({
    super.key,
    required this.roomId,
    required this.files,
    required this.attachEvent,
  });

  final String roomId;
  final List<File> files;
  final bool attachEvent;

  @override
  ConsumerState<MultiImagePreviewScreen> createState() => _MultiImagePreviewScreenState();
}

class _MultiImagePreviewScreenState extends ConsumerState<MultiImagePreviewScreen> {
  late List<File> _files = List.of(widget.files);
  bool _sending = false;

  Future<void> _editAt(int index) async {
    final edited = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => ImageEditorScreen(file: _files[index])),
    );
    if (edited == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final editedFile = await File(
      '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
    ).writeAsBytes(edited);
    setState(() => _files[index] = editedFile);
  }

  void _removeAt(int index) {
    setState(() => _files.removeAt(index));
    if (_files.isEmpty) Navigator.of(context).pop();
  }

  Future<void> _sendAll() async {
    setState(() => _sending = true);
    final notifier = ref.read(chatThreadProvider(widget.roomId).notifier);
    final total = _files.length;
    final failedFiles = <File>[];
    for (final file in List.of(_files)) {
      final ok = await notifier.sendImageMessage(XFile(file.path), attachEvent: widget.attachEvent);
      if (!ok) failedFiles.add(file);
    }
    if (!mounted) return;
    if (failedFiles.isNotEmpty) {
      final failed = failedFiles.length;
      setState(() { _sending = false; _files = failedFiles; });
      TpToast.error(context,
          '${total - failed}/$total photo${total > 1 ? 's' : ''} envoyée${total - failed > 1 ? 's' : ''} — $failed échec${failed > 1 ? 's' : ''}');
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.x),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${_files.length} photo${_files.length > 1 ? 's' : ''}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: _files.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.card),
                  child: Image.file(_files[i], fit: BoxFit.contain, width: double.infinity),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 84,
            // Empêche de retirer/éditer une photo pendant l'envoi : la liste
            // itérée dans _sendAll ne doit pas changer sous ses pieds.
            child: IgnorePointer(
              ignoring: _sending,
              child: Opacity(
                opacity: _sending ? 0.5 : 1,
                child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              scrollDirection: Axis.horizontal,
              itemCount: _files.length,
              separatorBuilder: (_, _) => const SizedBox(width: Sp.sm),
              itemBuilder: (_, i) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Image.file(_files[i], width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: 'Modifier la photo ${i + 1}',
                      child: GestureDetector(
                        onTap: () => _editAt(i),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                          child: const Icon(PhosphorIconsBold.pencilSimple, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Semantics(
                      button: true,
                      label: 'Retirer la photo ${i + 1}',
                      child: GestureDetector(
                        onTap: () => _removeAt(i),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                          child: const Icon(PhosphorIconsBold.x, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
            child: TpButton(
              label: _sending ? 'Envoi…' : 'Envoyer (${_files.length})',
              icon: PhosphorIconsBold.paperPlaneRight,
              fullWidth: true,
              state: _sending ? TpButtonState.loading : TpButtonState.idle,
              onPressed: _sending ? null : _sendAll,
            ),
          ),
        ],
      ),
    );
  }
}
