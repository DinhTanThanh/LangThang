import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/chat_model.dart';
import 'auth_service.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;
  ChatApiService._internal();

  final StreamController<ChatMessage> _messageStreamController = StreamController<ChatMessage>.broadcast();
  final StreamController<int> _unreadStreamController = StreamController<int>.broadcast();

  Stream<ChatMessage> get onMessageReceived => _messageStreamController.stream;
  Stream<int> get onTotalUnreadCountChanged => _unreadStreamController.stream;

  int _cachedTotalUnread = 0;

  int getTotalUnreadCount() {
    if (AuthService().currentUser == null) {
      return 0;
    }
    return _cachedTotalUnread;
  }

  void clearCache() {
    _cachedTotalUnread = 0;
    if (!_unreadStreamController.isClosed) {
      _unreadStreamController.add(0);
    }
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

  /// Lấy danh sách hộp thư Inbox thật từ database
  Future<ApiResponse<List<InboxItem>>> getInbox() async {
    try {
      final isLoggedIn = await AuthService().isLoggedIn();
      if (!isLoggedIn) {
        _cachedTotalUnread = 0;
        _unreadStreamController.add(0);
        return const ApiResponse<List<InboxItem>>(
          success: false,
          message: 'UNAUTHORIZED: Chưa đăng nhập hoặc token đã hết hạn.',
          data: [],
        );
      }

      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        _cachedTotalUnread = 0;
        _unreadStreamController.add(0);
        return const ApiResponse<List<InboxItem>>(
          success: false,
          message: 'UNAUTHORIZED: Chưa đăng nhập hoặc token đã hết hạn.',
          data: [],
        );
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/chat/inbox');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 401) {
        _cachedTotalUnread = 0;
        _unreadStreamController.add(0);
        return const ApiResponse<List<InboxItem>>(
          success: false,
          message: 'UNAUTHORIZED: Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          data: [],
        );
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final json = _tryDecodeJson(res);
        if (json != null) {
          dynamic items = json['data'] ?? json['items'] ?? json;
          if (items is Map && items['items'] is List) items = items['items'];
          if (items is List) {
            final list = items.map((e) => InboxItem.fromJson(e as Map<String, dynamic>)).toList();
            
            // Tính tổng số tin nhắn chưa đọc từ dữ liệu thật
            _cachedTotalUnread = list.fold<int>(0, (sum, item) => sum + item.unreadCount);
            _unreadStreamController.add(_cachedTotalUnread);

            return ApiResponse<List<InboxItem>>(
              success: true,
              message: 'Tải hộp thư thành công',
              data: list,
            );
          }
        }
      }

      _cachedTotalUnread = 0;
      _unreadStreamController.add(0);
      return const ApiResponse<List<InboxItem>>(
        success: true,
        message: 'Hộp thư trống',
        data: [],
      );
    } catch (e) {
      debugPrint('[ChatApiService] getInbox error: $e');
      _cachedTotalUnread = 0;
      _unreadStreamController.add(0);
      return ApiResponse<List<InboxItem>>(
        success: false,
        message: 'Lỗi khi tải hộp thư: $e',
        data: const [],
      );
    }
  }

  /// Lấy hoặc tạo phòng chat 1-1 với người dùng khác trong database
  Future<ApiResponse<int>> getOrCreateDirectRoom(int targetUserId, {String? targetUserName, String? targetUserAvatar}) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<int>(
          success: false,
          message: 'Vui lòng đăng nhập để bắt đầu trò chuyện',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/direct/$targetUserId');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'targetUserId': targetUserId}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 401) {
        return const ApiResponse<int>(
          success: false,
          message: 'UNAUTHORIZED: Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }

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

      final jsonErr = _tryDecodeJson(res);
      final serverMsg = (jsonErr?['message'] as String?) ??
          (jsonErr?['title'] as String?) ??
          'Không thể kết nối đến phòng trò chuyện.';

      return ApiResponse<int>(
        success: false,
        message: serverMsg,
      );
    } catch (e) {
      return ApiResponse<int>(
        success: false,
        message: 'Lỗi khi mở phòng chat: $e',
      );
    }
  }

  /// Tạo phòng chat nhóm
  Future<ApiResponse<int>> createGroupRoom(String name, List<int> memberUserIds) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<int>(
          success: false,
          message: 'AUTH_REQUIRED',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/group');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name.trim(),
          'memberUserIds': memberUserIds,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final json = _tryDecodeJson(res);
        if (json != null) {
          final roomId = (json['data']?['roomId'] as num?)?.toInt() ?? (json['data'] as num?)?.toInt();
          if (roomId != null && roomId > 0) {
            return ApiResponse<int>(
              success: true,
              message: 'Tạo nhóm thành công',
              data: roomId,
            );
          }
        }
      }
      return const ApiResponse<int>(
        success: false,
        message: 'Không thể tạo nhóm trò chuyện lúc này',
      );
    } catch (e) {
      return ApiResponse<int>(
        success: false,
        message: 'Lỗi: $e',
      );
    }
  }

  /// Lấy lịch sử tin nhắn thật của phòng chat từ database
  Future<ApiResponse<List<ChatMessage>>> getRoomMessages(int roomId, {int page = 1, int limit = 50}) async {
    try {
      final token = await AuthService().getAccessToken();
      final user = await AuthService().getCachedUser();
      final currentUserId = int.tryParse(user?.id ?? '');

      if (token == null || token.isEmpty) {
        return const ApiResponse<List<ChatMessage>>(
          success: false,
          message: 'Chưa đăng nhập',
          data: [],
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/messages').replace(
        queryParameters: {'page': '$page', 'limit': '$limit'},
      );
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 401) {
        return const ApiResponse<List<ChatMessage>>(
          success: false,
          message: 'UNAUTHORIZED: Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          data: [],
        );
      }

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

      return const ApiResponse<List<ChatMessage>>(
        success: true,
        message: 'Chưa có tin nhắn',
        data: [],
      );
    } catch (e) {
      debugPrint('[ChatApiService] getRoomMessages error: $e');
      return ApiResponse<List<ChatMessage>>(
        success: false,
        message: 'Lỗi khi tải tin nhắn: $e',
        data: const [],
      );
    }
  }

  /// Gửi tin nhắn lên database
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
    String? blogId,
    String? blogTitle,
    String? blogCoverUrl,
    String? blogCategory,
    String? blogAuthorName,
    String? blogAuthorAvatar,
    int? blogReadTimeMinutes,
    String? blogSummary,
    String? fileName,
    int? fileSizeBytes,
    int? durationSeconds,
    String? mediaUrl,
    List<String>? imageUrls,
    List<File>? fileList,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      final user = await AuthService().getCachedUser();
      final myId = int.tryParse(user?.id ?? '') ?? 0;

      if (token == null || token.isEmpty) {
        return const ApiResponse<ChatMessage>(
          success: false,
          message: 'Vui lòng đăng nhập để gửi tin nhắn.',
        );
      }

      if (fileList != null && fileList.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/messages/files');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['RoomId'] = '$roomId';
        if (content != null && content.isNotEmpty) request.fields['Content'] = content;
        if (replyToMessageId != null) request.fields['ReplyToMessageId'] = '$replyToMessageId';
        if (placeId != null && placeId > 0) request.fields['PlaceId'] = '$placeId';
        if (foodId != null && int.tryParse(foodId) != null) request.fields['FoodId'] = foodId;
        if (tripId != null && tripId > 0) request.fields['TripId'] = '$tripId';

        for (final file in fileList) {
          if (await file.exists()) {
            final fileNameOnly = file.path.split(Platform.pathSeparator).last;
            final bytes = await file.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes(
              'Files',
              bytes,
              filename: fileNameOnly,
            ));
          }
        }

        final streamed = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = _tryDecodeJson(response);
          if (json != null) {
            final data = json['data'] ?? json;
            if (data is Map<String, dynamic>) {
              final createdMsg = ChatMessage.fromJson(data, currentUserId: myId);
              _messageStreamController.add(createdMsg);
              return ApiResponse<ChatMessage>(
                success: true,
                message: 'Gửi tin nhắn thành công',
                data: createdMsg,
              );
            }
          }
        }

        if (response.statusCode == 401) {
          return const ApiResponse<ChatMessage>(
            success: false,
            message: 'UNAUTHORIZED: Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          );
        }

        final jsonErr = _tryDecodeJson(response);
        final errMsg = (jsonErr?['message'] as String?) ??
            (jsonErr?['title'] as String?) ??
            (jsonErr?['error'] as String?) ??
            'Không thể gửi tin nhắn lúc này (Mã lỗi: ${response.statusCode}).';

        return ApiResponse<ChatMessage>(
          success: false,
          message: errMsg,
        );
      } else {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/messages');
        final reqBody = <String, dynamic>{'roomId': roomId};
        if (content != null && content.isNotEmpty) reqBody['content'] = content;
        if (replyToMessageId != null) reqBody['replyToMessageId'] = replyToMessageId;
        if (placeId != null && placeId > 0) reqBody['placeId'] = placeId;
        if (foodId != null && int.tryParse(foodId) != null) reqBody['foodId'] = int.parse(foodId);
        if (tripId != null && tripId > 0) reqBody['tripId'] = tripId;

        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(reqBody),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 401) {
          return const ApiResponse<ChatMessage>(
            success: false,
            message: 'UNAUTHORIZED: Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          );
        }

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = _tryDecodeJson(res);
          if (json != null) {
            final data = json['data'] ?? json;
            if (data is Map<String, dynamic>) {
              final createdMsg = ChatMessage.fromJson(data, currentUserId: myId);
              _messageStreamController.add(createdMsg);
              return ApiResponse<ChatMessage>(
                success: true,
                message: 'Gửi tin nhắn thành công',
                data: createdMsg,
              );
            }
          }
        }

        final jsonErr = _tryDecodeJson(res);
        final errMsg = (jsonErr?['message'] as String?) ??
            (jsonErr?['title'] as String?) ??
            (jsonErr?['error'] as String?) ??
            'Không thể gửi tin nhắn lúc này (Mã lỗi: ${res.statusCode}).';

        return ApiResponse<ChatMessage>(
          success: false,
          message: errMsg,
        );
      }
    } catch (e) {
      debugPrint('[ChatApiService] sendMessage error: $e');
      return ApiResponse<ChatMessage>(
        success: false,
        message: 'Lỗi khi gửi tin nhắn: $e',
      );
    }
  }

  /// Đánh dấu phòng đã đọc
  Future<bool> markRoomAsRead(int roomId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/read');
        await http.put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          body: jsonEncode({}),
        ).timeout(const Duration(seconds: 5));
        
        // Cập nhật lại inbox
        getInbox();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Thêm cảm xúc cho tin nhắn
  Future<bool> addReaction(int messageId, String emoji, {int? roomId}) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/messages/$messageId/reactions');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'emoji': emoji,
            if (roomId != null && roomId > 0) 'roomId': roomId,
          }),
        ).timeout(const Duration(seconds: 5));
        return res.statusCode >= 200 && res.statusCode < 300;
      }
    } catch (_) {}
    return false;
  }

  /// Xóa tin nhắn
  Future<ApiResponse<bool>> deleteMessage(int roomId, int messageId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/messages/$messageId');
        final res = await http.delete(uri, headers: {
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 5));
        final isOk = res.statusCode >= 200 && res.statusCode < 300;
        return ApiResponse<bool>(
          success: isOk,
          message: isOk ? 'Đã xóa tin nhắn' : 'Không thể xóa tin nhắn',
          data: isOk,
        );
      }
    } catch (_) {}
    return const ApiResponse<bool>(
      success: false,
      message: 'Lỗi khi xóa tin nhắn',
      data: false,
    );
  }

  /// Sửa tin nhắn
  Future<ApiResponse<bool>> editMessage(int roomId, int messageId, String newContent) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/messages/$messageId');
        final res = await http.put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'content': newContent}),
        ).timeout(const Duration(seconds: 5));
        final isOk = res.statusCode >= 200 && res.statusCode < 300;
        return ApiResponse<bool>(
          success: isOk,
          message: isOk ? 'Đã sửa tin nhắn' : 'Không thể sửa tin nhắn',
          data: isOk,
        );
      }
    } catch (_) {}
    return const ApiResponse<bool>(
      success: false,
      message: 'Lỗi khi sửa tin nhắn',
      data: false,
    );
  }

  /// Lấy danh sách thành viên phòng
  Future<ApiResponse<List<ChatRoomMember>>> getRoomMembers(int roomId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/members');
        final res = await http.get(uri, headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 5));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = _tryDecodeJson(res);
          if (json != null) {
            dynamic items = json['data'] ?? json['items'] ?? json;
            if (items is List) {
              final list = items.map((e) => ChatRoomMember.fromJson(e as Map<String, dynamic>)).toList();
              return ApiResponse<List<ChatRoomMember>>(
                success: true,
                message: 'Thành công',
                data: list,
              );
            }
          }
        }
      }
      return const ApiResponse<List<ChatRoomMember>>(
        success: true,
        message: 'Thành công',
        data: [],
      );
    } catch (e) {
      return ApiResponse<List<ChatRoomMember>>(
        success: false,
        message: 'Lỗi: $e',
        data: const [],
      );
    }
  }

  /// Đổi tên nhóm (renameRoom)
  Future<ApiResponse<bool>> renameRoom(int roomId, String newName) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/name');
        final res = await http.put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': newName}),
        ).timeout(const Duration(seconds: 5));
        final isOk = res.statusCode >= 200 && res.statusCode < 300;
        return ApiResponse<bool>(
          success: isOk,
          message: isOk ? 'Đổi tên nhóm thành công' : 'Không thể đổi tên nhóm',
          data: isOk,
        );
      }
    } catch (_) {}
    return const ApiResponse<bool>(
      success: false,
      message: 'Lỗi khi đổi tên nhóm',
      data: false,
    );
  }

  /// Rời phòng chat
  Future<ApiResponse<bool>> leaveRoom(int roomId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/leave');
        final res = await http.post(uri, headers: {
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 5));
        final isOk = res.statusCode >= 200 && res.statusCode < 300;
        return ApiResponse<bool>(
          success: isOk,
          message: isOk ? 'Đã rời nhóm' : 'Không thể rời nhóm',
          data: isOk,
        );
      }
    } catch (_) {}
    return const ApiResponse<bool>(
      success: false,
      message: 'Lỗi khi rời nhóm',
      data: false,
    );
  }

  /// Thêm 1 thành viên vào nhóm
  Future<ApiResponse<bool>> addMemberToRoom(int roomId, int memberUserId) async {
    return addMembersToRoom(roomId, [memberUserId]);
  }

  /// Thêm danh sách thành viên vào nhóm
  Future<ApiResponse<bool>> addMembersToRoom(int roomId, List<int> userIds) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/members');
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'userIds': userIds}),
        ).timeout(const Duration(seconds: 5));
        final isOk = res.statusCode >= 200 && res.statusCode < 300;
        return ApiResponse<bool>(
          success: isOk,
          message: isOk ? 'Thêm thành viên thành công' : 'Không thể thêm thành viên',
          data: isOk,
        );
      }
    } catch (_) {}
    return const ApiResponse<bool>(
      success: false,
      message: 'Lỗi khi thêm thành viên',
      data: false,
    );
  }

  /// Xóa thành viên khỏi nhóm
  Future<bool> removeMemberFromRoom(int roomId, int memberId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/chat/rooms/$roomId/members/$memberId');
        final res = await http.delete(uri, headers: {
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 5));
        return res.statusCode >= 200 && res.statusCode < 300;
      }
    } catch (_) {}
    return false;
  }
}
