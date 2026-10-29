import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/ranking_model.dart';
import 'auth_service.dart';

class RankingApiService {
  static final RankingApiService _instance = RankingApiService._internal();
  factory RankingApiService() => _instance;
  RankingApiService._internal();

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

  Future<Map<String, String>> _buildHeaders({bool hasBody = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (hasBody) {
      headers['Content-Type'] = 'application/json';
    }
    final token = await AuthService().getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET /api/rankings/overview
  Future<ApiResponse<RankingOverviewData>> getRankingOverview() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.rankingOverview}');
      final headers = await _buildHeaders();

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      final json = _tryDecodeJson(res);

      if (res.statusCode >= 200 && res.statusCode < 300 && json != null) {
        final dataJson = json['data'] as Map<String, dynamic>? ?? json;
        return ApiResponse<RankingOverviewData>(
          success: true,
          message: json['message']?.toString() ?? 'Thành công',
          data: RankingOverviewData.fromJson(dataJson),
        );
      }

      final errorMsg = json?['message']?.toString() ?? 'Lỗi tải trang tổng quan bảng xếp hạng (${res.statusCode})';
      return ApiResponse<RankingOverviewData>(
        success: false,
        message: errorMsg,
      );
    } catch (e) {
      return ApiResponse<RankingOverviewData>(
        success: false,
        message: 'Không thể kết nối đến máy chủ: $e',
      );
    }
  }

  /// GET /api/rankings/detail?type=...&placeTypeId=...&provinceId=...&categoryId=...&page=...&pageSize=...
  Future<ApiResponse<RankingDetailViewData>> getRankingDetail({
    String type = 'place_type',
    int? placeTypeId,
    int? provinceId,
    int? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'type': type,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (placeTypeId != null) {
        queryParams['placeTypeId'] = placeTypeId.toString();
      }
      if (provinceId != null) {
        queryParams['provinceId'] = provinceId.toString();
      }
      if (categoryId != null) {
        queryParams['categoryId'] = categoryId.toString();
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.rankingDetail}')
          .replace(queryParameters: queryParams);
      final headers = await _buildHeaders();

      debugPrint('[RankingApiService] Calling: $uri');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      debugPrint('[RankingApiService] Response (${res.statusCode}): ${res.body}');
      final json = _tryDecodeJson(res);

      if (res.statusCode >= 200 && res.statusCode < 300 && json != null) {
        final dataJson = json['data'] as Map<String, dynamic>? ?? json;
        return ApiResponse<RankingDetailViewData>(
          success: true,
          message: json['message']?.toString() ?? 'Thành công',
          data: RankingDetailViewData.fromJson(dataJson),
        );
      }

      String errorMsg = json?['message']?.toString() ?? 'Lỗi tải dữ liệu chi tiết xếp hạng (${res.statusCode})';
      if (json != null && json['errors'] is List && (json['errors'] as List).isNotEmpty) {
        final errDetails = (json['errors'] as List)
            .map((e) => e is Map ? '${e['field'] ?? ''}: ${e['message'] ?? ''}' : e.toString())
            .join('; ');
        errorMsg += ' ($errDetails)';
      }

      return ApiResponse<RankingDetailViewData>(
        success: false,
        message: errorMsg,
      );
    } catch (e) {
      return ApiResponse<RankingDetailViewData>(
        success: false,
        message: 'Không thể kết nối đến máy chủ: $e',
      );
    }
  }
}
