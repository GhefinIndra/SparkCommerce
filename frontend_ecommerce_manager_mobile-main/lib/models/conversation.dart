// lib/models/conversation.dart
class Conversation {
  final String id;
  final int unreadCount;
  final bool canSendMessage;
  final String createTime;
  final int participantCount;
  final Buyer? buyer;
  final Message? latestMessage;

  Conversation({
    required this.id,
    required this.unreadCount,
    required this.canSendMessage,
    required this.createTime,
    required this.participantCount,
    this.buyer,
    this.latestMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      unreadCount: json['unreadCount'] ?? 0,
      canSendMessage: json['canSendMessage'] ?? false,
      createTime: json['createTime'] ?? '',
      participantCount: json['participantCount'] ?? 0,
      buyer: json['buyer'] != null ? Buyer.fromJson(json['buyer']) : null,
      latestMessage: json['latestMessage'] != null
          ? Message.fromJson(json['latestMessage'])
          : null,
    );
  }
}

class Buyer {
  final String imUserId;
  final String userId;
  final String nickname;
  final String avatar;
  final String role;
  final String buyerPlatform;

  Buyer({
    required this.imUserId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.role,
    required this.buyerPlatform,
  });

  factory Buyer.fromJson(Map<String, dynamic> json) {
    return Buyer(
      imUserId: json['im_user_id'] ?? '',
      userId: json['user_id'] ?? '',
      nickname: json['nickname'] ?? 'Unknown',
      avatar: json['avatar'] ?? '',
      role: json['role'] ?? 'BUYER',
      buyerPlatform: json['buyer_platform'] ?? 'TIKTOK_SHOP',
    );
  }
}

class Message {
  final String id;
  final String type;
  final String content;
  final String createTime;
  final bool isVisible;
  final String index;
  final MessageSender? sender;

  Message({
    required this.id,
    required this.type,
    required this.content,
    required this.createTime,
    required this.isVisible,
    required this.index,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      type: json['type'] ?? 'TEXT',
      content: json['content'] ?? '',
      createTime: json['createTime'] ?? '',
      isVisible: json['isVisible'] ?? true,
      index: json['index'] ?? '',
      sender: json['sender'] != null
          ? MessageSender.fromJson(json['sender'])
          : null,
    );
  }
}

class MessageSender {
  final String imUserId;
  final String role;
  final String nickname;
  final String avatar;

  MessageSender({
    required this.imUserId,
    required this.role,
    required this.nickname,
    required this.avatar,
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      imUserId: json['im_user_id'] ?? '',
      role: json['role'] ?? '',
      nickname: json['nickname'] ?? 'Unknown',
      avatar: json['avatar'] ?? '',
    );
  }
}
