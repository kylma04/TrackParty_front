/// Un utilisateur bloqué par l'utilisateur courant.
class BlockedUser {
  final String id; // id du blocage
  final String blockedId; // id de l'utilisateur bloqué
  final String displayName;
  final String? avatarUrl;
  final DateTime? blockedAt;

  const BlockedUser({
    required this.id,
    required this.blockedId,
    required this.displayName,
    this.avatarUrl,
    this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: json['id'].toString(),
        blockedId: json['blocked_id'].toString(),
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        blockedAt: json['blocked_at'] != null
            ? DateTime.tryParse(json['blocked_at'] as String)
            : null,
      );
}
