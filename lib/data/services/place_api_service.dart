import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/place_filter_dto.dart';
import '../models/place_model.dart';
import '../mock/mock_data.dart';

class PlaceApiService {
  static final PlaceApiService _instance = PlaceApiService._internal();
  factory PlaceApiService() => _instance;
  PlaceApiService._internal();

  /// GET /api/places/filter-options
  Future<ApiResponse<PlaceFilterOptionsDto>> getFilterOptions() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.placeFilterOptions}');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApiResponse<PlaceFilterOptionsDto>.fromJson(
          json,
          (data) => PlaceFilterOptionsDto.fromJson(data as Map<String, dynamic>),
        );
      }
    } catch (e) {
      // Fallback to local default options when offline or server unreachable
    }

    // Default fallback options matching backend
    return ApiResponse<PlaceFilterOptionsDto>(
      success: true,
      message: 'Default Filter Options',
      data: PlaceFilterOptionsDto(
        categories: [
          const LookupItemDto(id: 1, name: 'Thiên nhiên & Cảnh quan'),
          const LookupItemDto(id: 2, name: 'Di tích & Lịch sử'),
          const LookupItemDto(id: 3, name: 'Ẩm thực & Cafe'),
          const LookupItemDto(id: 4, name: 'Vui chơi & Giải trí'),
          const LookupItemDto(id: 5, name: 'Văn hóa & Nghệ thuật'),
          const LookupItemDto(id: 6, name: 'Nghỉ dưỡng & Resort'),
        ],
        regions: [
          const RegionLookupDto(
            id: 1,
            name: 'Miền Bắc',
            provinces: [
              LookupItemDto(id: 1, name: 'Hà Nội'),
              LookupItemDto(id: 2, name: 'Hải Phòng'),
              LookupItemDto(id: 3, name: 'Quảng Ninh'),
              LookupItemDto(id: 4, name: 'Ninh Bình'),
              LookupItemDto(id: 5, name: 'Lào Cai / Sa Pa'),
              LookupItemDto(id: 6, name: 'Hà Giang'),
              LookupItemDto(id: 7, name: 'Cao Bằng'),
            ],
          ),
          const RegionLookupDto(
            id: 2,
            name: 'Miền Trung',
            provinces: [
              LookupItemDto(id: 8, name: 'Đà Nẵng'),
              LookupItemDto(id: 9, name: 'Thừa Thiên Huế'),
              LookupItemDto(id: 10, name: 'Quảng Nam / Hội An'),
              LookupItemDto(id: 11, name: 'Khánh Hòa / Nha Trang'),
              LookupItemDto(id: 12, name: 'Lâm Đồng / Đà Lạt'),
              LookupItemDto(id: 13, name: 'Bình Định / Quy Nhơn'),
              LookupItemDto(id: 14, name: 'Quảng Bình'),
            ],
          ),
          const RegionLookupDto(
            id: 3,
            name: 'Miền Nam',
            provinces: [
              LookupItemDto(id: 15, name: 'TP. Hồ Chí Minh'),
              LookupItemDto(id: 16, name: 'Kiên Giang / Phú Quốc'),
              LookupItemDto(id: 17, name: 'Bà Rịa - Vũng Tàu'),
              LookupItemDto(id: 18, name: 'Cần Thơ'),
              LookupItemDto(id: 19, name: 'Tây Ninh'),
              LookupItemDto(id: 20, name: 'An Giang'),
            ],
          ),
        ],
      ),
    );
  }

  /// GET /api/places
  Future<ApiResponse<List<PlaceModel>>> searchPlaces(PlaceFilterParams params) async {
    try {
      final queryParams = params.toQueryParameters();
      final baseUri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}');
      final uri = queryParams.isEmpty
          ? baseUri
          : baseUri.replace(queryParameters: queryParams);

      debugPrint('[PlaceApiService] Calling: $uri');

      final response = await http
          .get(uri, headers: {
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 8));

      debugPrint('[PlaceApiService] Response code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final places = decoded
              .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
              .toList();
          debugPrint('[PlaceApiService] Loaded ${places.length} places (raw list)');
          return ApiResponse<List<PlaceModel>>(
            success: true,
            data: places,
            meta: PaginationMeta(
              page: params.page,
              size: params.pageSize,
              totalElements: places.length,
              totalPages: 1,
            ),
          );
        } else if (decoded is Map<String, dynamic>) {
          final parsed = ApiResponse<List<PlaceModel>>.fromJson(
            decoded,
            (data) {
              if (data is List) {
                return data
                    .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
                    .toList();
              } else if (data is Map<String, dynamic>) {
                final items = data['items'] ?? data['data'] ?? data['places'] ?? data['results'];
                if (items is List) {
                  return items
                      .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
                      .toList();
                }
              }
              return <PlaceModel>[];
            },
          );
          debugPrint('[PlaceApiService] Loaded ${parsed.data?.length ?? 0} places (total elements: ${parsed.meta?.totalElements})');
          return parsed;
        }
      } else {
        debugPrint('[PlaceApiService] Error Response (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e, stack) {
      debugPrint('[PlaceApiService] searchPlaces API error: $e');
      debugPrint('[PlaceApiService] Stack trace: $stack');
    }

    debugPrint('[PlaceApiService] Using local mock fallback');
    return _searchPlacesLocally(params);
  }

  /// In-memory search & filter fallback matching backend query logic
  ApiResponse<List<PlaceModel>> _searchPlacesLocally(PlaceFilterParams params) {
    List<PlaceModel> result = List.from(MockData.places);

    // 1. Keyword search
    if (params.keyword != null && params.keyword!.trim().isNotEmpty) {
      final q = params.keyword!.trim().toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.location.toLowerCase().contains(q) ||
            p.province.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.desc.toLowerCase().contains(q) ||
            p.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    // 2. Rating
    if (params.minRating != null && params.minRating! > 0) {
      result = result.where((p) => p.rating >= params.minRating!).toList();
    }

    // 3. Price Filter
    if (params.minPrice != null && params.maxPrice != null && params.minPrice! > 0 && params.maxPrice! > 0) {
      result = result.where((p) {
        if (p.price.contains('Miễn phí') && params.minPrice! > 0) return false;
        return p.priceMax >= params.minPrice! && p.priceMax <= params.maxPrice!;
      }).toList();
    } else if (params.minPrice != null && params.minPrice! > 0) {
      result = result.where((p) => p.priceMax >= params.minPrice!).toList();
    }

    // 4. Sorting
    switch (params.sortBy) {
      case 'rating_desc':
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'reviews_desc':
        result.sort((a, b) => b.reviews.compareTo(a.reviews));
        break;
      case 'price_asc':
        result.sort((a, b) => a.priceMax.compareTo(b.priceMax));
        break;
      case 'price_desc':
        result.sort((a, b) => b.priceMax.compareTo(a.priceMax));
        break;
      case 'newest':
        result.sort((a, b) => b.id.compareTo(a.id));
        break;
      case 'popular_desc':
      default:
        result.sort((a, b) => (b.rating * b.reviews).compareTo(a.rating * a.reviews));
        break;
    }

    final totalElements = result.length;
    final totalPages = (totalElements / params.pageSize).ceil();
    final startIndex = (params.page - 1) * params.pageSize;
    final pagedItems = startIndex < result.length
        ? result.skip(startIndex).take(params.pageSize).toList()
        : <PlaceModel>[];

    return ApiResponse<List<PlaceModel>>(
      success: true,
      message: 'Local fallback places',
      data: pagedItems,
      meta: PaginationMeta(
        page: params.page,
        size: params.pageSize,
        totalElements: totalElements,
        totalPages: totalPages > 0 ? totalPages : 1,
      ),
    );
  }
}
