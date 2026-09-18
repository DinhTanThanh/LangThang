enum MessageAttachmentType {
  place(1),
  food(2),
  trip(3),
  image(4),
  file(5),
  audio(6);

  final int value;
  const MessageAttachmentType(this.value);

  static MessageAttachmentType fromValue(dynamic val) {
    if (val is int) {
      return MessageAttachmentType.values.firstWhere(
        (e) => e.value == val,
        orElse: () => MessageAttachmentType.image,
      );
    }
    if (val is String) {
      final v = int.tryParse(val);
      if (v != null) return fromValue(v);
      switch (val.toLowerCase()) {
        case 'place':
          return MessageAttachmentType.place;
        case 'food':
          return MessageAttachmentType.food;
        case 'trip':
          return MessageAttachmentType.trip;
        case 'image':
          return MessageAttachmentType.image;
        case 'file':
          return MessageAttachmentType.file;
        case 'audio':
          return MessageAttachmentType.audio;
      }
    }
    return MessageAttachmentType.image;
  }
}

class MessageAttachment {
  final int id;
  final MessageAttachmentType attachmentType;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final int? durationSeconds;
  final int displayOrder;

  // Place preview
  final int? placeId;
  final String? placeName;
  final String? placeCoverUrl;
  final String? placeProvince;
  final double? placeRating;
  final String? placePrice;

  // Food preview
  final String? foodId;
  final String? foodName;
  final String? foodCoverUrl;
  final String? foodProvince;
  final String? foodPrice;
  final double? foodRating;

  // Trip preview
  final int? tripId;
  final String? tripTitle;
  final String? tripCoverUrl;
  final String? tripDuration;
  final String? tripDestination;

  const MessageAttachment({
    required this.id,
    required this.attachmentType,
    this.mediaUrl,
    this.fileName,
    this.fileSizeBytes,
    this.durationSeconds,
    this.displayOrder = 0,
    this.placeId,
    this.placeName,
    this.placeCoverUrl,
    this.placeProvince,
    this.placeRating,
    this.placePrice,
    this.foodId,
    this.foodName,
    this.foodCoverUrl,
    this.foodProvince,
    this.foodPrice,
    this.foodRating,
    this.tripId,
    this.tripTitle,
    this.tripCoverUrl,
    this.tripDuration,
    this.tripDestination,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      attachmentType: MessageAttachmentType.fromValue(json['attachmentType'] ?? json['type']),
      mediaUrl: json['mediaUrl']?.toString() ?? json['url']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      placeId: (json['placeId'] as num?)?.toInt(),
      placeName: json['placeName']?.toString(),
      placeCoverUrl: json['placeCoverUrl']?.toString() ?? json['placeImage']?.toString(),
      placeProvince: json['placeProvince']?.toString() ?? json['province']?.toString(),
      placeRating: (json['placeRating'] as num?)?.toDouble() ?? (json['rating'] as num?)?.toDouble(),
      placePrice: json['placePrice']?.toString() ?? json['price']?.toString(),
      foodId: json['foodId']?.toString(),
      foodName: json['foodName']?.toString(),
      foodCoverUrl: json['foodCoverUrl']?.toString(),
      foodProvince: json['foodProvince']?.toString(),
      foodPrice: json['foodPrice']?.toString(),
      foodRating: (json['foodRating'] as num?)?.toDouble(),
      tripId: (json['tripId'] as num?)?.toInt(),
      tripTitle: json['tripTitle']?.toString(),
      tripCoverUrl: json['tripCoverUrl']?.toString(),
      tripDuration: json['tripDuration']?.toString(),
      tripDestination: json['tripDestination']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'attachmentType': attachmentType.value,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'durationSeconds': durationSeconds,
      'displayOrder': displayOrder,
      'placeId': placeId,
      'placeName': placeName,
      'placeCoverUrl': placeCoverUrl,
      'placeProvince': placeProvince,
      'placeRating': placeRating,
      'placePrice': placePrice,
      'foodId': foodId,
      'foodName': foodName,
      'foodCoverUrl': foodCoverUrl,
      'foodProvince': foodProvince,
      'foodPrice': foodPrice,
      'foodRating': foodRating,
      'tripId': tripId,
      'tripTitle': tripTitle,
      'tripCoverUrl': tripCoverUrl,
      'tripDuration': tripDuration,
      'tripDestination': tripDestination,
    };
  }
}

class MessageReaction {
  final int messageId;
  final int userId;
  final String userName;
  final String emoji;
  final DateTime createdAt;

  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.userName,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      messageId: (json['messageId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      userName: json['userName']?.toString() ?? 'Người dùng',
      emoji: json['emoji']?.toString() ?? '❤️',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'userId': userId,
      'userName': userName,
      'emoji': emoji,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ChatMessage {
  final int id;
  final int roomId;
  final int senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String? content;
  final int? replyToMessageId;
  final String? replyToMessageSnippet;
  final String? replyToSenderName;
  final DateTime createdAt;
  final List<MessageAttachment> attachments;
  final List<MessageReaction> reactions;
  final bool isSentByMe;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.content,
    this.replyToMessageId,
    this.replyToMessageSnippet,
    this.replyToSenderName,
    required this.createdAt,
    this.attachments = const [],
    this.reactions = const [],
    this.isSentByMe = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    final senderId = (json['senderId'] as num?)?.toInt() ?? 0;
    final isMe = currentUserId != null && currentUserId == senderId;

    var attachList = <MessageAttachment>[];
    if (json['attachments'] is List) {
      attachList = (json['attachments'] as List)
          .map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    var reactList = <MessageReaction>[];
    if (json['reactions'] is List) {
      reactList = (json['reactions'] as List)
          .map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roomId: (json['roomId'] as num?)?.toInt() ?? 0,
      senderId: senderId,
      senderName: json['senderName']?.toString() ?? 'Người dùng',
      senderAvatarUrl: json['senderAvatarUrl']?.toString() ?? json['avatar']?.toString(),
      content: json['content']?.toString(),
      replyToMessageId: (json['replyToMessageId'] as num?)?.toInt(),
      replyToMessageSnippet: json['replyToMessageSnippet']?.toString(),
      replyToSenderName: json['replyToSenderName']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      attachments: attachList,
      reactions: reactList,
      isSentByMe: isMe,
    );
  }

  ChatMessage copyWith({
    int? id,
    int? roomId,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? content,
    int? replyToMessageId,
    String? replyToMessageSnippet,
    String? replyToSenderName,
    DateTime? createdAt,
    List<MessageAttachment>? attachments,
    List<MessageReaction>? reactions,
    bool? isSentByMe,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      content: content ?? this.content,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessageSnippet: replyToMessageSnippet ?? this.replyToMessageSnippet,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      isSentByMe: isSentByMe ?? this.isSentByMe,
    );
  }
}

class InboxItem {
  final int roomId;
  final String name;
  final String? avatarUrl;
  final bool isGroup;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final int? otherUserId;
  final bool isOnline;

  const InboxItem({
    required this.roomId,
    required this.name,
    this.avatarUrl,
    this.isGroup = false,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.otherUserId,
    this.isOnline = false,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    return InboxItem(
      roomId: (json['roomId'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Hội thoại',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar']?.toString(),
      isGroup: json['isGroup'] == true,
      lastMessage: json['lastMessage']?.toString(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      otherUserId: (json['otherUserId'] as num?)?.toInt(),
      isOnline: json['isOnline'] == true,
    );
  }

  InboxItem copyWith({
    int? roomId,
    String? name,
    String? avatarUrl,
    bool? isGroup,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    int? otherUserId,
    bool? isOnline,
  }) {
    return InboxItem(
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      otherUserId: otherUserId ?? this.otherUserId,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class ChatRoomMember {
  final int userId;
  final String name;
  final String? avatarUrl;
  final String? email;
  final DateTime joinedAt;

  const ChatRoomMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.email,
    required this.joinedAt,
  });

  factory ChatRoomMember.fromJson(Map<String, dynamic> json) {
    return ChatRoomMember(
      userId: (json['userId'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? json['fullName']?.toString() ?? 'Thành viên',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar']?.toString(),
      email: json['email']?.toString(),
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
