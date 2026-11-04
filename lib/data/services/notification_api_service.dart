import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';

class NotificationApiService {
  static final NotificationApiService _instance = NotificationApiService._internal();
  factory NotificationApiService() => _instance;
  NotificationApiService._internal();

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  int get unreadCount => unreadCountNotifier.value;

  void clearCache() {
    unreadCountNotifier.value = 0;
  }

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

  /// Lấy danh sách thông báo từ API thật: GET /api/notifications?page=1&pageSize=20&unreadOnly=false
  Future<ApiResponse<NotificationPagedResult>> getNotifications({
    int page = 1,
    int pageSize = 20,
    bool? unreadOnly,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        unreadCountNotifier.value = 0;
        return ApiResponse<NotificationPagedResult>(
          success: true,
          message: 'Chưa đăng nhập',
          data: NotificationPagedResult.empty(),
        );
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (unreadOnly != null && unreadOnly) {
        queryParams['unreadOnly'] = 'true';
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notifications}')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final json = _tryDecodeJson(response);
      if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
        final dataJson = json['data'] as Map<String, dynamic>? ?? {};
        final result = NotificationPagedResult.fromJson(dataJson);

        // Cập nhật unread count realtime
        unreadCountNotifier.value = result.unreadCount;

        return ApiResponse<NotificationPagedResult>(
          success: true,
          message: json['message']?.toString() ?? 'Thành công',
          data: result,
        );
      }

      return ApiResponse<NotificationPagedResult>(
        success: false,
        message: json?['message']?.toString() ?? 'Lỗi khi tải thông báo (${response.statusCode})',
        data: NotificationPagedResult.empty(),
      );
    } catch (e) {
      debugPrint('[NotificationApiService] Error getNotifications: $e');
      return ApiResponse<NotificationPagedResult>(
        success: false,
        message: 'Không thể kết nối đến máy chủ: $e',
        data: NotificationPagedResult.empty(),
      );
    }
  }

  /// Lấy số lượng thông báo chưa đọc: GET /api/notifications/unread-count
  Future<int> getUnreadCount() async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        unreadCountNotifier.value = 0;
        return 0;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.unreadNotificationCount}');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final json = _tryDecodeJson(response);
      if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
        final count = (json['data'] as num?)?.toInt() ?? 0;
        unreadCountNotifier.value = count;
        return count;
      }
    } catch (e) {
      debugPrint('[NotificationApiService] Error getUnreadCount: $e');
    }
    return unreadCountNotifier.value;
  }

  /// Đánh dấu một thông báo là đã đọc: PUT /api/notifications/{id}/read
  Future<bool> markAsRead(int id) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) return false;

      // Optimistic update
      if (unreadCountNotifier.value > 0) {
        unreadCountNotifier.value = unreadCountNotifier.value - 1;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.markNotificationAsRead(id)}');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final json = _tryDecodeJson(response);
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (!isSuccess) {
        // Rollback nếu fail
        getUnreadCount();
      }
      return json?['data'] == true || isSuccess;
    } catch (e) {
      debugPrint('[NotificationApiService] Error markAsRead: $e');
      getUnreadCount();
      return false;
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc: PUT /api/notifications/read-all
  Future<int> markAllAsRead() async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) return 0;

      // Optimistic reset
      unreadCountNotifier.value = 0;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.markAllNotificationsAsRead}');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final json = _tryDecodeJson(response);
      if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
        final affected = (json['data'] as num?)?.toInt() ?? 0;
        return affected;
      }
      getUnreadCount();
      return 0;
    } catch (e) {
      debugPrint('[NotificationApiService] Error markAllAsRead: $e');
      getUnreadCount();
      return 0;
    }
  }

  /// Xóa (lưu trữ) thông báo: DELETE /api/notifications/{id}
  Future<bool> deleteNotification(int id) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) return false;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deleteNotification(id)}');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final json = _tryDecodeJson(response);
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      getUnreadCount();
      return json?['data'] == true || isSuccess;
    } catch (e) {
      debugPrint('[NotificationApiService] Error deleteNotification: $e');
      return false;
    }
  }
}
