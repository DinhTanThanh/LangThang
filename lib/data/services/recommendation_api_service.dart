import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/place_model.dart';
import '../models/food_model.dart';
import 'auth_service.dart';

class PersonalizedRecommendationsResult {
  final List<PlaceModel> items;
  final bool isPersonalized;
  final int count;

  const PersonalizedRecommendationsResult({
    required this.items,
    required this.isPersonalized,
    required this.count,
  });

  factory PersonalizedRecommendationsResult.empty() {
    return const PersonalizedRecommendationsResult(
      items: [],
      isPersonalized: false,
      count: 0,
    );
  }
}

class RecommendationApiService {
  static final RecommendationApiService _instance = RecommendationApiService._internal();
  factory RecommendationApiService() => _instance;
  RecommendationApiService._internal();

  List<String> _getCandidateBaseUrls() {
    final List<String> list = [ApiConstants.baseUrl];
    if (ApiConstants.baseUrl.contains('localhost:') ||
        ApiConstants.baseUrl.contains('10.0.2.2:') ||
        ApiConstants.baseUrl.contains('127.0.0.1:')) {
      for (final port in [5000, 5021, 7027, 29036, 7001]) {
        final alt = ApiConstants.baseUrl.replaceAll(RegExp(r':\d+'), ':$port');
        if (!list.contains(alt)) list.add(alt);
      }
    }
    return list;
  }

  /// GET /api/recommendations/places/for-you
  /// Lấy danh sách địa điểm gợi ý cá nhân hóa (KNN) hoặc cold-start fallback
  Future<PersonalizedRecommendationsResult> getPersonalizedPlaces({
    int topK = 12,
    int? provinceId,
    int? categoryId,
  }) async {
    final token = await AuthService().getToken();
    final hasValidToken = token != null && token.isNotEmpty && !token.startsWith('google_session_token_');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (hasValidToken) 'Authorization': 'Bearer $token',
    };

    final candidateUrls = _getCandidateBaseUrls();

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base${ApiConstants.personalizedPlaces}').replace(
          queryParameters: {
            'topK': topK.toString(),
            if (provinceId != null) 'provinceId': provinceId.toString(),
            if (categoryId != null) 'categoryId': categoryId.toString(),
          },
        );

        final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            final data = decoded['data'] is Map<String, dynamic> ? decoded['data'] as Map<String, dynamic> : null;
            if (data != null) {
              final isPersonalized = (data['isPersonalized'] == true) || hasValidToken;
              final rawItems = data['items'] as List<dynamic>? ?? [];

              final items = rawItems
                  .whereType<Map<String, dynamic>>()
                  .map((json) => PlaceModel.fromJson(json))
                  .toList();

              if (items.isNotEmpty) {
                return PersonalizedRecommendationsResult(
                  items: items,
                  isPersonalized: isPersonalized,
                  count: items.length,
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[RecommendationApiService] getPersonalizedPlaces attempt failed on $base: $e');
      }
    }

    return PersonalizedRecommendationsResult.empty();
  }

  /// GET /api/recommendations/trips/{tripId}/suggested-places
  /// Đề xuất địa điểm thông minh theo gu cả đoàn (KNN)
  Future<List<PlaceModel>> getTripPlaceSuggestions(
    int tripId, {
    int topK = 12,
    int? provinceId,
  }) async {
    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tripSuggestions(tripId)}').replace(
        queryParameters: {
          'topK': topK.toString(),
          if (provinceId != null) 'provinceId': provinceId.toString(),
        },
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final rawItems = decoded['data'] as List<dynamic>? ?? [];
          final items = rawItems
              .whereType<Map<String, dynamic>>()
              .map((json) => PlaceModel.fromJson(json))
              .toList();

          if (items.isNotEmpty) {
            return items;
          }
        }
      }
    } catch (e) {
      debugPrint('[RecommendationApiService] getTripPlaceSuggestions error: $e');
    }

    // Fallback: gợi ý cá nhân hóa nếu trip mới tạo hoặc chưa đủ dữ liệu
    try {
      final fallbackResult = await getPersonalizedPlaces(topK: topK, provinceId: provinceId);
      if (fallbackResult.items.isNotEmpty) {
        return fallbackResult.items;
      }
    } catch (_) {}

    return [];
  }

  /// GET /api/recommendations/foods/for-you
  /// Lấy danh sách món ngon đặc sản đề xuất theo gu ẩm thực
  Future<List<FoodModel>> getRecommendedFoods({int topK = 12}) async {
    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.recommendedFoods}').replace(
        queryParameters: {
          'topK': topK.toString(),
        },
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final rawItems = decoded['data'] as List<dynamic>? ?? [];
          final items = rawItems
              .whereType<Map<String, dynamic>>()
              .map((json) => FoodModel.fromJson(json))
              .toList();

          if (items.isNotEmpty) {
            return items;
          }
        }
      }
    } catch (e) {
      debugPrint('[RecommendationApiService] getRecommendedFoods error: $e');
    }

    return _fallbackRecommendedFoods;
  }

  static const List<FoodModel> _fallbackRecommendedFoods = [
    FoodModel(
      id: '1',
      name: 'Chả Cá Lã Vọng',
      description: 'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.',
      imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop',
      suggestedPlaces: [
        FoodSuggestedPlace(
          name: 'Đặc sản ẩm thực nổi bật',
          address: 'Địa điểm ẩm thực uy tín',
          rating: 4.8,
        ),
      ],
    ),
    FoodModel(
      id: '2',
      name: 'Cà Phê Trứng Hà Nội',
      description: 'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.',
      imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&auto=format&fit=crop',
      suggestedPlaces: [
        FoodSuggestedPlace(
          name: 'Đặc sản ẩm thực nổi bật',
          address: 'Địa điểm ẩm thực uy tín',
          rating: 4.8,
        ),
      ],
    ),
    FoodModel(
      id: '3',
      name: 'Bánh Đa Cua Hải Phòng',
      description: 'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.',
      imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop',
      suggestedPlaces: [
        FoodSuggestedPlace(
          name: 'Đặc sản ẩm thực nổi bật',
          address: 'Địa điểm ẩm thực uy tín',
          rating: 4.8,
        ),
      ],
    ),
    FoodModel(
      id: '4',
      name: 'Bánh Mì Cay Hải Phòng',
      description: 'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.',
      imageUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&auto=format&fit=crop',
      suggestedPlaces: [
        FoodSuggestedPlace(
          name: 'Đặc sản ẩm thực nổi bật',
          address: 'Địa điểm ẩm thực uy tín',
          rating: 4.8,
        ),
      ],
    ),
  ];
}
