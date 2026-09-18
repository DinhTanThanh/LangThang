import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;
  ChatApiService._internal() {
    _initMockData();
  }

  final StreamController<ChatMessage> _messageStreamController = StreamController<ChatMessage>.broadcast();
  final StreamController<int> _unreadStreamController = StreamController<int>.broadcast();

  Stream<ChatMessage> get onMessageReceived => _messageStreamController.stream;
  Stream<int> get onTotalUnreadCountChanged => _unreadStreamController.stream;

  // In-memory persistent mock storage
  final List<InboxItem> _mockInbox = [];
  final Map<int, List<ChatMessage>> _mockRoomMessages = {};
  final Map<int, List<ChatRoomMember>> _mockRoomMembers = {};

  void _initMockData() {
    _mockInbox.addAll([
      InboxItem(
        roomId: 101,
        name: 'Lê Hoàng Long',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&fit=crop',
        isGroup: false,
        lastMessage: 'Cuối tuần này lên Tà Xùa săn mây không bạn ơi? ☁️',
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15)),
        unreadCount: 2,
        otherUserId: 2,
        isOnline: true,
      ),
      InboxItem(
        roomId: 102,
        name: 'Hội Phượt Xuyên Việt 🇻🇳',
        avatarUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=200&fit=crop',
        isGroup: true,
        lastMessage: 'Trần Thu Thảo: Mình vừa đăng cẩm nang Hội An mọi người vào xem nhé!',
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 0,
        isOnline: true,
      ),
      InboxItem(
        roomId: 103,
        name: 'Trần Thu Thảo',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&fit=crop',
        isGroup: false,
        lastMessage: 'Địa điểm này đẹp thật, cảm ơn bạn đã chia sẻ nhé! ❤️',
        lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        otherUserId: 3,
        isOnline: false,
      ),
      InboxItem(
        roomId: 104,
        name: 'Nguyễn Hải Đăng',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop',
        isGroup: false,
        lastMessage: 'Quán cà phê view sông Sài Gòn ở quận 2 siêu chill ☕',
        lastMessageAt: DateTime.now().subtract(const Duration(days: 3)),
        unreadCount: 0,
        otherUserId: 4,
        isOnline: true,
      ),
    ]);

    // Messages for Room 101 (Lê Hoàng Long)
    _mockRoomMessages[101] = [
      ChatMessage(
        id: 1001,
        roomId: 101,
        senderId: 2,
        senderName: 'Lê Hoàng Long',
        senderAvatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&fit=crop',
        content: 'Chào bạn! Mình thấy bạn cũng thích phượt Tây Bắc đúng không?',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        isSentByMe: false,
        reactions: [
          MessageReaction(
            messageId: 1001,
            userId: 1,
            userName: 'Tôi',
            emoji: '👋',
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          ),
        ],
      ),
      ChatMessage(
        id: 1002,
        roomId: 101,
        senderId: 1,
        senderName: 'Tôi',
        content: 'Đúng rồi bạn, mình thích nhất là cung đường Mã Pí Lèng và đèo Ô Quy Hồ.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
        isSentByMe: true,
      ),
      ChatMessage(
        id: 1003,
        roomId: 101,
        senderId: 2,
        senderName: 'Lê Hoàng Long',
        senderAvatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&fit=crop',
        content: 'Tuyệt vời luôn! Địa điểm này mùa này lúa chín vàng ươm nè:',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isSentByMe: false,
        attachments: const [
          MessageAttachment(
            id: 201,
            attachmentType: MessageAttachmentType.place,
            placeId: 1,
            placeName: 'Đèo Mã Pí Lèng & Sông Nho Quế',
            placeCoverUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&fit=crop',
            placeProvince: 'Hà Giang',
            placeRating: 4.9,
            placePrice: 'Miễn phí',
          ),
        ],
      ),
      ChatMessage(
        id: 1004,
        roomId: 101,
        senderId: 2,
        senderName: 'Lê Hoàng Long',
        senderAvatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&fit=crop',
        content: 'Cuối tuần này lên Tà Xùa săn mây không bạn ơi? ☁️',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        isSentByMe: false,
      ),
    ];

    // Messages for Room 102 (Hội Phượt Xuyên Việt)
    _mockRoomMessages[102] = [
      ChatMessage(
        id: 2001,
        roomId: 102,
        senderId: 4,
        senderName: 'Nguyễn Hải Đăng',
        senderAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop',
        content: 'Xin chào cả nhà! Mọi người đã lên lịch cho chuyến đi mùa thu chưa?',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isSentByMe: false,
      ),
      ChatMessage(
        id: 2002,
        roomId: 102,
        senderId: 3,
        senderName: 'Trần Thu Thảo',
        senderAvatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&fit=crop',
        content: 'Mình vừa đăng cẩm nang Hội An mọi người vào xem nhé!',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isSentByMe: false,
        attachments: const [
          MessageAttachment(
            id: 202,
            attachmentType: MessageAttachmentType.place,
            placeId: 3,
            placeName: 'Phố cổ Hội An',
            placeCoverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&fit=crop',
            placeProvince: 'Quảng Nam',
            placeRating: 4.8,
            placePrice: 'Miễn phí',
          ),
        ],
      ),
    ];
  }

  Map<String, dynamic>? _tryDecodeJson(http.Response response) {
    try {
      final raw = utf8.decode(response.bodyBytes).trim();
      if (raw.isNotEmpty && (raw.startsWith('{') || raw.startsWith('['))) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is List) {
          return {'data': decoded};
        }
      }
    } catch (_) {}
    return null;
  }

  /// Lấy danh sách hộp thư Inbox
  Future<ApiResponse<List<InboxItem>>> getInbox() async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final endpoints = [
          '${ApiConstants.baseUrl}/api/chat/inbox',
          '${ApiConstants.baseUrl}/api/v1/chat/inbox',
        ];
        final headers = {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };

        for (final ep in endpoints) {
          try {
            final res = await http.get(Uri.parse(ep), headers: headers).timeout(const Duration(seconds: 4));
            if (res.statusCode >= 200 && res.statusCode < 300) {
              final json = _tryDecodeJson(res);
              if (json != null) {
                dynamic items = json['data'] ?? json['items'] ?? json;
                if (items is Map && items['items'] is List) items = items['items'];
                if (items is List) {
                  final list = items.map((e) => InboxItem.fromJson(e as Map<String, dynamic>)).toList();
                  return ApiResponse<List<InboxItem>>(
                    success: true,
                    message: 'Tải hộp thư thành công',
                    data: list,
                  );
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] getInbox error: $e');
    }

    // Return in-memory mock data
    return ApiResponse<List<InboxItem>>(
      success: true,
      message: 'Tải hộp thư thành công',
      data: List.from(_mockInbox),
    );
  }

  /// Lấy hoặc tạo phòng chat 1-1 với người dùng khác
  Future<ApiResponse<int>> getOrCreateDirectRoom(int targetUserId, {String? targetUserName, String? targetUserAvatar}) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/direct/$targetUserId');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({}),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = _tryDecodeJson(res);
          if (json != null) {
            final roomId = (json['roomId'] as num?)?.toInt() ??
                (json['data']?['roomId'] as num?)?.toInt() ??
                (json['data'] as num?)?.toInt();
            if (roomId != null && roomId > 0) {
              return ApiResponse<int>(
                success: true,
                message: 'Mở phòng chat thành công',
                data: roomId,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] getOrCreateDirectRoom error: $e');
    }

    // Fallback: Tìm hoặc tạo phòng trong mock storage
    final existing = _mockInbox.where((item) => !item.isGroup && item.otherUserId == targetUserId).toList();
    if (existing.isNotEmpty) {
      return ApiResponse<int>(
        success: true,
        message: 'Mở phòng chat thành công',
        data: existing.first.roomId,
      );
    }

    final newRoomId = 100 + targetUserId;
    final newItem = InboxItem(
      roomId: newRoomId,
      name: targetUserName ?? 'Người dùng #$targetUserId',
      avatarUrl: targetUserAvatar ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&fit=crop',
      isGroup: false,
      lastMessage: 'Bắt đầu cuộc trò chuyện',
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
      otherUserId: targetUserId,
      isOnline: true,
    );
    _mockInbox.insert(0, newItem);
    _mockRoomMessages[newRoomId] = [];

    return ApiResponse<int>(
      success: true,
      message: 'Mở phòng chat thành công',
      data: newRoomId,
    );
  }

  /// Lấy lịch sử tin nhắn phòng chat
  Future<ApiResponse<List<ChatMessage>>> getRoomMessages(int roomId, {int page = 1, int limit = 50}) async {
    try {
      final token = await AuthService().getAccessToken();
      final user = await AuthService().getCachedUser();
      final currentUserId = int.tryParse(user?.id ?? '');

      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/messages').replace(
          queryParameters: {'page': '$page', 'limit': '$limit'},
        );
        final res = await http.get(uri, headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 4));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = _tryDecodeJson(res);
          if (json != null) {
            dynamic items = json['data'] ?? json['items'] ?? json;
            if (items is Map && items['items'] is List) items = items['items'];
            if (items is List) {
              final list = items.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>, currentUserId: currentUserId)).toList();
              return ApiResponse<List<ChatMessage>>(
                success: true,
                message: 'Tải tin nhắn thành công',
                data: list,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] getRoomMessages error: $e');
    }

    // Return mock messages
    final msgs = _mockRoomMessages[roomId] ?? [];
    return ApiResponse<List<ChatMessage>>(
      success: true,
      message: 'Tải tin nhắn thành công',
      data: List.from(msgs),
    );
  }

  /// Gửi tin nhắn
  Future<ApiResponse<ChatMessage>> sendMessage({
    required int roomId,
    String? content,
    int? replyToMessageId,
    String? replySnippet,
    String? replySenderName,
    int? placeId,
    String? placeName,
    String? placeCoverUrl,
    String? placeProvince,
    double? placeRating,
    String? placePrice,
    String? foodId,
    String? foodName,
    String? foodCoverUrl,
    String? foodProvince,
    String? foodPrice,
    double? foodRating,
    int? tripId,
    String? tripTitle,
    String? tripCoverUrl,
    String? tripDuration,
    String? tripDestination,
    String? fileName,
    int? fileSizeBytes,
    int? durationSeconds,
    String? mediaUrl,
    List<String>? imageUrls,
  }) async {
    final user = await AuthService().getCachedUser();
    final myId = int.tryParse(user?.id ?? '') ?? 1;
    final myName = user?.fullName ?? 'Tôi';
    final myAvatar = user?.avatarUrl;

    List<MessageAttachment> attachments = [];

    if (placeId != null && placeId > 0) {
      attachments.add(
        MessageAttachment(
          id: DateTime.now().millisecondsSinceEpoch,
          attachmentType: MessageAttachmentType.place,
          placeId: placeId,
          placeName: placeName ?? 'Địa điểm du lịch',
          placeCoverUrl: placeCoverUrl,
          placeProvince: placeProvince ?? 'Việt Nam',
          placeRating: placeRating ?? 5.0,
          placePrice: placePrice ?? 'Miễn phí',
        ),
      );
    }

    if (foodName != null && foodName.isNotEmpty) {
      attachments.add(
        MessageAttachment(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          attachmentType: MessageAttachmentType.food,
          foodId: foodId,
          foodName: foodName,
          foodCoverUrl: foodCoverUrl,
          foodProvince: foodProvince,
          foodPrice: foodPrice,
          foodRating: foodRating ?? 5.0,
        ),
      );
    }

    if (tripTitle != null && tripTitle.isNotEmpty) {
      attachments.add(
        MessageAttachment(
          id: DateTime.now().millisecondsSinceEpoch + 2,
          attachmentType: MessageAttachmentType.trip,
          tripId: tripId,
          tripTitle: tripTitle,
          tripCoverUrl: tripCoverUrl,
          tripDuration: tripDuration,
          tripDestination: tripDestination,
        ),
      );
    }

    if (fileName != null && fileName.isNotEmpty) {
      attachments.add(
        MessageAttachment(
          id: DateTime.now().millisecondsSinceEpoch + 3,
          attachmentType: MessageAttachmentType.file,
          fileName: fileName,
          fileSizeBytes: fileSizeBytes ?? 2048576,
          mediaUrl: mediaUrl,
        ),
      );
    }

    if (durationSeconds != null && durationSeconds > 0) {
      attachments.add(
        MessageAttachment(
          id: DateTime.now().millisecondsSinceEpoch + 4,
          attachmentType: MessageAttachmentType.audio,
          durationSeconds: durationSeconds,
          mediaUrl: mediaUrl,
        ),
      );
    }

    if (imageUrls != null && imageUrls.isNotEmpty) {
      for (final url in imageUrls) {
        attachments.add(
          MessageAttachment(
            id: DateTime.now().millisecondsSinceEpoch + attachments.length,
            attachmentType: MessageAttachmentType.image,
            mediaUrl: url,
          ),
        );
      }
    }

    final newMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      roomId: roomId,
      senderId: myId,
      senderName: myName,
      senderAvatarUrl: myAvatar,
      content: content,
      replyToMessageId: replyToMessageId,
      replyToMessageSnippet: replySnippet,
      replyToSenderName: replySenderName,
      createdAt: DateTime.now(),
      attachments: attachments,
      isSentByMe: true,
    );

    // Update in-memory storage
    if (!_mockRoomMessages.containsKey(roomId)) {
      _mockRoomMessages[roomId] = [];
    }
    _mockRoomMessages[roomId]!.add(newMsg);

    // Update inbox last message
    final inboxIdx = _mockInbox.indexWhere((i) => i.roomId == roomId);
    if (inboxIdx != -1) {
      final item = _mockInbox[inboxIdx];
      String lastText = content?.isNotEmpty == true
          ? content!
          : (placeId != null
              ? '📍 [Địa điểm] $placeName'
              : (foodName != null
                  ? '🍜 [Món ăn] $foodName'
                  : (tripTitle != null
                      ? '🗺️ [Lịch trình] $tripTitle'
                      : (fileName != null ? '📁 [Tệp] $fileName' : (durationSeconds != null ? '🎙️ [Tin nhắn thoại]' : '📷 [Hình ảnh]')))));
      _mockInbox[inboxIdx] = item.copyWith(
        lastMessage: lastText,
        lastMessageAt: DateTime.now(),
      );
      // Move to top
      final updated = _mockInbox.removeAt(inboxIdx);
      _mockInbox.insert(0, updated);
    }

    _messageStreamController.add(newMsg);

    // Simulate instant partner auto-reply in demo mode if 1-1 chat
    _scheduleDemoPartnerReply(roomId, myName, content, placeName);

    return ApiResponse<ChatMessage>(
      success: true,
      message: 'Gửi tin nhắn thành công',
      data: newMsg,
    );
  }

  void _scheduleDemoPartnerReply(int roomId, String myName, String? sentText, String? placeName) {
    final inboxItem = _mockInbox.where((i) => i.roomId == roomId).firstOrNull;
    if (inboxItem == null || inboxItem.isGroup) return;

    Timer(const Duration(seconds: 2), () {
      final replies = [
        placeName != null
            ? 'Cảm ơn $myName đã chia sẻ địa điểm $placeName nhé, trông tuyệt quá! 😍'
            : 'Okie $myName, mình đã nhận được tin nhắn!',
        'Chuyến đi này chắc chắn sẽ rất vui đấy! ✨',
        'Mình đã lưu lại vào lịch trình rồi nha. 👍',
      ];
      final replyText = (replies..shuffle()).first;

      final partnerMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        roomId: roomId,
        senderId: inboxItem.otherUserId ?? 2,
        senderName: inboxItem.name,
        senderAvatarUrl: inboxItem.avatarUrl,
        content: replyText,
        createdAt: DateTime.now(),
        isSentByMe: false,
      );

      _mockRoomMessages[roomId]?.add(partnerMsg);

      final idx = _mockInbox.indexWhere((i) => i.roomId == roomId);
      if (idx != -1) {
        _mockInbox[idx] = _mockInbox[idx].copyWith(
          lastMessage: replyText,
          lastMessageAt: DateTime.now(),
        );
      }

      _messageStreamController.add(partnerMsg);
    });
  }

  /// Đánh dấu đã đọc phòng chat
  Future<ApiResponse<bool>> markRoomAsRead(int roomId) async {
    final idx = _mockInbox.indexWhere((i) => i.roomId == roomId);
    if (idx != -1) {
      _mockInbox[idx] = _mockInbox[idx].copyWith(unreadCount: 0);
      _unreadStreamController.add(getTotalUnreadCount());
    }
    return const ApiResponse<bool>(success: true, message: 'Đã đọc', data: true);
  }

  /// Thả cảm xúc
  Future<ApiResponse<bool>> addMessageReaction(int roomId, int messageId, String emoji) async {
    final msgs = _mockRoomMessages[roomId];
    if (msgs != null) {
      final msgIdx = msgs.indexWhere((m) => m.id == messageId);
      if (msgIdx != -1) {
        final currentMsg = msgs[msgIdx];
        final existingReactionIdx = currentMsg.reactions.indexWhere((r) => r.userId == 1);
        List<MessageReaction> newReactions = List.from(currentMsg.reactions);

        if (existingReactionIdx != -1) {
          if (newReactions[existingReactionIdx].emoji == emoji) {
            newReactions.removeAt(existingReactionIdx);
          } else {
            newReactions[existingReactionIdx] = MessageReaction(
              messageId: messageId,
              userId: 1,
              userName: 'Tôi',
              emoji: emoji,
              createdAt: DateTime.now(),
            );
          }
        } else {
          newReactions.add(
            MessageReaction(
              messageId: messageId,
              userId: 1,
              userName: 'Tôi',
              emoji: emoji,
              createdAt: DateTime.now(),
            ),
          );
        }

        msgs[msgIdx] = currentMsg.copyWith(reactions: newReactions);
      }
    }
    return const ApiResponse<bool>(success: true, message: 'Thả cảm xúc thành công', data: true);
  }

  /// Tạo nhóm chat mới
  Future<ApiResponse<int>> createGroupRoom(String name, List<int> memberIds) async {
    final newRoomId = 500 + DateTime.now().millisecondsSinceEpoch % 1000;
    final newGroup = InboxItem(
      roomId: newRoomId,
      name: name.isNotEmpty ? name : 'Nhóm phượt mới',
      avatarUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=200&fit=crop',
      isGroup: true,
      lastMessage: 'Đã tạo nhóm chat',
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
      isOnline: true,
    );

    _mockInbox.insert(0, newGroup);
    _mockRoomMessages[newRoomId] = [
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        roomId: newRoomId,
        senderId: 1,
        senderName: 'Hệ thống',
        content: 'Chào mừng các thành viên đến với nhóm "$name"!',
        createdAt: DateTime.now(),
        isSentByMe: false,
      ),
    ];

    return ApiResponse<int>(
      success: true,
      message: 'Tạo nhóm chat thành công',
      data: newRoomId,
    );
  }

  /// Lấy danh sách thành viên phòng chat
  Future<ApiResponse<List<ChatRoomMember>>> getRoomMembers(int roomId) async {
    final members = _mockRoomMembers[roomId] ?? [
      ChatRoomMember(
        userId: 1,
        name: 'Tôi (Bạn)',
        avatarUrl: null,
        email: 'me@langthang.vn',
        joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      ChatRoomMember(
        userId: 2,
        name: 'Lê Hoàng Long',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&fit=crop',
        email: 'long.le@gmail.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      ChatRoomMember(
        userId: 3,
        name: 'Trần Thu Thảo',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&fit=crop',
        email: 'thuthao@gmail.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    return ApiResponse<List<ChatRoomMember>>(
      success: true,
      message: 'Thành công',
      data: members,
    );
  }

  int getTotalUnreadCount() {
    return _mockInbox.fold(0, (sum, item) => sum + item.unreadCount);
  }
}
