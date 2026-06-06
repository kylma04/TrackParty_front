class ChatUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isPromoter;

  const ChatUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isPromoter = false,
  });

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        avatarUrl: j['avatar_url'] as String?,
        isPromoter: j['is_promoter'] as bool? ?? false,
      );
}

class ChatLastMessage {
  final String id;
  final String senderName;
  final String content;
  final DateTime createdAt;

  const ChatLastMessage({
    required this.id,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory ChatLastMessage.fromJson(Map<String, dynamic> j) => ChatLastMessage(
        id: j['id'] as String,
        senderName: j['sender_name'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ChatMemberPreview {
  final String id;
  final String displayName;
  final String? avatarUrl;

  const ChatMemberPreview({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  factory ChatMemberPreview.fromJson(Map<String, dynamic> j) => ChatMemberPreview(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        avatarUrl: j['avatar_url'] as String?,
      );
}

class ChatRoomModel {
  final String id;
  final String roomType;  // 'private', 'event', 'community'
  final String displayName;
  final String groupMode;  // 'open', 'broadcast'
  final String myRole;     // 'admin', 'member'
  final String? eventId;
  final String? eventTitle;
  final ChatLastMessage? lastMessage;
  final int unreadCount;
  final int membersCount;
  final List<ChatMemberPreview> membersPreview;
  final DateTime createdAt;
  final String? promoterId;
  final String? promoterName;
  final String? promoterAvatarUrl;
  final String? roomAvatarUrl;

  const ChatRoomModel({
    required this.id,
    required this.roomType,
    required this.displayName,
    this.groupMode = 'open',
    this.myRole = 'member',
    this.eventId,
    this.eventTitle,
    this.lastMessage,
    required this.unreadCount,
    this.membersCount = 0,
    required this.membersPreview,
    required this.createdAt,
    this.promoterId,
    this.promoterName,
    this.promoterAvatarUrl,
    this.roomAvatarUrl,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> j) => ChatRoomModel(
        id: j['id'] as String,
        roomType: j['room_type'] as String,
        displayName: j['display_name'] as String? ?? 'Conversation',
        groupMode: j['group_mode'] as String? ?? 'open',
        myRole: j['my_role'] as String? ?? 'member',
        eventId: j['event_id'] as String?,
        eventTitle: j['event_title'] as String?,
        lastMessage: j['last_message'] != null
            ? ChatLastMessage.fromJson(j['last_message'] as Map<String, dynamic>)
            : null,
        unreadCount: j['unread_count'] as int? ?? 0,
        membersCount: j['members_count'] as int? ?? 0,
        membersPreview: (j['members_preview'] as List<dynamic>? ?? [])
            .map((e) => ChatMemberPreview.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
        promoterId: j['promoter_id'] as String?,
        promoterName: j['promoter_name'] as String?,
        promoterAvatarUrl: j['promoter_avatar_url'] as String?,
        roomAvatarUrl: j['room_avatar_url'] as String?,
      );

  bool get isPrivate    => roomType == 'private';
  bool get isEvent      => roomType == 'event';
  bool get isCommunity  => roomType == 'community';
  bool get isBroadcast  => groupMode == 'broadcast';
  bool get isAdmin      => myRole == 'admin';
}

class MessageReaction {
  final String emoji;
  final int count;

  const MessageReaction({required this.emoji, required this.count});

  factory MessageReaction.fromJson(Map<String, dynamic> j) =>
      MessageReaction(emoji: j['emoji'] as String, count: j['count'] as int);
}

class EventInviteData {
  final String id;
  final String title;
  final String category;
  final String? categoryEmoji;
  final DateTime startAt;
  final String addressLabel;
  final String quartier;
  final String contributionType;
  final List<Map<String, String>> contributionItems;
  final String? coverImageUrl;

  const EventInviteData({
    required this.id,
    required this.title,
    required this.category,
    this.categoryEmoji,
    required this.startAt,
    required this.addressLabel,
    required this.quartier,
    required this.contributionType,
    required this.contributionItems,
    this.coverImageUrl,
  });

  static String categoryLabel(String cat) {
    const map = {
      'soiree': 'SOIRÉE',
      'musique': 'MUSIQUE',
      'cuisine': 'CUISINE',
      'sport': 'SPORT',
      'art': 'ART',
      'plage': 'PLAGE',
      'autre': 'ÉVÉNEMENT',
    };
    return map[cat] ?? 'ÉVÉNEMENT';
  }

  factory EventInviteData.fromJson(Map<String, dynamic> j) => EventInviteData(
        id: j['id'] as String,
        title: j['title'] as String,
        category: j['category'] as String? ?? 'autre',
        categoryEmoji: j['category_emoji'] as String?,
        startAt: DateTime.parse(j['start_at'] as String),
        addressLabel: j['address_label'] as String? ?? '',
        quartier: j['quartier'] as String? ?? '',
        contributionType: j['contribution_type'] as String? ?? 'gratuit',
        coverImageUrl: j['cover_image_url'] as String?,
        contributionItems: (j['contribution_items'] as List<dynamic>? ?? [])
            .map((e) => {
                  'name': (e as Map<String, dynamic>)['name'] as String,
                  'emoji': e['emoji'] as String? ?? '',
                })
            .toList(),
      );
}

class ChatMessage {
  final String id;
  final ChatUser sender;
  final String content;
  final String messageType; // 'text', 'image', 'voice', 'event_invite', 'announcement'
  final String? imageUrl;
  final String? voiceUrl;
  final int? voiceDuration;
  final String? eventInviteId;
  final EventInviteData? eventInviteData;
  final String? invitationId;
  final String? invitationStatus; // 'pending', 'accepted', 'refused'
  final List<MessageReaction> reactions;
  final bool isPinned;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.messageType,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration,
    this.eventInviteId,
    this.eventInviteData,
    this.invitationId,
    this.invitationStatus,
    this.reactions = const [],
    required this.isPinned,
    required this.createdAt,
  });

  ChatMessage copyWith({String? invitationStatus, List<MessageReaction>? reactions}) => ChatMessage(
        id: id,
        sender: sender,
        content: content,
        messageType: messageType,
        imageUrl: imageUrl,
        voiceUrl: voiceUrl,
        voiceDuration: voiceDuration,
        eventInviteId: eventInviteId,
        eventInviteData: eventInviteData,
        invitationId: invitationId,
        invitationStatus: invitationStatus ?? this.invitationStatus,
        reactions: reactions ?? this.reactions,
        isPinned: isPinned,
        createdAt: createdAt,
      );

  static List<MessageReaction> _parseReactions(dynamic raw) {
    if (raw == null) return const [];
    return (raw as List<dynamic>)
        .map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        sender: ChatUser.fromJson(j['sender'] as Map<String, dynamic>),
        content: j['content'] as String? ?? '',
        messageType: j['message_type'] as String? ?? 'text',
        imageUrl: j['image_url'] as String?,
        voiceUrl: j['voice_url'] as String?,
        voiceDuration: j['voice_duration'] as int?,
        eventInviteId: j['event_invite_id'] as String?,
        eventInviteData: j['event_invite_data'] != null
            ? EventInviteData.fromJson(j['event_invite_data'] as Map<String, dynamic>)
            : null,
        invitationId: j['invitation_id'] as String?,
        invitationStatus: j['invitation_status'] as String?,
        reactions: _parseReactions(j['reactions']),
        isPinned: j['is_pinned'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  factory ChatMessage.fromWsEvent(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        sender: ChatUser(
          id: j['sender_id'] as String,
          displayName: j['sender_name'] as String,
          avatarUrl: j['sender_avatar_url'] as String?,
        ),
        content: j['content'] as String? ?? '',
        messageType: j['message_type'] as String? ?? 'text',
        imageUrl: j['image_url'] as String?,
        voiceUrl: j['voice_url'] as String?,
        voiceDuration: j['voice_duration'] as int?,
        eventInviteId: j['event_invite_id'] as String?,
        eventInviteData: j['event_invite_data'] != null
            ? EventInviteData.fromJson(j['event_invite_data'] as Map<String, dynamic>)
            : null,
        invitationId: j['invitation_id'] as String?,
        invitationStatus: j['invitation_status'] as String?,
        reactions: _parseReactions(j['reactions']),
        isPinned: false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  bool get isText         => messageType == 'text';
  bool get isImage        => messageType == 'image';
  bool get isVoice        => messageType == 'voice';
  bool get isEventInvite  => messageType == 'event_invite';
  bool get isAnnouncement => messageType == 'announcement';
}

// ── Invitation ────────────────────────────────────────────────────────────────

class InvitationContribItem {
  final String id;
  final String name;
  final String emoji;
  final int quantityTotal;
  final int quantityTaken;

  const InvitationContribItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.quantityTotal,
    required this.quantityTaken,
  });

  int get quantityRemaining => quantityTotal - quantityTaken;
  bool get isAvailable => quantityRemaining > 0;

  factory InvitationContribItem.fromJson(Map<String, dynamic> j) =>
      InvitationContribItem(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '',
        quantityTotal: j['quantity_total'] as int,
        quantityTaken: j['quantity_taken'] as int,
      );
}

class InvitationEventInfo {
  final String id;
  final String title;
  final String? coverImageUrl;
  final DateTime startAt;
  final String contributionType;
  final List<InvitationContribItem> contributionItems;

  const InvitationEventInfo({
    required this.id,
    required this.title,
    this.coverImageUrl,
    required this.startAt,
    this.contributionType = 'gratuit',
    this.contributionItems = const [],
  });

  bool get needsContribution =>
      contributionType == 'nature' && contributionItems.isNotEmpty;

  factory InvitationEventInfo.fromJson(Map<String, dynamic> j) =>
      InvitationEventInfo(
        id: j['id'] as String,
        title: j['title'] as String,
        coverImageUrl: j['cover_image_url'] as String?,
        startAt: DateTime.parse(j['start_at'] as String),
        contributionType: j['contribution_type'] as String? ?? 'gratuit',
        contributionItems: (j['contribution_items'] as List<dynamic>?)
                ?.map((e) => InvitationContribItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class InvitationModel {
  final String id;
  final ChatUser sender;
  final ChatUser receiver;
  final String invitationType; // 'event', 'dm'
  final InvitationEventInfo? event;
  final String status; // 'pending', 'accepted', 'refused'
  final DateTime createdAt;
  final DateTime? respondedAt;

  const InvitationModel({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.invitationType,
    this.event,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> j) => InvitationModel(
        id: j['id'] as String,
        sender: ChatUser.fromJson(j['sender'] as Map<String, dynamic>),
        receiver: ChatUser.fromJson(j['receiver'] as Map<String, dynamic>),
        invitationType: j['invitation_type'] as String? ?? 'event',
        event: j['event'] != null
            ? InvitationEventInfo.fromJson(j['event'] as Map<String, dynamic>)
            : null,
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(j['created_at'] as String),
        respondedAt: j['responded_at'] != null
            ? DateTime.parse(j['responded_at'] as String)
            : null,
      );

  bool get isPending  => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRefused  => status == 'refused';
}

// ── Membre d'une salle ───────────────────────────────────────────────────────

class RoomMemberModel {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isPromoter;
  final String role; // 'admin', 'member'
  final bool hasDm;
  final bool hasPendingInvitation;

  const RoomMemberModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.isPromoter,
    required this.role,
    required this.hasDm,
    this.hasPendingInvitation = false,
  });

  bool get isAdmin => role == 'admin';

  factory RoomMemberModel.fromJson(Map<String, dynamic> j) => RoomMemberModel(
        id:                     j['id'] as String,
        displayName:            j['display_name'] as String,
        avatarUrl:              j['avatar_url'] as String?,
        isPromoter:             j['is_promoter'] as bool? ?? false,
        role:                   j['role'] as String? ?? 'member',
        hasDm:                  j['has_dm'] as bool? ?? false,
        hasPendingInvitation:   j['has_pending_invitation'] as bool? ?? false,
      );
}

// ── Résultat de recherche d'utilisateurs ─────────────────────────────────────

class UserSearchResult {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isPromoter;

  const UserSearchResult({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isPromoter = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> j) => UserSearchResult(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        avatarUrl: j['avatar_url'] as String?,
        isPromoter: j['is_promoter'] as bool? ?? false,
      );
}
