/// Une question fréquente (FAQ).
class FaqItem {
  final String id;
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
        id: json['id'].toString(),
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        category: json['category'] as String? ?? '',
      );
}

/// Contenu de l'écran « Aide & support » : coordonnées + FAQ.
class SupportContent {
  final String intro;
  final String email;
  final String phone;
  final String whatsapp;
  final String responseTime;
  final List<FaqItem> faq;

  const SupportContent({
    required this.intro,
    required this.email,
    required this.phone,
    required this.whatsapp,
    required this.responseTime,
    required this.faq,
  });

  factory SupportContent.fromJson(Map<String, dynamic> json) => SupportContent(
        intro: json['intro'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        responseTime: json['response_time'] as String? ?? '',
        faq: (json['faq'] as List<dynamic>? ?? [])
            .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Un document légal (politique de confidentialité, CGU…).
class LegalDocument {
  final String slug;
  final String title;
  final String body;
  final DateTime? updatedAt;

  const LegalDocument({
    required this.slug,
    required this.title,
    required this.body,
    this.updatedAt,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) => LegalDocument(
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );
}
