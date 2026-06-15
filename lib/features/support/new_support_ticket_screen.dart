import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/support_model.dart';
import '../../core/services/support_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_ext.dart';
import '../../widgets/tp_button.dart';
import '../../widgets/tp_field.dart';

class NewSupportTicketScreen extends ConsumerStatefulWidget {
  const NewSupportTicketScreen({super.key});

  @override
  ConsumerState<NewSupportTicketScreen> createState() =>
      _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState
    extends ConsumerState<NewSupportTicketScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'account';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty) {
      setState(() => _error = 'Donne un sujet à ta demande.');
      return;
    }
    if (message.length < 5) {
      setState(() => _error = 'Décris ton problème en quelques mots.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await ref.read(supportServiceProvider).createTicket(
            subject: subject,
            category: _category,
            message: message,
          );
      ref.invalidate(supportTicketsProvider);
      if (!mounted) return;
      // Remplace l'écran de création par le fil → retour direct à la liste.
      context.pushReplacement('/support/${ticket.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tpBg,
      appBar: AppBar(
        backgroundColor: context.tpCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: context.tpInk, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Nouvelle demande',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: context.tpInk)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.md, 20, Sp.md, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catégorie',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: context.tpInkSub)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supportCategories.entries.map((e) {
                final selected = _category == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _category = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? kPrimary
                          : context.tpCard,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                        color: selected ? kPrimary : context.tpHair,
                        width: 1.4,
                      ),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : context.tpInk)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            TpField(
              label: 'Sujet',
              prefixIcon: PhosphorIcons.textT(),
              controller: _subjectCtrl,
              maxLength: 160,
            ),
            const SizedBox(height: 14),
            TpField(
              label: 'Décris ton problème',
              controller: _messageCtrl,
              maxLines: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: kError)),
            ],
            const SizedBox(height: 22),
            TpButton(
              label: 'Envoyer la demande',
              fullWidth: true,
              state: _loading ? TpButtonState.loading : TpButtonState.idle,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
