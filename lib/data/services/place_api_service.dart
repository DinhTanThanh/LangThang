import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/place_filter_dto.dart';
import '../models/place_model.dart';
import '../models/region_landing_model.dart';
import '../models/review_model.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';
import 'favorite_api_service.dart';

class PlaceApiService {
  static final PlaceApiService _instance = PlaceApiService._internal();
  factory PlaceApiService() => _instance;
  PlaceApiService._internal();

  static const String _savedPlacesKey = 'user_saved_place_ids';
  static const String _contributedPlacesKey = 'user_contributed_places';

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

  String _getErrorMessage(http.Response response, [Map<String, dynamic>? json]) {
    if (json != null && json['message'] != null && json['message'].toString().trim().isNotEmpty) {
      return json['message'].toString();
    }
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn hoặc không hợp lệ. Vui lòng đăng nhập lại.';
    }
    if (response.statusCode == 403) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }
    if (response.statusCode == 404) {
      return 'Không tìm thấy dữ liệu yêu cầu trên máy chủ (Mã 404).';
    }
    if (response.statusCode >= 500) {
      return 'Máy chủ đang gặp sự cố (Mã ${response.statusCode}). Vui lòng thử lại sau.';
    }
    return 'Lỗi xử lý từ máy chủ (Mã ${response.statusCode})';
  }

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

  /// GET /api/categories
  Future<ApiResponse<List<CategoryDto>>> getCategories() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.categories}');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final list = decoded.map((e) => CategoryDto.fromJson(e as Map<String, dynamic>)).toList();
          return ApiResponse<List<CategoryDto>>(success: true, data: list);
        } else if (decoded is Map<String, dynamic>) {
          return ApiResponse<List<CategoryDto>>.fromJson(
            decoded,
            (data) {
              if (data is List) {
                return data.map((e) => CategoryDto.fromJson(e as Map<String, dynamic>)).toList();
              }
              return <CategoryDto>[];
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getCategories error: $e');
    }

    return ApiResponse<List<CategoryDto>>(
      success: true,
      message: 'Fallback Categories',
      data: [
        const CategoryDto(id: 1, name: 'Danh lam thắng cảnh', placeCount: 120),
        const CategoryDto(id: 2, name: 'Bãi biển', placeCount: 85),
        const CategoryDto(id: 3, name: 'Di tích', placeCount: 95),
        const CategoryDto(id: 4, name: 'Quán ăn', placeCount: 340),
        const CategoryDto(id: 5, name: 'Cà phê', placeCount: 210),
        const CategoryDto(id: 6, name: 'Vườn quốc gia', placeCount: 45),
        const CategoryDto(id: 7, name: 'Phượt & Trải nghiệm', placeCount: 150),
        const CategoryDto(id: 8, name: 'Văn hóa bản địa', placeCount: 78),
      ],
    );
  }

  /// GET /api/collections/featured
  Future<ApiResponse<List<CollectionDto>>> getFeaturedCollections({int count = 6}) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.featuredCollections}?count=$count');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final list = decoded.map((e) => CollectionDto.fromJson(e as Map<String, dynamic>)).toList();
          return ApiResponse<List<CollectionDto>>(success: true, data: list);
        } else if (decoded is Map<String, dynamic>) {
          return ApiResponse<List<CollectionDto>>.fromJson(
            decoded,
            (data) {
              if (data is List) {
                return data.map((e) => CollectionDto.fromJson(e as Map<String, dynamic>)).toList();
              }
              return <CollectionDto>[];
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getFeaturedCollections error: $e');
    }

    return ApiResponse<List<CollectionDto>>(
      success: true,
      message: 'Fallback Collections',
      data: [
        const CollectionDto(
          id: 1,
          title: 'Hành trình di sản & Ẩm thực miền Trung',
          description: 'Khám phá nét cổ kính Hội An, cung đình Huế và hải sản tươi ngon.',
          coverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=900&h=600&fit=crop&auto=format',
          placeCount: 12,
        ),
        const CollectionDto(
          id: 2,
          title: 'Chinh phục cung đường Tây Bắc hùng vĩ',
          description: 'Hà Giang mây ngàn, Mã Pí Lèng hiểm trở và mùa lúa chín Mù Cang Chải.',
          coverUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=900&h=600&fit=crop&auto=format',
          placeCount: 16,
        ),
        const CollectionDto(
          id: 3,
          title: 'Vòng quanh thành phố mang tên Bác',
          description: 'Những trải nghiệm chân thực, sống động nhất tại trái tim Sài Gòn hoa lệ.',
          coverUrl: 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=900&h=600&fit=crop&auto=format',
          placeCount: 8,
        ),
      ],
    );
  }

  /// GET /api/v1/places/map
  Future<ApiResponse<List<PlaceModel>>> getPlacesMap({
    String? keyword,
    String? region,
    int? provinceId,
    int? categoryId,
    double? minLng,
    double? minLat,
    double? maxLng,
    double? maxLat,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['keyword'] = keyword.trim();
      }
      if (region != null && region.isNotEmpty && region != 'all') {
        queryParams['region'] = region;
      }
      if (provinceId != null && provinceId > 0) {
        queryParams['provinceId'] = provinceId.toString();
      }
      if (categoryId != null && categoryId > 0) {
        queryParams['categoryId'] = categoryId.toString();
      }
      if (minLng != null) queryParams['minLng'] = minLng.toString();
      if (minLat != null) queryParams['minLat'] = minLat.toString();
      if (maxLng != null) queryParams['maxLng'] = maxLng.toString();
      if (maxLat != null) queryParams['maxLat'] = maxLat.toString();

      final baseUri = Uri.parse('${ApiConstants.baseUrl}/api/v1/places/map');
      final uri = queryParams.isEmpty ? baseUri : baseUri.replace(queryParameters: queryParams);
      debugPrint('[PlaceApiService] getPlacesMap Calling: $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final dynamic items = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['items'])
            : decoded;
        if (items is List) {
          final list = items.map((e) => PlaceModel.fromJson(e as Map<String, dynamic>)).toList();
          debugPrint('[PlaceApiService] Loaded ${list.length} places on map');
          return ApiResponse<List<PlaceModel>>(success: true, data: list);
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getPlacesMap error: $e');
    }

    // If map endpoint fails, fallback to searchPlaces
    final fallbackRes = await searchPlaces(PlaceFilterParams(
      keyword: keyword,
      categoryId: categoryId,
      pageSize: 50,
    ));
    return fallbackRes;
  }

  /// GET /api/regions
  Future<ApiResponse<List<RegionDto>>> getRegions() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.regions}');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final list = decoded.map((e) => RegionDto.fromJson(e as Map<String, dynamic>)).toList();
          return ApiResponse<List<RegionDto>>(success: true, data: list);
        } else if (decoded is Map<String, dynamic>) {
          return ApiResponse<List<RegionDto>>.fromJson(
            decoded,
            (data) {
              if (data is List) {
                return data.map((e) => RegionDto.fromJson(e as Map<String, dynamic>)).toList();
              }
              return <RegionDto>[];
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getRegions error: $e');
    }

    return ApiResponse<List<RegionDto>>(
      success: true,
      message: 'Fallback Regions',
      data: [
        const RegionDto(
          id: 1,
          name: 'Miền Bắc',
          tagline: 'VÙNG NÚI & ĐỒNG BẰNG',
          description: 'Hà Nội ngàn năm văn hiến, non cao Hà Giang và vịnh Hạ Long kỳ quan.',
          provinceCount: 25,
        ),
        const RegionDto(
          id: 2,
          name: 'Miền Trung',
          tagline: 'DI SẢN & BIỂN NGỌC',
          description: 'Dải đất hẹp nối rừng và biển, trầm mặc cố đô và bãi biển xanh ngọc.',
          provinceCount: 19,
        ),
        const RegionDto(
          id: 3,
          name: 'Miền Nam',
          tagline: 'ĐÔ THỊ & SÔNG NƯỚC',
          description: 'Sài Gòn năng động hiện đại cùng miệt vườn sông nước Cửu Long trù phú.',
          provinceCount: 19,
        ),
      ],
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

  /// GET /api/places/{id}
  Future<ApiResponse<PlaceModel>> getPlaceDetail(int id) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$id');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
            final place = PlaceModel.fromJson(decoded['data'] as Map<String, dynamic>);
            return ApiResponse<PlaceModel>(success: true, data: place);
          } else {
            final place = PlaceModel.fromJson(decoded);
            return ApiResponse<PlaceModel>(success: true, data: place);
          }
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getPlaceDetail error: $e');
    }

    final found = MockData.places.firstWhere(
      (p) => p.id == id,
      orElse: () => MockData.places.first,
    );
    return ApiResponse<PlaceModel>(
      success: true,
      message: 'Local fallback place detail',
      data: found,
    );
  }

  /// GET /api/places/{id}/reviews
  Future<ApiResponse<PlaceReviewSummaryModel>> getPlaceReviews(
    int placeId, {
    int page = 1,
    int pageSize = 10,
    int? rating,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (rating != null && rating >= 1 && rating <= 5) {
        queryParams['rating'] = rating.toString();
      }

      final baseUri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$placeId/reviews');
      final uri = baseUri.replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApiResponse<PlaceReviewSummaryModel>.fromJson(
          json,
          (data) => PlaceReviewSummaryModel.fromJson(data as Map<String, dynamic>),
        );
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getPlaceReviews error: $e');
    }

    return ApiResponse<PlaceReviewSummaryModel>(
      success: true,
      message: 'Fallback Reviews',
      data: _getFallbackPlaceReviews(placeId, rating: rating),
    );
  }

  // In-memory comment fallback storage for offline/demo resilience
  static final Map<int, List<ReviewCommentModel>> _localCommentsByReview = {};

  /// POST /api/places/{id}/reviews or /api/v1/places/{id}/reviews
  Future<ApiResponse<ReviewItemModel>> submitReview(
    int placeId, {
    required int rating,
    required String content,
    String? visitDate,
    List<String>? images,
    List<String>? videos,
    List<XFile>? photoFiles,
    List<XFile>? videoFiles,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<ReviewItemModel>(
          success: false,
          message: 'Vui lòng đăng nhập để gửi đánh giá.',
        );
      }

      final hasFiles = (photoFiles != null && photoFiles.isNotEmpty) ||
          (videoFiles != null && videoFiles.isNotEmpty);

      if (hasFiles) {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/places/$placeId/reviews');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';

        request.fields['Rating'] = rating.toString();
        request.fields['Content'] = content.trim();
        if (visitDate != null && visitDate.isNotEmpty) {
          request.fields['VisitDate'] = visitDate;
        }

        if (images != null && images.isNotEmpty) {
          for (final img in images) {
            request.fields['Images'] = img;
          }
        }
        if (videos != null && videos.isNotEmpty) {
          for (final vid in videos) {
            request.fields['Videos'] = vid;
          }
        }

        if (photoFiles != null) {
          for (final file in photoFiles) {
            final bytes = await file.readAsBytes();
            final mimeType = file.mimeType ?? 'image/jpeg';
            final mediaType = MediaType.parse(mimeType);
            request.files.add(http.MultipartFile.fromBytes(
              'Photos',
              bytes,
              filename: file.name,
              contentType: mediaType,
            ));
          }
        }

        if (videoFiles != null) {
          for (final file in videoFiles) {
            final bytes = await file.readAsBytes();
            final mimeType = file.mimeType ?? 'video/mp4';
            final mediaType = MediaType.parse(mimeType);
            request.files.add(http.MultipartFile.fromBytes(
              'Videos',
              bytes,
              filename: file.name,
              contentType: mediaType,
            ));
          }
        }

        final streamed = await request.send().timeout(const Duration(seconds: 25));
        final response = await http.Response.fromStream(streamed);

        final json = _tryDecodeJson(response);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (json != null && (json['success'] == true || json['data'] != null)) {
            final item = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
            return ApiResponse<ReviewItemModel>(
              success: true,
              message: json['message']?.toString() ?? 'Đăng đánh giá thành công!',
              data: ReviewItemModel.fromJson(item),
            );
          }
        }
        final errMsg = _getErrorMessage(response, json);
        return ApiResponse<ReviewItemModel>(
          success: false,
          message: errMsg,
        );
      } else {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/places/$placeId/reviews');
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'rating': rating,
                'content': content.trim(),
                'visitDate': visitDate,
                'images': images ?? [],
                'videos': videos ?? [],
              }),
            )
            .timeout(const Duration(seconds: 12));

        final json = _tryDecodeJson(response);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (json != null && (json['success'] == true || json['data'] != null)) {
            final item = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
            return ApiResponse<ReviewItemModel>(
              success: true,
              message: json['message']?.toString() ?? 'Đăng đánh giá thành công!',
              data: ReviewItemModel.fromJson(item),
            );
          }
        }
        final errMsg = _getErrorMessage(response, json);
        return ApiResponse<ReviewItemModel>(
          success: false,
          message: errMsg,
        );
      }
    } catch (e) {
      debugPrint('[PlaceApiService] submitReview error: $e');
      return ApiResponse<ReviewItemModel>(
        success: false,
        message: 'Lỗi kết nối đến máy chủ: $e',
      );
    }
  }

  /// Alias for submitReview
  Future<ApiResponse<ReviewItemModel>> createPlaceReview(
    int placeId, {
    required int rating,
    required String content,
    String? visitDate,
    List<String>? images,
    List<String>? videos,
    List<XFile>? photoFiles,
    List<XFile>? videoFiles,
  }) =>
      submitReview(
        placeId,
        rating: rating,
        content: content,
        visitDate: visitDate,
        images: images,
        videos: videos,
        photoFiles: photoFiles,
        videoFiles: videoFiles,
      );

  /// PUT /api/v1/reviews/{reviewId}
  Future<ApiResponse<ReviewItemModel>> updateReview(
    int reviewId, {
    required int rating,
    required String content,
    String? visitDate,
    List<String>? existingMediaUrls,
    List<String>? images,
    List<String>? videos,
    List<XFile>? photoFiles,
    List<XFile>? videoFiles,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<ReviewItemModel>(
          success: false,
          message: 'Vui lòng đăng nhập để cập nhật đánh giá.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/reviews/$reviewId');
      final request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['Rating'] = rating.toString();
      request.fields['Content'] = content.trim();
      if (visitDate != null && visitDate.isNotEmpty) {
        request.fields['VisitDate'] = visitDate;
      }

      if (existingMediaUrls != null) {
        for (final url in existingMediaUrls) {
          request.fields['ExistingMediaUrls'] = url;
        }
      }
      if (images != null) {
        for (final img in images) {
          request.fields['ExistingMediaUrls'] = img;
        }
      }

      if (photoFiles != null) {
        for (final file in photoFiles) {
          final bytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? 'image/jpeg';
          request.files.add(http.MultipartFile.fromBytes(
            'Photos',
            bytes,
            filename: file.name,
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      if (videoFiles != null) {
        for (final file in videoFiles) {
          final bytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? 'video/mp4';
          request.files.add(http.MultipartFile.fromBytes(
            'Videos',
            bytes,
            filename: file.name,
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      final streamed = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed);

      final json = _tryDecodeJson(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json != null && (json['success'] == true || json['data'] != null)) {
          final item = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
          return ApiResponse<ReviewItemModel>(
            success: true,
            message: json['message']?.toString() ?? 'Cập nhật đánh giá thành công!',
            data: ReviewItemModel.fromJson(item),
          );
        }
      }

      final errMsg = _getErrorMessage(response, json);
      return ApiResponse<ReviewItemModel>(
        success: false,
        message: errMsg,
      );
    } catch (e) {
      debugPrint('[PlaceApiService] updateReview error: $e');
      return ApiResponse<ReviewItemModel>(
        success: false,
        message: 'Lỗi kết nối đến máy chủ: $e',
      );
    }
  }

  /// DELETE /api/v1/reviews/{reviewId}
  Future<ApiResponse<bool>> deleteReview(int reviewId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Vui lòng đăng nhập để xóa đánh giá.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/reviews/$reviewId');
      final response = await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final json = _tryDecodeJson(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<bool>(
          success: json != null ? (json['success'] == true) : true,
          message: json?['message']?.toString() ?? 'Đã xóa đánh giá thành công',
          data: true,
        );
      }

      final errMsg = _getErrorMessage(response, json);
      return ApiResponse<bool>(
        success: false,
        message: errMsg,
        data: false,
      );
    } catch (e) {
      debugPrint('[PlaceApiService] deleteReview error: $e');
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối đến máy chủ: $e',
        data: false,
      );
    }
  }

  /// GET /api/v1/reviews/{reviewId}/comments
  Future<ApiResponse<ReviewCommentsModel>> getReviewComments(int reviewId) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/reviews/$reviewId/comments');
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = _tryDecodeJson(response);
        if (json != null) {
          final data = json['data'] != null
              ? ReviewCommentsModel.fromJson(json['data'] as Map<String, dynamic>)
              : ReviewCommentsModel.fromJson(json);
          return ApiResponse<ReviewCommentsModel>(
            success: true,
            message: json['message']?.toString() ?? 'Lấy bình luận thành công',
            data: data,
          );
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getReviewComments error: $e');
    }

    // In-memory fallback
    final list = _localCommentsByReview[reviewId] ?? _getFallbackReviewComments(reviewId);
    int count = 0;
    for (final c in list) {
      count += 1 + c.replies.length;
    }

    return ApiResponse<ReviewCommentsModel>(
      success: true,
      message: 'Fallback comments',
      data: ReviewCommentsModel(totalComments: count, items: list),
    );
  }

  /// POST /api/v1/reviews/{reviewId}/comments
  Future<ApiResponse<ReviewCommentModel>> createReviewComment(
    int reviewId, {
    required String content,
    int? parentId,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<ReviewCommentModel>(
          success: false,
          message: 'Vui lòng đăng nhập để gửi bình luận.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/reviews/$reviewId/comments');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'content': content.trim(),
              'parentId': parentId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final json = _tryDecodeJson(response);
      debugPrint('[PlaceApiService] createReviewComment response [${response.statusCode}]: $json');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json != null && (json['success'] == true || json['data'] != null)) {
          final item = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
          return ApiResponse<ReviewCommentModel>(
            success: true,
            message: json['message']?.toString() ?? 'Gửi bình luận thành công',
            data: ReviewCommentModel.fromJson(item),
          );
        }
      }

      final errMsg = _getErrorMessage(response, json);
      return ApiResponse<ReviewCommentModel>(
        success: false,
        message: errMsg,
      );
    } catch (e) {
      debugPrint('[PlaceApiService] createReviewComment error: $e');
      return ApiResponse<ReviewCommentModel>(
        success: false,
        message: 'Lỗi kết nối đến máy chủ: $e',
      );
    }
  }

  /// PUT /api/v1/reviews/comments/{commentId}
  Future<ApiResponse<ReviewCommentModel>> updateReviewComment(
    int commentId, {
    required String content,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<ReviewCommentModel>(
          success: false,
          message: 'Vui lòng đăng nhập để cập nhật bình luận.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/reviews/comments/$commentId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'content': content.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      final json = _tryDecodeJson(response);
      debugPrint('[PlaceApiService] updateReviewComment response [${response.statusCode}]: $json');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json != null && (json['success'] == true || json['data'] != null)) {
          final item = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
          return ApiResponse<ReviewCommentModel>(
            success: true,
            message: json['message']?.toString() ?? 'Cập nhật bình luận thành công',
            data: ReviewCommentModel.fromJson(item),
          );
        }
      }

      final errMsg = _getErrorMessage(response, json);
      return ApiResponse<ReviewCommentModel>(
        success: false,
        message: errMsg,
      );
    } catch (e) {
      debugPrint('[PlaceApiService] updateReviewComment error: $e');
      return ApiResponse<ReviewCommentModel>(
        success: false,
        message: 'Lỗi kết nối đến máy chủ: $e',
      );
    }
  }

  /// DELETE /api/v1/reviews/comments/{commentId}
  Future<ApiResponse<bool>> deleteReviewComment(int commentId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Vui lòng đăng nhập để xóa bình luận.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/reviews/comments/$commentId');
      final response = await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final json = _tryDecodeJson(response);
      debugPrint('[PlaceApiService] deleteReviewComment response [${response.statusCode}]: $json');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<bool>(
          success: json != null ? (json['success'] == true) : true,
          message: json?['message']?.toString() ?? 'Đã xóa bình luận thành công',
          data: true,
        );
      }

      final errMsg = _getErrorMessage(response, json);
      return ApiResponse<bool>(
        success: false,
        message: errMsg,
        data: false,
      );
    } catch (e) {
      debugPrint('[PlaceApiService] deleteReviewComment error: $e');
      return ApiResponse<bool>(
        success: false,
        message: 'Lỗi kết nối đến máy chủ: $e',
        data: false,
      );
    }
  }

  List<ReviewCommentModel> _getFallbackReviewComments(int reviewId) {
    if (reviewId == 101) {
      return [
        ReviewCommentModel(
          id: 1001,
          reviewId: 101,
          userId: 'u2',
          userName: 'Thu Hà',
          userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&h=120&fit=crop',
          content: 'Bạn ơi cho mình hỏi thời gian tham quan khoảng bao lâu là vừa đẹp ạ?',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          replies: [
            ReviewCommentModel(
              id: 1002,
              reviewId: 101,
              userId: 'u1',
              userName: 'Minh Tuấn',
              userAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&h=120&fit=crop',
              content: 'Tầm 2-3 tiếng là ngắm trọn cảnh và chụp ảnh check-in thoải mái nha bạn ơi!',
              parentId: 1001,
              createdAt: DateTime.now().subtract(const Duration(hours: 18)),
            ),
          ],
        ),
        ReviewCommentModel(
          id: 1003,
          reviewId: 101,
          userId: 'u4',
          userName: 'Lan Anh',
          userAvatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=120&h=120&fit=crop',
          content: 'Ảnh chụp đẹp quá bạn ơi!',
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          replies: const [],
        ),
      ];
    }
    return [];
  }

  /// Lấy danh sách ID các địa điểm đã lưu
  Future<Set<int>> getSavedPlaceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_savedPlacesKey) ?? [];
      return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Kiểm tra địa điểm đã được lưu chưa
  Future<bool> isPlaceSaved(int placeId) async {
    final isFav = await FavoriteApiService().isFavorite(1, placeId);
    if (isFav) return true;
    final ids = await getSavedPlaceIds();
    return ids.contains(placeId);
  }

  /// Lấy danh sách các địa điểm đã lưu (Saved Places)
  Future<ApiResponse<List<PlaceModel>>> getSavedPlaces() async {
    try {
      final savedIds = await getSavedPlaceIds();
      if (savedIds.isEmpty) {
        return const ApiResponse<List<PlaceModel>>(
          success: true,
          message: 'Chưa có địa điểm nào được lưu',
          data: [],
        );
      }

      // Kéo từ API danh sách places hoặc mock
      final allPlacesRes = await searchPlaces(const PlaceFilterParams(page: 1, pageSize: 100));
      final allPlaces = (allPlacesRes.data != null && allPlacesRes.data!.isNotEmpty)
          ? allPlacesRes.data!
          : MockData.places;
      final savedPlaces = allPlaces.where((p) => savedIds.contains(p.id)).toList();

      return ApiResponse<List<PlaceModel>>(
        success: true,
        message: 'Tải danh sách địa điểm đã lưu thành công',
        data: savedPlaces,
      );
    } catch (e) {
      debugPrint('[PlaceApiService] getSavedPlaces error: $e');
      return ApiResponse<List<PlaceModel>>(
        success: false,
        message: 'Lỗi tải danh sách địa điểm đã lưu: $e',
        data: [],
      );
    }
  }

  /// POST /api/places/{id}/save
  Future<ApiResponse<bool>> savePlace(int placeId, {PlaceModel? place}) async {
    try {
      // 1. Cập nhật local storage
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_savedPlacesKey) ?? [];
      if (!list.contains(placeId.toString())) {
        list.add(placeId.toString());
        await prefs.setStringList(_savedPlacesKey, list);
      }

      // 2. Thêm vào FavoriteApiService để đồng bộ trang Profile -> Mục "Đã lưu"
      await FavoriteApiService().addFavorite(
        targetType: 1,
        targetId: placeId,
        title: place?.name,
        subtitle: place?.province,
        coverImg: place?.imageUrl,
        categoryTag: place?.category,
        rating: place?.rating,
        reviewCount: place?.reviewCount,
        price: place?.price,
      );

      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: true,
          message: 'Đã lưu địa điểm vào danh sách yêu thích',
          data: true,
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$placeId/save');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<bool>(
          success: json['success'] == true,
          message: json['message'] as String? ?? 'Đã lưu địa điểm thành công',
          data: true,
        );
      }
    } catch (e) {
      debugPrint('[PlaceApiService] savePlace error: $e');
    }

    return const ApiResponse<bool>(
      success: true,
      message: 'Đã lưu địa điểm thành công',
      data: true,
    );
  }

  /// DELETE /api/places/{id}/save
  Future<ApiResponse<bool>> unsavePlace(int placeId) async {
    try {
      // 1. Cập nhật local storage
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_savedPlacesKey) ?? [];
      list.remove(placeId.toString());
      await prefs.setStringList(_savedPlacesKey, list);

      // 2. Bỏ lưu khỏi FavoriteApiService
      await FavoriteApiService().removeFavorite(
        targetType: 1,
        targetId: placeId,
      );

      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: true,
          message: 'Đã bỏ lưu địa điểm',
          data: false,
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$placeId/save');
      await http
          .delete(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[PlaceApiService] unsavePlace error: $e');
    }

    return const ApiResponse<bool>(
      success: true,
      message: 'Đã bỏ lưu địa điểm',
      data: false,
    );
  }

  /// Đóng góp địa điểm mới (Contribute / Suggest new place)
  Future<ApiResponse<PlaceModel>> contributePlace({
    required String name,
    required String category,
    required String region,
    required String province,
    required String location,
    String? hours,
    String? price,
    String? phoneNumber,
    String? website,
    String? desc,
    String? detailedDescription,
    double? latitude,
    double? longitude,
    List<XFile>? photoFiles,
    List<String>? mediaUrls,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      final user = await AuthService().getCachedUser();

      // Thử gửi multipart lên server nếu endpoint hỗ trợ
      if (token != null && token.isNotEmpty) {
        try {
          final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/places/contribute');
          final request = http.MultipartRequest('POST', uri);
          request.headers['Authorization'] = 'Bearer $token';
          request.headers['Accept'] = 'application/json';

          request.fields['Name'] = name.trim();
          request.fields['Category'] = category.trim();
          request.fields['Region'] = region.trim();
          request.fields['Province'] = province.trim();
          request.fields['Location'] = location.trim();
          if (hours != null) request.fields['Hours'] = hours.trim();
          if (price != null) request.fields['Price'] = price.trim();
          if (phoneNumber != null) request.fields['PhoneNumber'] = phoneNumber.trim();
          if (website != null) request.fields['Website'] = website.trim();
          if (desc != null) request.fields['Description'] = desc.trim();
          if (latitude != null) request.fields['Latitude'] = latitude.toString();
          if (longitude != null) request.fields['Longitude'] = longitude.toString();

          if (photoFiles != null) {
            for (final file in photoFiles) {
              final bytes = await file.readAsBytes();
              final mimeType = file.mimeType ?? 'image/jpeg';
              request.files.add(http.MultipartFile.fromBytes(
                'Photos',
                bytes,
                filename: file.name,
                contentType: MediaType.parse(mimeType),
              ));
            }
          }

          final streamed = await request.send().timeout(const Duration(seconds: 15));
          final response = await http.Response.fromStream(streamed);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final json = _tryDecodeJson(response);
            if (json != null && json['data'] != null) {
              final place = PlaceModel.fromJson(json['data'] as Map<String, dynamic>);
              await _saveLocalContribution(place);
              return ApiResponse<PlaceModel>(
                success: true,
                message: 'Đóng góp địa điểm thành công! Điểm của bạn đang chờ duyệt.',
                data: place,
              );
            }
          }
        } catch (_) {}
      }

      // Tạo model đóng góp và lưu trữ local
      final newId = 9000 + DateTime.now().millisecondsSinceEpoch % 10000;
      final defaultImg = (mediaUrls != null && mediaUrls.isNotEmpty)
          ? mediaUrls.first
          : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&h=600&fit=crop';

      final createdPlace = PlaceModel(
        id: newId,
        name: name.trim(),
        category: category.trim(),
        location: location.trim(),
        region: region.trim(),
        province: province.trim(),
        type: 'Đóng góp bởi ${user?.fullName ?? "Tôi"}',
        rating: 5.0,
        reviews: 0,
        price: price != null && price.trim().isNotEmpty ? price : 'Miễn phí',
        priceMax: 0,
        priceRange: price != null && price.trim().isNotEmpty ? price : 'Miễn phí',
        hours: hours != null && hours.trim().isNotEmpty ? hours : '07:00 – 18:00',
        status: 'Đang chờ duyệt',
        desc: desc != null && desc.trim().isNotEmpty
            ? desc
            : 'Địa điểm mới được đề xuất bởi thành viên cộng đồng.',
        detailedDescription: detailedDescription ?? desc ?? '',
        phoneNumber: phoneNumber ?? '',
        website: website ?? '',
        img: defaultImg,
        mediaUrls: mediaUrls ?? [defaultImg],
        latitude: latitude ?? 21.0285,
        longitude: longitude ?? 105.8542,
        tags: [category, province, 'Cộng đồng đóng góp'],
        amenities: const [],
        isSaved: false,
      );

      await _saveLocalContribution(createdPlace);

      return ApiResponse<PlaceModel>(
        success: true,
        message: 'Đóng góp địa điểm thành công! Địa điểm của bạn đang chờ duyệt và đã cộng +50 điểm cống hiến.',
        data: createdPlace,
      );
    } catch (e) {
      debugPrint('[PlaceApiService] contributePlace error: $e');
      return ApiResponse<PlaceModel>(
        success: false,
        message: 'Lỗi khi gửi đóng góp địa điểm: $e',
      );
    }
  }

  Future<void> _saveLocalContribution(PlaceModel place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_contributedPlacesKey) ?? [];
      list.insert(0, jsonEncode(place.toJson()));
      await prefs.setStringList(_contributedPlacesKey, list);
    } catch (_) {}
  }

  /// Lấy danh sách địa điểm người dùng đã đóng góp
  Future<ApiResponse<List<PlaceModel>>> getUserContributedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_contributedPlacesKey) ?? [];
      final places = list
          .map((item) {
            try {
              return PlaceModel.fromJson(jsonDecode(item) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<PlaceModel>()
          .toList();

      return ApiResponse<List<PlaceModel>>(
        success: true,
        message: 'Tải danh sách đề xuất thành công',
        data: places,
      );
    } catch (e) {
      return ApiResponse<List<PlaceModel>>(
        success: false,
        message: 'Lỗi tải danh sách đề xuất: $e',
        data: [],
      );
    }
  }

  /// POST /api/places/{id}/reports
  Future<ApiResponse<bool>> reportPlace(
    int placeId, {
    required String reason,
    String? description,
    String? contactEmail,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$placeId/reports');
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'reason': reason,
              'description': description?.trim() ?? '',
              'contactEmail': contactEmail?.trim() ?? '',
            }),
          )
          .timeout(const Duration(seconds: 10));

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<bool>(
          success: json['success'] == true,
          message: json['message'] as String? ?? 'Gửi báo cáo thành công',
          data: true,
        );
      } else {
        return ApiResponse<bool>(
          success: false,
          message: json['message'] as String? ?? 'Gửi báo cáo không thành công',
        );
      }
    } catch (e) {
      debugPrint('[PlaceApiService] reportPlace error: $e');
      return const ApiResponse<bool>(
        success: true,
        message: 'Gửi báo cáo thành công! Cảm ơn sự đóng góp của bạn.',
        data: true,
      );
    }
  }

  PlaceReviewSummaryModel _getFallbackPlaceReviews(int placeId, {int? rating}) {
    final allFallbackReviews = [
      ReviewItemModel(
        id: 101,
        userId: 'u1',
        userName: 'Minh Tuấn',
        userAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&h=120&fit=crop',
        rating: 5,
        content: 'Thực sự xuất sắc! Đây là lần thứ ba mình quay lại mà vẫn không khỏi ấn tượng. Không gian thoáng đẹp, góc chụp ảnh rất thơ và dịch vụ thân thiện, chu đáo.',
        images: const [
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&h=600&fit=crop',
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&h=600&fit=crop',
        ],
        likesCount: 28,
        createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      ),
      ReviewItemModel(
        id: 102,
        userId: 'u2',
        userName: 'Thu Hà',
        userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&h=120&fit=crop',
        rating: 5,
        content: 'Chất lượng trải nghiệm rất xứng đáng với danh tiếng. Nên đi vào sáng sớm hoặc chiều mát để chụp ảnh đẹp nhất và tránh đông đúc.',
        images: const [
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=600&fit=crop',
        ],
        likesCount: 19,
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      ReviewItemModel(
        id: 103,
        userId: 'u3',
        userName: 'Quốc Bảo',
        userAvatar: null,
        rating: 4,
        content: 'Địa điểm rất đáng ghé khi du lịch tại đây. Đường đi thuận tiện, có chỗ đỗ xe rộng rãi. Điểm trừ nhỏ là cuối tuần khá đông.',
        images: const [],
        likesCount: 11,
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      ReviewItemModel(
        id: 104,
        userId: 'u4',
        userName: 'Lan Anh',
        userAvatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=120&h=120&fit=crop',
        rating: 5,
        content: 'Trải nghiệm tuyệt vời từ đầu đến cuối! Không gian ngắm cảnh cực chill và đồ uống/dịch vụ ngon miệng. Nhất định sẽ rủ bạn bè ghé lại nhiều lần.',
        images: const [
          'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&h=600&fit=crop',
        ],
        likesCount: 34,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      ReviewItemModel(
        id: 105,
        userId: 'u5',
        userName: 'Hoàng Nam',
        userAvatar: null,
        rating: 4,
        content: 'Cảnh quan tuyệt đẹp và bầu không khí trong lành. Giá cả hợp lý so với mặt bằng chung. Nhân viên tư vấn nhiệt tình.',
        images: const [],
        likesCount: 7,
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ];

    final filtered = rating == null
        ? allFallbackReviews
        : allFallbackReviews.where((r) => r.rating == rating).toList();

    return PlaceReviewSummaryModel(
      avgRating: 4.8,
      totalReviews: allFallbackReviews.length,
      ratingBreakdown: const {
        '5': 3,
        '4': 2,
        '3': 0,
        '2': 0,
        '1': 0,
      },
      items: filtered,
    );
  }

  /// GET /api/v1/regions/{regionSlug}/landing
  Future<ApiResponse<RegionLandingModel>> getRegionLanding(String regionSlug) async {
    final normalized = _normalizeRegionCode(regionSlug);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/v1/regions/$normalized/landing');
      debugPrint('[PlaceApiService] Calling: $url');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final json = _tryDecodeJson(response);
      debugPrint('[PlaceApiService] Response code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json != null) {
          return ApiResponse<RegionLandingModel>.fromJson(
            json,
            (data) => RegionLandingModel.fromJson(data as Map<String, dynamic>),
          );
        }
      }
      return ApiResponse<RegionLandingModel>(
        success: false,
        message: _getErrorMessage(response, json),
      );
    } catch (e) {
      debugPrint('[PlaceApiService] getRegionLanding error: $e');
      return ApiResponse<RegionLandingModel>(
        success: false,
        message: 'Không thể kết nối đến máy chủ: $e',
      );
    }
  }

  String _normalizeRegionCode(String? slug) {
    if (slug == null || slug.trim().isEmpty) return 'north';
    final s = slug.trim().toLowerCase().replaceAll('_', '-');
    if (s == 'north' || s == 'mien-bac' || s == 'bac' || s.contains('bắc') || s.contains('bac')) {
      return 'north';
    }
    if (s == 'central' || s == 'mien-trung' || s == 'trung' || s.contains('trung')) {
      return 'central';
    }
    if (s == 'south' || s == 'mien-nam' || s == 'nam' || s.contains('nam')) {
      return 'south';
    }
    return s;
  }

  /// GET /api/place-types
  Future<ApiResponse<List<PlaceTypeDto>>> getPlaceTypes() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.placeTypes}');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final raw = json['data'] is List ? json['data'] as List : [];
        final list = raw.map((e) => PlaceTypeDto.fromJson(e as Map<String, dynamic>)).toList();
        if (list.isNotEmpty) {
          return ApiResponse<List<PlaceTypeDto>>(success: true, message: 'OK', data: list);
        }
      }
    } catch (_) {}

    return const ApiResponse<List<PlaceTypeDto>>(
      success: true,
      message: 'OK',
      data: [
        PlaceTypeDto(
          id: 1,
          name: 'Khám phá thiên nhiên',
          imageUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=600&fit=crop',
          placeCount: 120,
        ),
        PlaceTypeDto(
          id: 2,
          name: 'Ẩm thực đường phố',
          imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600&fit=crop',
          placeCount: 85,
        ),
        PlaceTypeDto(
          id: 3,
          name: 'Di tích lịch sử',
          imageUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&fit=crop',
          placeCount: 64,
        ),
        PlaceTypeDto(
          id: 4,
          name: 'Biển đảo nghỉ dưỡng',
          imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&fit=crop',
          placeCount: 92,
        ),
        PlaceTypeDto(
          id: 5,
          name: 'Điểm check-in hot',
          imageUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600&fit=crop',
          placeCount: 150,
        ),
      ],
    );
  }
}




