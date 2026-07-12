// Data models for the in-app chat between a driver and an accepted passenger.

class ChatMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime sentAt;
  final String? senderName;
  final String? senderPhotoUrl;

  ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.sentAt,
    this.senderName,
    this.senderPhotoUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      isRead: json['isRead'] as bool? ?? false,
      sentAt: DateTime.parse(json['sentAt'] as String).toLocal(),
      senderName: sender?['fullName'] as String?,
      senderPhotoUrl: sender?['profilePhotoUrl'] as String?,
    );
  }
}

class ChatOtherUser {
  final String id;
  final String? fullName;
  final String? profilePhotoUrl;

  ChatOtherUser({required this.id, this.fullName, this.profilePhotoUrl});

  factory ChatOtherUser.fromJson(Map<String, dynamic> json) => ChatOtherUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String?,
        profilePhotoUrl: json['profilePhotoUrl'] as String?,
      );
}

class ChatLastMessage {
  final String content;
  final DateTime sentAt;
  final String senderId;
  final bool isRead;

  ChatLastMessage({
    required this.content,
    required this.sentAt,
    required this.senderId,
    required this.isRead,
  });

  factory ChatLastMessage.fromJson(Map<String, dynamic> json) =>
      ChatLastMessage(
        content: json['content'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String).toLocal(),
        senderId: json['senderId'] as String,
        isRead: json['isRead'] as bool? ?? false,
      );
}

class Conversation {
  final String bookingId;
  final String status;

  /// Whether the conversation is still open for sending (false = read-only).
  final bool canSend;
  final ChatOtherUser otherUser;
  final String role; // 'passenger' | 'driver' — my role in this booking
  final String originName;
  final String destName;
  final DateTime? departureAt;
  final ChatLastMessage? lastMessage;
  final int unreadCount;

  Conversation({
    required this.bookingId,
    required this.status,
    required this.canSend,
    required this.otherUser,
    required this.role,
    required this.originName,
    required this.destName,
    required this.departureAt,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final ride = json['ride'] as Map<String, dynamic>? ?? const {};
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return Conversation(
      bookingId: json['bookingId'] as String,
      status: json['status'] as String,
      canSend: json['canSend'] as bool? ?? false,
      otherUser:
          ChatOtherUser.fromJson(json['otherUser'] as Map<String, dynamic>),
      role: json['role'] as String? ?? 'passenger',
      originName: ride['originName'] as String? ?? '',
      destName: ride['destName'] as String? ?? '',
      departureAt: ride['departureAt'] != null
          ? DateTime.parse(ride['departureAt'] as String).toLocal()
          : null,
      lastMessage: last != null ? ChatLastMessage.fromJson(last) : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
