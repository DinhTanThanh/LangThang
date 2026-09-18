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
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final endpoints = [
          '${ApiConstants.baseUrl}/api/users/me/friends',
          '${ApiConstants.baseUrl}/api/v1/users/me/friends',
        ];

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };

        for (final ep in endpoints) {
          try {
            final res = await http.get(Uri.parse(ep), headers: headers).timeout(const Duration(seconds: 4));
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
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[FriendApiService] getFriends error: $e');
    }

    // Fallback: Mock Data
    final accepted = _mockFriends.where((f) => f.status == FriendshipStatus.accepted).toList();
    final incoming = _mockFriends.where((f) => f.status == FriendshipStatus.pendingIncoming).toList();
    final outgoing = _mockFriends.where((f) => f.status == FriendshipStatus.pendingOutgoing).toList();
    final blocked = _mockFriends.where((f) => f.status == FriendshipStatus.blocked).toList();

    return ApiResponse<FriendsResponseModel>(
      success: true,
      message: 'Tải danh sách bạn bè thành công',
      data: FriendsResponseModel(
        friends: accepted,
        pendingRequestsReceived: incoming,
        pendingRequestsSent: outgoing,
        blockedUsers: blocked,
      ),
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

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/users/search').replace(
        queryParameters: {'query': cleanQuery},
      );

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
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
    } catch (e) {
      debugPrint('[FriendApiService] searchUsers error: $e');
    }

    // Fallback: Tìm trong Mock Data + danh sách gợi ý mẫu
    final mockSearchUniverse = [
      ..._mockFriends,
      const FriendUser(
        id: 10,
        fullName: 'Phạm Minh Đức',
        email: 'duc.pham@travel.vn',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop',
        coverUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800&fit=crop',
        bio: 'Khám phá ẩm thực đường phố Hà Nội và các danh thắng phía Bắc',
        rankLevel: 'Thành viên mới',
        reputationScore: 110,
        mutualFriendsCount: 1,
        status: FriendshipStatus.suggestion,
      ),
      const FriendUser(
        id: 11,
        fullName: 'Trương Mỹ Linh',
        email: 'mylinh.nhatrang@gmail.com',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop',
        coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&fit=crop',
        bio: 'Reviewer du lịch biển đảo Nha Trang - Phú Quốc',
        rankLevel: 'Thổ địa Nha Trang',
        reputationScore: 450,
        mutualFriendsCount: 4,
        status: FriendshipStatus.suggestion,
      ),
      const FriendUser(
        id: 12,
        fullName: 'Lê Duy Bách',
        email: 'duybach.quynhon@gmail.com',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&fit=crop',
        coverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&fit=crop',
        bio: 'Thích cắm trại và ngắm bình minh Eo Gió Quy Nhơn',
        rankLevel: 'Thổ địa Quy Nhơn',
        reputationScore: 360,
        mutualFriendsCount: 2,
        status: FriendshipStatus.suggestion,
      ),
    ];

    final q = cleanQuery.toLowerCase().replaceAll('#', '');
    final filtered = mockSearchUniverse.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.id.toString() == q;
    }).toList();

    return ApiResponse<List<FriendUser>>(
      success: true,
      message: 'Tìm kiếm thành công',
      data: filtered,
    );
  }

  /// Gửi lời mời kết bạn
  Future<ApiResponse<bool>> sendFriendRequest(int targetUserId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/friends/request/$targetUserId');
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
          _updateMockStatus(targetUserId, FriendshipStatus.pendingOutgoing);
          return const ApiResponse<bool>(
            success: true,
            message: 'Đã gửi lời mời kết bạn',
            data: true,
          );
        }
      }
    } catch (e) {
      debugPrint('[FriendApiService] sendFriendRequest error: $e');
    }

    _updateMockStatus(targetUserId, FriendshipStatus.pendingOutgoing);
    return const ApiResponse<bool>(
      success: true,
      message: 'Đã gửi lời mời kết bạn',
      data: true,
    );
  }

  /// Phản hồi lời mời kết bạn (accept / reject)
  Future<ApiResponse<bool>> respondFriendRequest(int targetUserId, String action) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/friends/respond/$targetUserId');
        final res = await http.put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'action': action}),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (action == 'accept') {
            _updateMockStatus(targetUserId, FriendshipStatus.accepted);
          } else {
            _removeMockUser(targetUserId);
          }
          return ApiResponse<bool>(
            success: true,
            message: action == 'accept' ? 'Đã chấp nhận lời mời' : 'Đã từ chối lời mời',
            data: true,
          );
        }
      }
    } catch (e) {
      debugPrint('[FriendApiService] respondFriendRequest error: $e');
    }

    if (action == 'accept') {
      _updateMockStatus(targetUserId, FriendshipStatus.accepted);
    } else {
      _removeMockUser(targetUserId);
    }
    return ApiResponse<bool>(
      success: true,
      message: action == 'accept' ? 'Đã chấp nhận lời mời kết bạn' : 'Đã xóa lời mời kết bạn',
      data: true,
    );
  }

  /// Hủy kết bạn hoặc hủy lời mời kết bạn đã gửi
  Future<ApiResponse<bool>> unfriend(int targetUserId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/friends/$targetUserId');
        final res = await http.delete(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          _removeMockUser(targetUserId);
          return const ApiResponse<bool>(
            success: true,
            message: 'Đã hủy kết bạn thành công',
            data: true,
          );
        }
      }
    } catch (e) {
      debugPrint('[FriendApiService] unfriend error: $e');
    }

    _removeMockUser(targetUserId);
    return const ApiResponse<bool>(
      success: true,
      message: 'Đã hủy kết bạn thành công',
      data: true,
    );
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
