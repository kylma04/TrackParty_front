import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Catégories de ticket (doivent correspondre au backend).
const supportCategories = <String, String>{
  'account': 'Compte',
  'event': 'Événement',
  'payment': 'Paiement',
  'report': 'Signalement',
  'other': 'Autre',
};

String supportCategoryLabel(String key) => supportCategories[key] ?? 'Autre';

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// Date courte et relative : « 14:32 » aujourd'hui, sinon « 12 juin ».
String supportDateShort(DateTime? d) {
  if (d == null) return '';
  final local = d.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${local.day} ${_months[local.month - 1]}';
}

/// (label, couleur de texte, couleur de fond) pour un statut de ticket.
(String, Color, Color) supportStatusStyle(String status) {
  switch (status) {
    case 'open':
      return ('Ouvert', const Color(0xFF92400E), const Color(0xFFFEF3C7));
    case 'in_progress':
      return ('En cours', const Color(0xFF3730A3), const Color(0xFFE0E7FF));
    case 'resolved':
      return ('Résolu', const Color(0xFF065F46), const Color(0xFFD1FAE5));
    case 'closed':
      return ('Fermé', const Color(0xFF374151), const Color(0xFFE5E7EB));
    default:
      return (status, kInkSubDark, kHairDark);
  }
}

class SupportMessage {
  final String id;
  final String body;
  final bool isFromSupport;
  final DateTime? createdAt;

  const SupportMessage({
    required this.id,
    required this.body,
    required this.isFromSupport,
    this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['id'].toString(),
        body: j['body'] as String? ?? '',
        isFromSupport: j['is_from_support'] as bool? ?? false,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );
}

class SupportTicket {
  final String id;
  final String subject;
  final String category;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String lastPreview;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    this.createdAt,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastPreview = '',
    this.messages = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'].toString(),
        subject: j['subject'] as String? ?? '',
        category: j['category'] as String? ?? 'other',
        status: j['status'] as String? ?? 'open',
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.tryParse(j['last_message_at'] as String)
            : null,
        unreadCount: j['unread_count'] as int? ?? 0,
        lastPreview: j['last_preview'] as String? ?? '',
        messages: (j['messages'] as List<dynamic>? ?? [])
            .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
