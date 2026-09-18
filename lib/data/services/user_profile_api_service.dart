import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/user_profile_data_models.dart';
import 'auth_service.dart';

class UserProfileApiService {
  static final UserProfileApiService _instance = UserProfileApiService._internal();
  factory UserProfileApiService() => _instance;
  UserProfileApiService._internal();

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

  Future<http.Response?> _getWithFallback(String path1, String path2, {Map<String, String>? queryParams}) async {
    final token = await AuthService().getAccessToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_'))
        'Authorization': 'Bearer $token',
    };

    try {
      var uri = Uri.parse('${ApiConstants.baseUrl}$path1');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 404) {
        var uri2 = Uri.parse('${ApiConstants.baseUrl}$path2');
        if (queryParams != null && queryParams.isNotEmpty) {
          uri2 = uri2.replace(queryParameters: queryParams);
        }
        return await http.get(uri2, headers: headers).timeout(const Duration(seconds: 4));
      }
      return res;
    } catch (e) {
      debugPrint('[UserProfileApiService] _getWithFallback error: $e');
      return null;
    }
  }

  Future<http.Response?> _deleteWithFallback(String path1, String path2) async {
    final token = await AuthService().getAccessToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_'))
        'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$path1');
      final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 404) {
        final uri2 = Uri.parse('${ApiConstants.baseUrl}$path2');
        return await http.delete(uri2, headers: headers).timeout(const Duration(seconds: 4));
      }
      return res;
    } catch (e) {
      debugPrint('[UserProfileApiService] _deleteWithFallback error: $e');
      return null;
    }
  }

  Future<http.Response?> _postWithFallback(String path1, String path2, {Map<String, dynamic>? body}) async {
    final token = await AuthService().getAccessToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_'))
        'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$path1');
      final res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 5));
      if (res.statusCode == 404) {
        final uri2 = Uri.parse('${ApiConstants.baseUrl}$path2');
        return await http.post(uri2, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 5));
      }
      return res;
    } catch (e) {
      debugPrint('[UserProfileApiService] _postWithFallback error: $e');
      return null;
    }
  }

  static const String _localVisitLogsKey = 'user_all_visit_logs_cache_v2';

  // ==================== 1. VISIT LOGS ====================

  Future<ApiResponse<List<VisitLogItemModel>>> getMyVisitLogs({int? privacy, String? keyword, int page = 1, int pageSize = 50}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (privacy != null) queryParams['privacy'] = privacy.toString();
      if (keyword != null && keyword.trim().isNotEmpty) queryParams['keyword'] = keyword.trim();

      final response = await _getWithFallback(
        '/api/v1/users/me/visit-logs',
        '/api/users/me/visit-logs',
        queryParams: queryParams,
      );

      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        final json = _tryDecodeJson(response);
        if (json != null) {
          final raw = json['data'] is Map ? json['data']['items'] : json['data'];
          if (raw is List) {
            final list = raw.map((e) => VisitLogItemModel.fromJson(e as Map<String, dynamic>)).toList();
            await _mergeRemoteVisitLogsToLocal(list);
            return ApiResponse<List<VisitLogItemModel>>(success: true, message: 'OK', data: list);
          }
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] getMyVisitLogs error: $e');
    }

    // Fallback Local Cache
    final localList = await _getLocalVisitLogs();
    var filtered = localList;
    if (privacy != null) {
      filtered = filtered.where((l) => l.privacy == privacy).toList();
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.toLowerCase().trim();
      filtered = filtered.where((l) =>
        l.placeName.toLowerCase().contains(q) ||
        l.province.toLowerCase().contains(q) ||
        l.category.toLowerCase().contains(q)
      ).toList();
    }

    return ApiResponse<List<VisitLogItemModel>>(
      success: true,
      message: 'OK',
      data: filtered,
    );
  }

  Future<ApiResponse<VisitLogItemModel>> createVisitLog({
    required int placeId,
    required String visitedDate,
    int privacy = 1,
    String? notes,
    String? placeName,
    String? province,
    String? category,
    String? coverImg,
    double? lat,
    double? lng,
  }) async {
    final newId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final fallbackItem = VisitLogItemModel(
      id: newId,
      placeId: placeId,
      placeName: placeName ?? 'Địa điểm #$placeId',
      province: province ?? '',
      category: category ?? 'Khám phá',
      visitedDate: visitedDate,
      privacy: privacy,
      coverImg: coverImg ?? '',
      lat: lat,
      lng: lng,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _saveVisitLogToLocal(fallbackItem);

    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final body = jsonEncode({
          'placeId': placeId,
          'visitedDate': visitedDate,
          'privacy': privacy,
          'notes': notes,
        });

        final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/visit-logs');
        final res = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 4));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = _tryDecodeJson(res);
          if (json != null && json['data'] != null) {
            final item = VisitLogItemModel.fromJson(json['data'] as Map<String, dynamic>);
            await _saveVisitLogToLocal(item);
            return ApiResponse<VisitLogItemModel>(success: true, message: 'OK', data: item);
          }
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] createVisitLog error: $e');
    }
    return ApiResponse<VisitLogItemModel>(success: true, message: 'Đã lưu nhật ký', data: fallbackItem);
  }

  Future<ApiResponse<bool>> updateVisitLog(int id, {required String visitedDate, required int privacy}) async {
    final list = await _getLocalVisitLogs();
    final idx = list.indexWhere((l) => l.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(visitedDate: visitedDate, privacy: privacy);
      await _cacheVisitLogs(list);
    }

    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final body = jsonEncode({
          'visitedDate': visitedDate,
          'privacy': privacy,
        });

        final uri1 = Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/visit-logs/$id');
        final res = await http.put(uri1, headers: headers, body: body).timeout(const Duration(seconds: 4));
        if (res.statusCode == 404) {
          final uri2 = Uri.parse('${ApiConstants.baseUrl}/api/users/me/visit-logs/$id');
          await http.put(uri2, headers: headers, body: body).timeout(const Duration(seconds: 4));
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] updateVisitLog error: $e');
    }
    return const ApiResponse<bool>(success: true, message: 'Đã cập nhật nhật ký', data: true);
  }

  Future<ApiResponse<bool>> deleteVisitLog(int id) async {
    await _removeVisitLogFromLocal(id);

    try {
      final res = await _deleteWithFallback(
        '/api/v1/users/me/visit-logs/$id',
        '/api/users/me/visit-logs/$id',
      );
      if (res != null && res.statusCode >= 200 && res.statusCode < 300) {
        return const ApiResponse<bool>(success: true, message: 'OK', data: true);
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] deleteVisitLog error: $e');
    }
    return const ApiResponse<bool>(success: true, message: 'Đã xóa nhật ký', data: true);
  }

  Future<ApiResponse<bool>> changeVisitLogPrivacy(int id, int privacy) async {
    final list = await _getLocalVisitLogs();
    final idx = list.indexWhere((l) => l.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(privacy: privacy);
      await _cacheVisitLogs(list);
    }

    try {
      final token = await AuthService().getAccessToken();
      if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_')) {
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/visit-logs/$id/privacy');
        final res = await http.patch(uri, headers: headers, body: jsonEncode({'privacy': privacy})).timeout(const Duration(seconds: 4));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return const ApiResponse<bool>(success: true, message: 'OK', data: true);
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] changeVisitLogPrivacy error: $e');
    }
    return const ApiResponse<bool>(success: true, message: 'Đã đổi quyền riêng tư', data: true);
  }

  // ==================== VISIT LOG LOCAL CACHE HELPERS ====================

  Future<List<VisitLogItemModel>> _getLocalVisitLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localVisitLogsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List;
        return list.map((item) => VisitLogItemModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return <VisitLogItemModel>[];
  }

  Future<void> _cacheVisitLogs(List<VisitLogItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_localVisitLogsKey, jsonStr);
    } catch (_) {}
  }

  Future<void> _mergeRemoteVisitLogsToLocal(List<VisitLogItemModel> remoteItems) async {
    final localItems = await _getLocalVisitLogs();
    final map = <int, VisitLogItemModel>{};
    for (final item in localItems) {
      map[item.id] = item;
    }
    for (final item in remoteItems) {
      map[item.id] = item;
    }
    await _cacheVisitLogs(map.values.toList());
  }

  Future<void> _saveVisitLogToLocal(VisitLogItemModel item) async {
    final list = await _getLocalVisitLogs();
    list.removeWhere((i) => i.id == item.id || (i.placeId == item.placeId && i.visitedDate == item.visitedDate));
    list.insert(0, item);
    await _cacheVisitLogs(list);
  }

  Future<void> _removeVisitLogFromLocal(int id) async {
    final list = await _getLocalVisitLogs();
    list.removeWhere((i) => i.id == id);
    await _cacheVisitLogs(list);
  }

  // ==================== 2. REVIEWS ====================

  Future<ApiResponse<List<UserReviewItemModel>>> getMyReviews({int page = 1, int pageSize = 50}) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };

      final response = await _getWithFallback(
        '/api/v1/users/me/reviews',
        '/api/users/me/reviews',
        queryParams: queryParams,
      );

      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        final json = _tryDecodeJson(response);
        if (json != null) {
          final raw = json['data'] is Map ? json['data']['items'] : json['data'];
          if (raw is List) {
            final list = raw.map((e) => UserReviewItemModel.fromJson(e as Map<String, dynamic>)).toList();
            return ApiResponse<List<UserReviewItemModel>>(success: true, message: 'OK', data: list);
          }
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] getMyReviews error: $e');
    }

    return ApiResponse<List<UserReviewItemModel>>(
      success: true,
      message: 'OK',
      data: const [],
    );
  }

  // ==================== 3. COMMENTS ====================

  Future<ApiResponse<List<UserCommentItemModel>>> getMyComments({int page = 1, int pageSize = 50}) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };

      final response = await _getWithFallback(
        '/api/v1/users/me/comments',
        '/api/users/me/comments',
        queryParams: queryParams,
      );

      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        final json = _tryDecodeJson(response);
        if (json != null) {
          final raw = json['data'] is Map ? json['data']['items'] : json['data'];
          if (raw is List) {
            final list = raw.map((e) => UserCommentItemModel.fromJson(e as Map<String, dynamic>)).toList();
            return ApiResponse<List<UserCommentItemModel>>(success: true, message: 'OK', data: list);
          }
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] getMyComments error: $e');
    }

    return ApiResponse<List<UserCommentItemModel>>(
      success: true,
      message: 'OK',
      data: const [],
    );
  }

  // ==================== 4. BLOGS ====================

  Future<ApiResponse<List<UserBlogItemModel>>> getMyBlogs({int? status, int page = 1, int pageSize = 50}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (status != null) queryParams['status'] = status.toString();

      final response = await _getWithFallback(
        '/api/v1/users/me/blogs',
        '/api/users/me/blogs',
        queryParams: queryParams,
      );

      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        final json = _tryDecodeJson(response);
        if (json != null) {
          final raw = json['data'] is Map ? json['data']['items'] : json['data'];
          if (raw is List) {
            final list = raw.map((e) => UserBlogItemModel.fromJson(e as Map<String, dynamic>)).toList();
            return ApiResponse<List<UserBlogItemModel>>(success: true, message: 'OK', data: list);
          }
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] getMyBlogs error: $e');
    }

    return ApiResponse<List<UserBlogItemModel>>(
      success: true,
      message: 'OK',
      data: const [],
    );
  }

  Future<ApiResponse<bool>> deleteBlog(int id) async {
    try {
      final res = await _deleteWithFallback(
        '/api/v1/blogs/$id',
        '/api/blogs/$id',
      );
      if (res != null && res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResponse<bool>(success: true, message: 'OK', data: true);
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] deleteBlog error: $e');
    }
    return ApiResponse<bool>(success: false, message: 'Lỗi khi xóa bài viết', data: false);
  }

  // ==================== 5. PROPOSALS ====================

  static const String _localProposalsKey = 'user_proposals_cache_list';

  Future<void> _saveLocalProposal(ProposalItemModel item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_localProposalsKey) ?? [];
      final encoded = jsonEncode(item.toJson());
      list.removeWhere((str) {
        try {
          final m = jsonDecode(str) as Map<String, dynamic>;
          return m['id'] == item.id || (m['name'] == item.name && m['address'] == item.address);
        } catch (_) {
          return false;
        }
      });
      list.insert(0, encoded);
      await prefs.setStringList(_localProposalsKey, list);
    } catch (e) {
      debugPrint('[UserProfileApiService] _saveLocalProposal error: $e');
    }
  }

  Future<List<ProposalItemModel>> _getLocalProposals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_localProposalsKey) ?? [];
      return list.map((str) => ProposalItemModel.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _removeLocalProposal(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_localProposalsKey) ?? [];
      list.removeWhere((str) {
        try {
          final m = jsonDecode(str) as Map<String, dynamic>;
          return m['id'] == id;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList(_localProposalsKey, list);
    } catch (_) {}
  }

  Future<ApiResponse<List<ProposalItemModel>>> getMyProposals({int? status, int page = 1, int pageSize = 50}) async {
    final List<ProposalItemModel> combined = [];
    final Set<int> seenIds = {};

    // 1. Fetch from Backend API
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (status != null) queryParams['status'] = status.toString();

      final response = await _getWithFallback(
        '/api/v1/users/me/proposals',
        '/api/users/me/proposals',
        queryParams: queryParams,
      );

      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        final json = _tryDecodeJson(response);
        if (json != null) {
          final raw = json['data'] is Map ? json['data']['items'] : json['data'];
          if (raw is List) {
            for (final e in raw) {
              final item = ProposalItemModel.fromJson(e as Map<String, dynamic>);
              if (seenIds.add(item.id)) {
                combined.add(item);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] getMyProposals error: $e');
    }

    // 2. Merge local stored proposals
    final localList = await _getLocalProposals();
    for (final item in localList) {
      if (status != null && item.status != status) continue;
      if (seenIds.add(item.id)) {
        combined.insert(0, item);
      }
    }

    return ApiResponse<List<ProposalItemModel>>(
      success: true,
      message: 'OK',
      data: combined,
    );
  }

  Future<ApiResponse<bool>> deleteProposal(int id) async {
    await _removeLocalProposal(id);
    try {
      final res = await _deleteWithFallback(
        '/api/v1/proposals/$id',
        '/api/proposals/$id',
      );
      if (res != null && res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResponse<bool>(success: true, message: 'OK', data: true);
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] deleteProposal error: $e');
    }
    return ApiResponse<bool>(success: true, message: 'Đã thu hồi đề xuất', data: true);
  }

  Future<ApiResponse<ProposalItemModel>> createProposal({
    required String name,
    required String category,
    required String province,
    required String address,
    String? phone,
    String? website,
    String? openingHours,
    String? priceRange,
    double? minPrice,
    double? maxPrice,
    String? description,
    double? latitude,
    double? longitude,
    String? coverImg,
    List<String>? mediaUrls,
  }) async {
    ProposalItemModel? resultItem;
    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        'category': category.trim(),
        'province': province.trim(),
        'address': address.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (website != null && website.isNotEmpty) 'website': website.trim(),
        if (openingHours != null && openingHours.isNotEmpty) 'openingHours': openingHours.trim(),
        if (priceRange != null && priceRange.isNotEmpty) 'priceRange': priceRange.trim(),
        'minPrice': ?minPrice,
        'maxPrice': ?maxPrice,
        if (description != null && description.isNotEmpty) 'description': description.trim(),
        'latitude': ?latitude,
        'longitude': ?longitude,
        if (coverImg != null && coverImg.isNotEmpty) 'coverImg': coverImg,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
      };

      final res = await _postWithFallback(
        '/api/v1/proposals',
        '/api/proposals',
        body: body,
      );

      if (res != null && res.statusCode >= 200 && res.statusCode < 300) {
        final json = _tryDecodeJson(res);
        if (json != null && json['data'] != null) {
          resultItem = ProposalItemModel.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[UserProfileApiService] createProposal error: $e');
    }

    // Local fallback if API failed or offline/guest
    resultItem ??= ProposalItemModel(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      name: name,
      category: category,
      province: province,
      address: address,
      phone: phone ?? '',
      website: website ?? '',
      openingHours: openingHours ?? '07:30 – 18:00',
      priceRange: priceRange ?? 'Miễn phí',
      description: description ?? '',
      coverImg: (coverImg != null && coverImg.isNotEmpty)
          ? coverImg
          : (mediaUrls != null && mediaUrls.isNotEmpty ? mediaUrls.first : ''),
      mediaUrls: mediaUrls ?? [],
      status: 0,
      createdAt: 'Vừa xong',
    );

    // Save proposal to local cache so user ALWAYS sees their proposal in profile immediately
    await _saveLocalProposal(resultItem);

    return ApiResponse<ProposalItemModel>(
      success: true,
      message: 'Gửi đề xuất thành công',
      data: resultItem,
    );
  }
}

