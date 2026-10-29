import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/favorite_model.dart';
import 'auth_service.dart';

class FavoriteApiService {
  static final FavoriteApiService _instance = FavoriteApiService._internal();
  factory FavoriteApiService() => _instance;
  FavoriteApiService._internal();

  /// Global notifier để thông báo cho toàn bộ ứng dụng (Profile, Home, v.v.) khi có thay đổi yêu thích
  static final ValueNotifier<int> favoritesNotifier = ValueNotifier<int>(0);

  static void notifyFavoritesChanged() {
    favoritesNotifier.value++;
  }

  static const String _localFavoritesBaseKey = 'user_all_favorites_cache_v3';

  Future<String> _getLocalFavoritesKey() async {
    return await AuthService().getScopedKey(_localFavoritesBaseKey);
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

  /// Lấy danh sách yêu thích từ Backend API (/api/users/me/favorites)
  Future<ApiResponse<FavoritePagedResultModel>> getFavorites({
    int? targetType,
    String? keyword,
    String? sortBy,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final queryParams = <String, String>{
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        };
        if (targetType != null && targetType > 0) {
          queryParams['targetType'] = targetType.toString();
        }
        if (keyword != null && keyword.trim().isNotEmpty) {
          queryParams['keyword'] = keyword.trim();
        }
        if (sortBy != null && sortBy.trim().isNotEmpty) {
          queryParams['sortBy'] = sortBy.trim();
        }

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };

        final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}')
            .replace(queryParameters: queryParams);

        debugPrint('[FavoriteApiService] Calling getFavorites: $uri');

        final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
        debugPrint('[FavoriteApiService] getFavorites status: ${response.statusCode}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = _tryDecodeJson(response);
          if (json != null) {
            final dataJson = json['data'] ?? json;
            if (dataJson is Map<String, dynamic>) {
              final result = FavoritePagedResultModel.fromJson(dataJson);
              
              // Đồng bộ danh sách thật từ Database vào Local Cache và hợp nhất dữ liệu
              if (targetType == null || targetType == 0) {
                final merged = await _syncAndMergeRemoteFavorites(result.items);
                return ApiResponse<FavoritePagedResultModel>(
                  success: true,
                  message: json['message'] as String? ?? 'Tải danh sách yêu thích thành công',
                  data: result.copyWith(items: merged, totalCount: merged.length),
                );
              }

              return ApiResponse<FavoritePagedResultModel>(
                success: true,
                message: json['message'] as String? ?? 'Tải danh sách yêu thích thành công',
                data: result,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FavoriteApiService] getFavorites remote error: $e');
    }

    // Fallback: Lấy từ Local Cache nếu offline hoặc chưa đồng bộ
    final localItems = await _getLocalFavorites();
    var filtered = localItems;

    if (targetType != null && targetType > 0) {
      filtered = filtered.where((item) => item.targetType == targetType).toList();
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final query = keyword.toLowerCase().trim();
      filtered = filtered.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.subtitle.toLowerCase().contains(query) ||
            item.categoryTag.toLowerCase().contains(query);
      }).toList();
    }

    if (sortBy == 'rating') {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (sortBy == 'name') {
      filtered.sort((a, b) => a.title.compareTo(b.title));
    }

    return ApiResponse<FavoritePagedResultModel>(
      success: true,
      message: 'Tải danh sách đã lưu thành công',
      data: FavoritePagedResultModel(
        items: filtered,
        page: page,
        pageSize: pageSize,
        totalCount: filtered.length,
        totalPages: 1,
      ),
    );
  }

  /// Thêm một mục vào danh sách yêu thích (POST /api/users/me/favorites/{targetType}/{targetId})
  Future<ApiResponse<bool>> addFavorite({
    required int targetType,
    required int targetId,
    String? title,
    String? subtitle,
    String? coverImg,
    String? categoryTag,
    double? rating,
    int? reviewCount,
    String? price,
    List<String>? mediaUrls,
  }) async {
    final newItem = FavoriteItemModel(
      id: targetId,
      targetId: targetId,
      targetType: targetType,
      title: title != null && title.isNotEmpty ? title : 'Địa điểm đã lưu #$targetId',
      subtitle: subtitle ?? '',
      coverImg: coverImg ?? '',
      categoryTag: categoryTag ?? 'Khám phá',
      rating: rating ?? 5.0,
      reviewCount: reviewCount ?? 0,
      price: price,
      savedDate: DateTime.now().toIso8601String(),
      mediaUrls: mediaUrls ?? (coverImg != null && coverImg.isNotEmpty ? [coverImg] : []),
    );

    // Lưu local cache ngay lập tức để người dùng có phản hồi tức thì trên UI
    await _saveItemToLocal(newItem);
    notifyFavoritesChanged();

    final token = await AuthService().getAccessToken();
    if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'targetType': targetType,
        'targetId': targetId,
      });

      try {
        final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}/$targetType/$targetId');
        debugPrint('[FavoriteApiService] Calling addFavorite: $uri with body: $body');
        final res = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 8));
        debugPrint('[FavoriteApiService] addFavorite response: ${res.statusCode} - ${res.body}');

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = _tryDecodeJson(res);
          return ApiResponse<bool>(
            success: true,
            message: json?['message']?.toString() ?? 'Đã lưu vào danh sách yêu thích trong database.',
            data: true,
          );
        } else if (res.statusCode == 401) {
          return const ApiResponse<bool>(
            success: false,
            message: 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
            data: false,
          );
        }
      } catch (e) {
        debugPrint('[FavoriteApiService] addFavorite remote sync error: $e');
      }
    }

    return const ApiResponse<bool>(
      success: true,
      message: 'Đã lưu vào danh sách yêu thích thành công.',
      data: true,
    );
  }

  /// Xóa khỏi danh sách yêu thích (DELETE /api/users/me/favorites/{targetType}/{targetId})
  Future<ApiResponse<bool>> removeFavorite({
    required int targetType,
    required int targetId,
  }) async {
    // Xóa khỏi local cache ngay lập tức
    await _removeItemFromLocal(targetType, targetId);
    notifyFavoritesChanged();

    final token = await AuthService().getAccessToken();
    if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      try {
        final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}/$targetType/$targetId');
        debugPrint('[FavoriteApiService] Calling removeFavorite: $uri');
        final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 8));
        debugPrint('[FavoriteApiService] removeFavorite response: ${res.statusCode} - ${res.body}');

        if (targetType == 1) {
          try {
            final placeSaveUri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$targetId/save');
            await http.delete(placeSaveUri, headers: headers).timeout(const Duration(seconds: 5));
          } catch (_) {}
        }

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = _tryDecodeJson(res);
          return ApiResponse<bool>(
            success: true,
            message: json?['message']?.toString() ?? 'Đã xóa địa điểm khỏi bảng Favorite trong database.',
            data: true,
          );
        }
      } catch (e) {
        debugPrint('[FavoriteApiService] removeFavorite remote sync error: $e');
      }
    }

    return const ApiResponse<bool>(
      success: true,
      message: 'Đã bỏ lưu khỏi danh sách yêu thích.',
      data: true,
    );
  }

  /// Kiểm tra mục đã được lưu chưa
  Future<bool> isFavorite(int targetType, int targetId) async {
    final token = await AuthService().getAccessToken();
    if (token != null && token.isNotEmpty) {
      final res = await getFavorites(targetType: targetType, pageSize: 100);
      if (res.success && res.data != null) {
        return res.data!.items.any((item) => item.targetType == targetType && item.targetId == targetId);
      }
    }
    final list = await _getLocalFavorites();
    return list.any((item) => item.targetType == targetType && item.targetId == targetId);
  }

  /// Lấy danh sách ID các địa điểm đã yêu thích
  Future<Set<int>> getFavoritePlaceIds() async {
    final token = await AuthService().getAccessToken();
    if (token != null && token.isNotEmpty) {
      final res = await getFavorites(targetType: 1, pageSize: 100);
      if (res.success && res.data != null) {
        return res.data!.items.where((item) => item.targetType == 1).map((item) => item.targetId).toSet();
      }
    }
    final list = await _getLocalFavorites();
    return list.where((item) => item.targetType == 1).map((item) => item.targetId).toSet();
  }

  /// Lấy số lượng thống kê theo từng danh mục
  Future<Map<FavoriteTargetType, int>> getFavoriteCounts() async {
    final res = await getFavorites(pageSize: 100);
    final list = res.data?.items ?? await _getLocalFavorites();
    return {
      FavoriteTargetType.all: list.length,
      FavoriteTargetType.place: list.where((f) => f.targetType == 1).length,
      FavoriteTargetType.food: list.where((f) => f.targetType == 2).length,
      FavoriteTargetType.itinerary: list.where((f) => f.targetType == 3).length,
      FavoriteTargetType.blog: list.where((f) => f.targetType == 4).length,
    };
  }

  // ==================== LOCAL STORAGE HELPERS ====================

  Future<List<FavoriteItemModel>> _getLocalFavorites() async {
    try {
      final key = await _getLocalFavoritesKey();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List;
        return list.map((item) => FavoriteItemModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    return <FavoriteItemModel>[];
  }

  Future<void> _cacheFavorites(List<FavoriteItemModel> items) async {
    try {
      final key = await _getLocalFavoritesKey();
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(key, jsonStr);
    } catch (_) {}
  }

  Future<List<FavoriteItemModel>> _syncAndMergeRemoteFavorites(List<FavoriteItemModel> remoteItems) async {
    final localList = await _getLocalFavorites();
    final Map<String, FavoriteItemModel> map = {};
    for (final loc in localList) {
      map['${loc.targetType}_${loc.targetId}'] = loc;
    }
    for (final rem in remoteItems) {
      final key = '${rem.targetType}_${rem.targetId}';
      if (map.containsKey(key)) {
        final loc = map[key]!;
        final mergedTitle = (rem.title.isNotEmpty && !rem.title.contains('#'))
            ? rem.title
            : (loc.title.isNotEmpty ? loc.title : rem.title);
        final mergedCover = rem.coverImg.isNotEmpty ? rem.coverImg : loc.coverImg;
        final mergedSub = rem.subtitle.isNotEmpty ? rem.subtitle : loc.subtitle;
        map[key] = rem.copyWith(title: mergedTitle, coverImg: mergedCover, subtitle: mergedSub);
      } else {
        map[key] = rem;
      }
    }
    final mergedList = map.values.toList();
    await _cacheFavorites(mergedList);
    return mergedList;
  }

  Future<void> _saveItemToLocal(FavoriteItemModel item) async {
    final list = await _getLocalFavorites();
    list.removeWhere((i) => i.targetType == item.targetType && i.targetId == item.targetId);
    list.insert(0, item);
    await _cacheFavorites(list);
  }

  Future<void> _removeItemFromLocal(int targetType, int targetId) async {
    final list = await _getLocalFavorites();
    list.removeWhere((i) => i.targetType == targetType && i.targetId == targetId);
    await _cacheFavorites(list);
  }
}
