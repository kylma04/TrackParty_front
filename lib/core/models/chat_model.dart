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
  final String roomType; // 'private', 'event', 'community'
  final String displayName;
  final String? eventId;
  final String? eventTitle;
  final ChatLastMessage? lastMessage;
  final int unreadCount;
  final List<ChatMemberPreview> membersPreview;
  final DateTime createdAt;

  const ChatRoomModel({
    required this.id,
    required this.roomType,
    required this.displayName,
    this.eventId,
    this.eventTitle,
    this.lastMessage,
    required this.unreadCount,
    required this.membersPreview,
    required this.createdAt,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> j) => ChatRoomModel(
        id: j['id'] as String,
        roomType: j['room_type'] as String,
        displayName: j['display_name'] as String? ?? 'Conversation',
        eventId: j['event_id'] as String?,
        eventTitle: j['event_title'] as String?,
        lastMessage: j['last_message'] != null
            ? ChatLastMessage.fromJson(j['last_message'] as Map<String, dynamic>)
            : null,
        unreadCount: j['unread_count'] as int? ?? 0,
        membersPreview: (j['members_preview'] as List<dynamic>? ?? [])
            .map((e) => ChatMemberPreview.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  bool get isPrivate   => roomType == 'private';
  bool get isEvent     => roomType == 'event';
  bool get isCommunity => roomType == 'community';
}

class ChatMessage {
  final String id;
  final ChatUser sender;
  final String content;
  final String messageType; // 'text', 'image', 'event_invite'
  final String? imageUrl;
  final String? eventInviteId;
  final bool isPinned;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.messageType,
    this.imageUrl,
    this.eventInviteId,
    required this.isPinned,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        sender: ChatUser.fromJson(j['sender'] as Map<String, dynamic>),
        content: j['content'] as String? ?? '',
        messageType: j['message_type'] as String? ?? 'text',
        imageUrl: j['image_url'] as String?,
        eventInviteId: j['event_invite_id'] as String?,
        isPinned: j['is_pinned'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  // Constructeur depuis un event WebSocket
  factory ChatMessage.fromWsEvent(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        sender: ChatUser(
          id: j['sender_id'] as String,
          displayName: j['sender_name'] as String,
        ),
        content: j['content'] as String? ?? '',
        messageType: j['message_type'] as String? ?? 'text',
        eventInviteId: j['event_invite_id'] as String?,
        isPinned: false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
