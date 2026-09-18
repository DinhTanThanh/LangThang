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

  static const String _localFavoritesKey = 'user_all_favorites_cache_v2';

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

  /// Lấy danh sách yêu thích từ Backend API hoặc Cache Local
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

        var uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/favorites')
            .replace(queryParameters: queryParams);

        debugPrint('[FavoriteApiService] Calling: $uri');

        var response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 3));
        if (response.statusCode == 404) {
          final uri2 = Uri.parse('${ApiConstants.baseUrl}/api/users/me/favorites')
              .replace(queryParameters: queryParams);
          response = await http.get(uri2, headers: headers).timeout(const Duration(seconds: 3));
        }

        debugPrint('[FavoriteApiService] Status code: ${response.statusCode}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = _tryDecodeJson(response);
          if (json != null) {
            final dataJson = json['data'] ?? json;
            if (dataJson is Map<String, dynamic>) {
              final result = FavoritePagedResultModel.fromJson(dataJson);
              if (result.items.isNotEmpty) {
                // Merge vào cache local để offline vẫn còn và không bị ghi đè mất
                await _mergeRemoteFavoritesToLocal(result.items);
                return ApiResponse<FavoritePagedResultModel>(
                  success: true,
                  message: json['message'] as String? ?? 'Tải danh sách yêu thích thành công',
                  data: result,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FavoriteApiService] getFavorites remote error: $e');
    }

    // Fallback: Lấy từ Local Cache
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

  /// Thêm một mục vào danh sách yêu thích
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
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      targetId: targetId,
      targetType: targetType,
      title: title != null && title.isNotEmpty ? title : 'Địa điểm đã lưu #$targetId',
      subtitle: subtitle ?? '',
      coverImg: coverImg ?? '',
      categoryTag: categoryTag ?? 'Khám phá',
      rating: rating ?? 5.0,
      reviewCount: reviewCount ?? 0,
      price: price,
      savedDate: 'Hôm nay',
      mediaUrls: mediaUrls ?? (coverImg != null && coverImg.isNotEmpty ? [coverImg] : []),
    );

    await _saveItemToLocal(newItem);

    try {
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

        final uri1 = Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/favorites');
        final res = await http.post(uri1, headers: headers, body: body).timeout(const Duration(seconds: 3));
        if (res.statusCode == 404) {
          final uri2 = Uri.parse('${ApiConstants.baseUrl}/api/users/me/favorites');
          await http.post(uri2, headers: headers, body: body).timeout(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('[FavoriteApiService] addFavorite remote error: $e');
    }

    return const ApiResponse<bool>(
      success: true,
      message: 'Đã lưu vào danh sách yêu thích',
      data: true,
    );
  }

  /// Xóa khỏi danh sách yêu thích
  Future<ApiResponse<bool>> removeFavorite({
    required int targetType,
    required int targetId,
  }) async {
    await _removeItemFromLocal(targetType, targetId);

    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final uri1 = Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/favorites/$targetType/$targetId');
        final res = await http.delete(uri1, headers: headers).timeout(const Duration(seconds: 3));
        if (res.statusCode == 404) {
          final uri2 = Uri.parse('${ApiConstants.baseUrl}/api/users/me/favorites/$targetType/$targetId');
          await http.delete(uri2, headers: headers).timeout(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('[FavoriteApiService] removeFavorite remote error: $e');
    }

    return const ApiResponse<bool>(
      success: true,
      message: 'Đã bỏ lưu khỏi danh sách yêu thích',
      data: true,
    );
  }

  /// Kiểm tra mục đã được lưu chưa
  Future<bool> isFavorite(int targetType, int targetId) async {
    final list = await _getLocalFavorites();
    return list.any((item) => item.targetType == targetType && item.targetId == targetId);
  }

  /// Lấy danh sách ID các địa điểm đã yêu thích
  Future<Set<int>> getFavoritePlaceIds() async {
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
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localFavoritesKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List;
        return list.map((item) => FavoriteItemModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    return <FavoriteItemModel>[];
  }

  Future<void> _cacheFavorites(List<FavoriteItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_localFavoritesKey, jsonStr);
    } catch (_) {}
  }

  Future<void> _mergeRemoteFavoritesToLocal(List<FavoriteItemModel> remoteItems) async {
    final localItems = await _getLocalFavorites();
    final map = <String, FavoriteItemModel>{};
    for (final item in localItems) {
      map['${item.targetType}_${item.targetId}'] = item;
    }
    for (final item in remoteItems) {
      map['${item.targetType}_${item.targetId}'] = item;
    }
    await _cacheFavorites(map.values.toList());
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
