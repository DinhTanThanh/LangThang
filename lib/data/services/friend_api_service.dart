import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/friend_model.dart';
import 'auth_service.dart';

class FriendApiService {
  static final FriendApiService _instance = FriendApiService._internal();
  factory FriendApiService() => _instance;
  FriendApiService._internal();

  // In-memory mock storage for fallback
  final List<FriendUser> _mockFriends = [
    const FriendUser(
      id: 2,
      fullName: 'Lê Hoàng Long',
      email: 'hoanglong.travel@gmail.com',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&fit=crop',
      coverUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&fit=crop',
      bio: 'Đam mê phượt Tây Bắc & săn mây Tà Xùa',
      rankLevel: 'Thổ địa Hà Giang',
      reputationScore: 480,
      mutualFriendsCount: 5,
      status: FriendshipStatus.accepted,
      connectedDate: 'Đã kết bạn',
    ),
    const FriendUser(
      id: 3,
      fullName: 'Trần Thu Thảo',
      email: 'thuthao.blogger@gmail.com',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&fit=crop',
      coverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&fit=crop',
      bio: 'Yêu thích phố cổ Hội An & các món ăn cung đình Huế',
      rankLevel: 'Thổ địa Hội An',
      reputationScore: 320,
      mutualFriendsCount: 3,
      status: FriendshipStatus.accepted,
      connectedDate: 'Đã kết bạn',
    ),
    const FriendUser(
      id: 4,
      fullName: 'Nguyễn Hải Đăng',
      email: 'haidang.saigon@gmail.com',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop',
      coverUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800&fit=crop',
      bio: 'Nhiếp ảnh gia đường phố Sài Gòn',
      rankLevel: 'Thổ địa Sài Gòn',
      reputationScore: 590,
      mutualFriendsCount: 8,
      status: FriendshipStatus.accepted,
      connectedDate: 'Đã kết bạn',
    ),
    const FriendUser(
      id: 5,
      fullName: 'Võ Bích Trâm',
      email: 'bichtram.tour@gmail.com',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&fit=crop',
      coverUrl: 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=800&fit=crop',
      bio: 'HDV Du lịch sông nước Miền Tây & Chợ nổi Cái Răng',
      rankLevel: 'Thổ địa Cần Thơ',
      reputationScore: 240,
      mutualFriendsCount: 2,
      status: FriendshipStatus.pendingIncoming,
      connectedDate: 'Hôm nay',
    ),
    const FriendUser(
      id: 6,
      fullName: 'Đặng Minh Quân',
      email: 'minhquan.danang@gmail.com',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&fit=crop',
      coverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&fit=crop',
      bio: 'Local guide tại Đà Nẵng & Bà Nà Hills',
      rankLevel: 'Thổ địa Đà Nẵng',
      reputationScore: 410,
      mutualFriendsCount: 4,
      status: FriendshipStatus.pendingOutgoing,
      connectedDate: 'Hôm qua',
    ),
  ];

  Map<String, dynamic>? _tryDecodeJson(http.Response response) {
    try {
      final raw = utf8.decode(response.bodyBytes).trim();
      if (raw.isNotEmpty && (raw.startsWith('{') || raw.startsWith('['))) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Lấy danh sách bạn bè, lời mời đã nhận, lời mời đã gửi
  Future<ApiResponse<FriendsResponseModel>> getFriends() async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<FriendsResponseModel>(
          success: true,
          message: 'Chưa đăng nhập',
          data: FriendsResponseModel(),
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/users/me/friends');
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final json = _tryDecodeJson(res);
        if (json != null) {
          final dataJson = json['data'] ?? json;
          if (dataJson is Map<String, dynamic>) {
            final model = FriendsResponseModel.fromJson(dataJson);
            return ApiResponse<FriendsResponseModel>(
              success: true,
              message: json['message'] as String? ?? 'Tải danh sách bạn bè thành công',
              data: model,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[FriendApiService] getFriends error: $e');
    }

    return const ApiResponse<FriendsResponseModel>(
      success: true,
      message: 'Danh sách bạn bè trống',
      data: FriendsResponseModel(),
    );
  }

  /// Tìm kiếm người dùng theo tên hoặc ID
  Future<ApiResponse<List<FriendUser>>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const ApiResponse<List<FriendUser>>(
        success: true,
        message: '',
        data: [],
      );
    }

    try {
      final token = await AuthService().getAccessToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final endpoints = [
        '${ApiConstants.baseUrl}/api/users/search',
        '${ApiConstants.baseUrl}/api/friends/search',
      ];

      for (final ep in endpoints) {
        try {
          final uri = Uri.parse(ep).replace(
            queryParameters: {
              'q': cleanQuery,
              'keyword': cleanQuery,
            },
          );

          final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
          if (res.statusCode >= 200 && res.statusCode < 300) {
            final json = _tryDecodeJson(res);
            if (json != null) {
              final data = json['data'] ?? json;
              if (data is List) {
                final list = data.map((e) => FriendUser.fromJson(e as Map<String, dynamic>)).toList();
                return ApiResponse<List<FriendUser>>(
                  success: true,
                  message: 'Tìm kiếm thành công',
                  data: list,
                );
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[FriendApiService] searchUsers error: $e');
    }

    return const ApiResponse<List<FriendUser>>(
      success: true,
      message: 'Không tìm thấy người dùng phù hợp',
      data: [],
    );
  }

  /// Gửi lời mời kết bạn
  Future<ApiResponse<bool>> sendFriendRequest(int targetUserId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Bạn cần đăng nhập để gửi lời mời kết bạn',
          data: false,
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/friends/request');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'targetUserId': targetUserId}),
      ).timeout(const Duration(seconds: 8));

      final bodyStr = utf8.decode(res.bodyBytes).trim();
      final json = bodyStr.isNotEmpty ? jsonDecode(bodyStr) as Map<String, dynamic> : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
        _updateMockStatus(targetUserId, FriendshipStatus.pendingOutgoing);
        return ApiResponse<bool>(
          success: true,
          message: json['message'] as String? ?? 'Đã gửi lời mời kết bạn thành công',
          data: true,
        );
      } else {
        final errorMsg = json['message']?.toString() ?? 'Không thể gửi lời mời kết bạn.';
        return ApiResponse<bool>(
          success: false,
          message: errorMsg,
          data: false,
        );
      }
    } catch (e) {
      debugPrint('[FriendApiService] sendFriendRequest error: $e');
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        data: false,
      );
    }
  }

  /// Phản hồi lời mời kết bạn (accept / reject)
  Future<ApiResponse<bool>> respondFriendRequest(int targetUserId, String action) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Bạn cần đăng nhập để thực hiện thao tác',
          data: false,
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/friends/respond/$targetUserId');
      final res = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': action}),
      ).timeout(const Duration(seconds: 8));

      final bodyStr = utf8.decode(res.bodyBytes).trim();
      final json = bodyStr.isNotEmpty ? jsonDecode(bodyStr) as Map<String, dynamic> : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
        if (action == 'accept') {
          _updateMockStatus(targetUserId, FriendshipStatus.accepted);
        } else {
          _removeMockUser(targetUserId);
        }
        return ApiResponse<bool>(
          success: true,
          message: json['message'] as String? ?? (action == 'accept' ? 'Đã chấp nhận lời mời kết bạn' : 'Đã từ chối lời mời kết bạn'),
          data: true,
        );
      } else {
        final errorMsg = json['message']?.toString() ?? 'Không thể phản hồi lời mời kết bạn.';
        return ApiResponse<bool>(
          success: false,
          message: errorMsg,
          data: false,
        );
      }
    } catch (e) {
      debugPrint('[FriendApiService] respondFriendRequest error: $e');
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        data: false,
      );
    }
  }

  /// Hủy kết bạn hoặc hủy lời mời kết bạn đã gửi
  Future<ApiResponse<bool>> unfriend(int targetUserId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Bạn cần đăng nhập để thực hiện thao tác',
          data: false,
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/friends/$targetUserId');
      final res = await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final bodyStr = utf8.decode(res.bodyBytes).trim();
      final json = bodyStr.isNotEmpty ? jsonDecode(bodyStr) as Map<String, dynamic> : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
        _removeMockUser(targetUserId);
        return ApiResponse<bool>(
          success: true,
          message: json['message'] as String? ?? 'Đã hủy kết bạn thành công',
          data: true,
        );
      } else {
        final errorMsg = json['message']?.toString() ?? 'Không thể hủy kết bạn.';
        return ApiResponse<bool>(
          success: false,
          message: errorMsg,
          data: false,
        );
      }
    } catch (e) {
      debugPrint('[FriendApiService] unfriend error: $e');
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        data: false,
      );
    }
  }

  // ===== Local Mock Updaters =====
  void _updateMockStatus(int targetUserId, FriendshipStatus status) {
    final idx = _mockFriends.indexWhere((u) => u.id == targetUserId);
    if (idx != -1) {
      _mockFriends[idx] = _mockFriends[idx].copyWith(status: status);
    } else {
      _mockFriends.add(
        FriendUser(
          id: targetUserId,
          fullName: 'Người dùng #$targetUserId',
          status: status,
        ),
      );
    }
  }

  void _removeMockUser(int targetUserId) {
    _mockFriends.removeWhere((u) => u.id == targetUserId);
  }
}
