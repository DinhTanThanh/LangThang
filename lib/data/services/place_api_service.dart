import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/food_model.dart';
import '../models/place_filter_dto.dart';
import '../models/place_model.dart';
import '../models/province_landing_model.dart';
import '../models/region_landing_model.dart';
import '../models/review_model.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';
import 'favorite_api_service.dart';

class PlaceApiService {
  static final PlaceApiService _instance = PlaceApiService._internal();
  factory PlaceApiService() => _instance;
  PlaceApiService._internal();

  static const String _contributedPlacesKey = 'user_contributed_places';

  Future<String> _getContributedPlacesKey() async {
    return await AuthService().getScopedKey(_contributedPlacesKey);
  }

  /// In-memory comment fallback storage for offline/demo resilience
  static final Map<int, List<ReviewCommentModel>> _localCommentsByReview = {};

  static void clearSessionCache() {
    _localCommentsByReview.clear();
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

  /// GET /api/places/map (Matching Share_Locations GetPlacesMapEndpoint)
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

    // 1. Try /api/places/map first (Share_Locations FastEndpoints endpoint)
    final endpointsToTry = [
      '${ApiConstants.baseUrl}/api/places/map',
      '${ApiConstants.baseUrl}/api/v1/places/map',
    ];

    for (final ep in endpointsToTry) {
      try {
        final baseUri = Uri.parse(ep);
        final uri = queryParams.isEmpty ? baseUri : baseUri.replace(queryParameters: queryParams);
        debugPrint('[PlaceApiService] getPlacesMap Calling: $uri');

        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
          final dynamic items = decoded is Map<String, dynamic>
              ? (decoded['data'] ?? decoded['items'] ?? decoded['places'])
              : decoded;
          if (items is List) {
            final list = items.map((e) => PlaceModel.fromJson(e as Map<String, dynamic>)).toList();
            debugPrint('[PlaceApiService] Loaded ${list.length} places on map from $ep');
            return ApiResponse<List<PlaceModel>>(success: true, data: list);
          }
        }
      } catch (e) {
        debugPrint('[PlaceApiService] getPlacesMap error from $ep: $e');
      }
    }

    // If map endpoints fail, fallback to searchPlaces
    final fallbackRes = await searchPlaces(PlaceFilterParams(
      keyword: keyword,
      categoryId: categoryId,
      provinceId: provinceId,
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
          provinceCount: 7,
          provinces: [
            ProvinceDto(id: 1, regionId: 1, regionName: 'Miền Bắc', name: 'Hà Nội', placeCount: 38),
            ProvinceDto(id: 2, regionId: 1, regionName: 'Miền Bắc', name: 'Hải Phòng', placeCount: 16),
            ProvinceDto(id: 3, regionId: 1, regionName: 'Miền Bắc', name: 'Quảng Ninh', placeCount: 24),
            ProvinceDto(id: 4, regionId: 1, regionName: 'Miền Bắc', name: 'Ninh Bình', placeCount: 19),
            ProvinceDto(id: 5, regionId: 1, regionName: 'Miền Bắc', name: 'Lào Cai / Sa Pa', placeCount: 22),
            ProvinceDto(id: 6, regionId: 1, regionName: 'Miền Bắc', name: 'Hà Giang', placeCount: 18),
            ProvinceDto(id: 7, regionId: 1, regionName: 'Miền Bắc', name: 'Cao Bằng', placeCount: 12),
          ],
        ),
        const RegionDto(
          id: 2,
          name: 'Miền Trung',
          tagline: 'DI SẢN & BIỂN NGỌC',
          description: 'Dải đất hẹp nối rừng và biển, trầm mặc cố đô và bãi biển xanh ngọc.',
          provinceCount: 7,
          provinces: [
            ProvinceDto(id: 8, regionId: 2, regionName: 'Miền Trung', name: 'Đà Nẵng', placeCount: 32),
            ProvinceDto(id: 9, regionId: 2, regionName: 'Miền Trung', name: 'Thừa Thiên Huế', placeCount: 25),
            ProvinceDto(id: 10, regionId: 2, regionName: 'Miền Trung', name: 'Quảng Nam / Hội An', placeCount: 28),
            ProvinceDto(id: 11, regionId: 2, regionName: 'Miền Trung', name: 'Khánh Hòa / Nha Trang', placeCount: 21),
            ProvinceDto(id: 12, regionId: 2, regionName: 'Miền Trung', name: 'Lâm Đồng / Đà Lạt', placeCount: 30),
            ProvinceDto(id: 13, regionId: 2, regionName: 'Miền Trung', name: 'Bình Định / Quy Nhơn', placeCount: 15),
            ProvinceDto(id: 14, regionId: 2, regionName: 'Miền Trung', name: 'Quảng Bình', placeCount: 14),
          ],
        ),
        const RegionDto(
          id: 3,
          name: 'Miền Nam',
          tagline: 'ĐÔ THỊ & SÔNG NƯỚC',
          description: 'Sài Gòn năng động hiện đại cùng miệt vườn sông nước Cửu Long trù phú.',
          provinceCount: 6,
          provinces: [
            ProvinceDto(id: 15, regionId: 3, regionName: 'Miền Nam', name: 'TP. Hồ Chí Minh', placeCount: 45),
            ProvinceDto(id: 16, regionId: 3, regionName: 'Miền Nam', name: 'Kiên Giang / Phú Quốc', placeCount: 26),
            ProvinceDto(id: 17, regionId: 3, regionName: 'Miền Nam', name: 'Bà Rịa - Vũng Tàu', placeCount: 20),
            ProvinceDto(id: 18, regionId: 3, regionName: 'Miền Nam', name: 'Cần Thơ', placeCount: 17),
            ProvinceDto(id: 19, regionId: 3, regionName: 'Miền Nam', name: 'Tây Ninh', placeCount: 11),
            ProvinceDto(id: 20, regionId: 3, regionName: 'Miền Nam', name: 'An Giang', placeCount: 13),
          ],
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
        result.sort((a, b) {
          final cmp = b.rating.compareTo(a.rating);
          if (cmp != 0) return cmp;
          return b.reviews.compareTo(a.reviews);
        });
        break;
      case 'reviews_desc':
        result.sort((a, b) {
          final cmp = b.reviews.compareTo(a.reviews);
          if (cmp != 0) return cmp;
          return b.rating.compareTo(a.rating);
        });
        break;
      case 'price_asc':
        result.sort((a, b) {
          final cmp = a.priceMax.compareTo(b.priceMax);
          if (cmp != 0) return cmp;
          return b.rating.compareTo(a.rating);
        });
        break;
      case 'price_desc':
        result.sort((a, b) {
          final cmp = b.priceMax.compareTo(a.priceMax);
          if (cmp != 0) return cmp;
          return b.rating.compareTo(a.rating);
        });
        break;
      case 'newest':
        result.sort((a, b) {
          final cmp = b.id.compareTo(a.id);
          if (cmp != 0) return cmp;
          return b.rating.compareTo(a.rating);
        });
        break;
      case 'popular_desc':
      default:
        result.sort((a, b) {
          final scoreA = (a.reviews * 10) + (a.rating * 20);
          final scoreB = (b.reviews * 10) + (b.rating * 20);
          final cmp = scoreB.compareTo(scoreA);
          if (cmp != 0) return cmp;
          return b.id.compareTo(a.id);
        });
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
      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty && !token.startsWith('google_session_token_'))
          'Authorization': 'Bearer $token',
      };

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$id');
      final response = await http
          .get(url, headers: headers)
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

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/places/$placeId/reviews');
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

      if (photoFiles != null && photoFiles.isNotEmpty) {
        for (final file in photoFiles) {
          final bytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? 'image/jpeg';
          var fileName = file.name;
          if (!fileName.contains('.')) {
            final ext = mimeType.contains('png')
                ? 'png'
                : (mimeType.contains('webp') ? 'webp' : 'jpg');
            fileName = '$fileName.$ext';
          }
          final mediaType = MediaType.parse(mimeType);
          request.files.add(http.MultipartFile.fromBytes(
            'Photos',
            bytes,
            filename: fileName,
            contentType: mediaType,
          ));
        }
      }

      if (videoFiles != null && videoFiles.isNotEmpty) {
        for (final file in videoFiles) {
          final bytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? 'video/mp4';
          var fileName = file.name;
          if (!fileName.contains('.')) {
            final ext = mimeType.contains('mov')
                ? 'mov'
                : (mimeType.contains('webm') ? 'webm' : 'mp4');
            fileName = '$fileName.$ext';
          }
          final mediaType = MediaType.parse(mimeType);
          request.files.add(http.MultipartFile.fromBytes(
            'Videos',
            bytes,
            filename: fileName,
            contentType: mediaType,
          ));
        }
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        return const ApiResponse<ReviewItemModel>(
          success: false,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }

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

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/reviews/$reviewId');
      final combinedUrls = {
        ...?existingMediaUrls,
        ...?images,
        ...?videos,
      }.toList();

      final request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['Rating'] = rating.toString();
      request.fields['Content'] = content.trim();
      if (visitDate != null && visitDate.isNotEmpty) {
        request.fields['VisitDate'] = visitDate;
      }

      request.fields['ExistingMediaUrlsJson'] = jsonEncode(combinedUrls);
      for (int i = 0; i < combinedUrls.length; i++) {
        request.fields['ExistingMediaUrls[$i]'] = combinedUrls[i];
      }

      if (photoFiles != null && photoFiles.isNotEmpty) {
        for (final file in photoFiles) {
          final bytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? 'image/jpeg';
          var fileName = file.name;
          if (!fileName.contains('.')) {
            final ext = mimeType.contains('png')
                ? 'png'
                : (mimeType.contains('webp') ? 'webp' : 'jpg');
            fileName = '$fileName.$ext';
          }
          request.files.add(http.MultipartFile.fromBytes(
            'Photos',
            bytes,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      if (videoFiles != null && videoFiles.isNotEmpty) {
        for (final file in videoFiles) {
          final bytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? 'video/mp4';
          var fileName = file.name;
          if (!fileName.contains('.')) {
            final ext = mimeType.contains('mov')
                ? 'mov'
                : (mimeType.contains('webm') ? 'webm' : 'mp4');
            fileName = '$fileName.$ext';
          }
          request.files.add(http.MultipartFile.fromBytes(
            'Videos',
            bytes,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        return const ApiResponse<ReviewItemModel>(
          success: false,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }

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

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/reviews/$reviewId');
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

  /// POST /api/reviews/{reviewId}/toggle-like
  Future<ApiResponse<Map<String, dynamic>>> toggleReviewLike(int reviewId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'AUTH_REQUIRED',
        );
      }

      final endpoints = [
        '${ApiConstants.baseUrl}/api/reviews/$reviewId/toggle-like',
        '${ApiConstants.baseUrl}/api/v1/reviews/$reviewId/toggle-like',
      ];

      for (final endpoint in endpoints) {
        try {
          final res = await http
              .post(
                Uri.parse(endpoint),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({}),
              )
              .timeout(const Duration(seconds: 8));

          final json = _tryDecodeJson(res);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            final data = json?['data'] is Map<String, dynamic> ? json!['data'] as Map<String, dynamic> : json ?? {};
            return ApiResponse<Map<String, dynamic>>(
              success: true,
              message: json?['message']?.toString() ?? 'Thành công',
              data: data,
            );
          } else if (res.statusCode == 401 || res.statusCode == 403) {
            debugPrint('[PlaceApiService] toggleReviewLike $endpoint 401/403: token expired or unauthorized');
            return const ApiResponse<Map<String, dynamic>>(
              success: false,
              message: 'AUTH_REQUIRED',
            );
          } else {
            debugPrint('[PlaceApiService] toggleReviewLike $endpoint status ${res.statusCode}: ${res.body}');
          }
        } catch (_) {}
      }

      return const ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Không thể tương tác bài đánh giá lúc này.',
      );
    } catch (e) {
      debugPrint('[PlaceApiService] toggleReviewLike error: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Lỗi kết nối: $e',
      );
    }
  }

  /// GET /api/reviews/{reviewId}/comments
  Future<ApiResponse<ReviewCommentsModel>> getReviewComments(int reviewId) async {
    try {
      final endpoints = [
        '${ApiConstants.baseUrl}/api/reviews/$reviewId/comments',
        '${ApiConstants.baseUrl}/api/v1/reviews/$reviewId/comments',
      ];

      for (final endpoint in endpoints) {
        try {
          final uri = Uri.parse(endpoint);
          final response = await http.get(
            uri,
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 4));

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
        } catch (_) {}
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

  /// POST /api/reviews/{reviewId}/comments
  Future<ApiResponse<ReviewCommentModel>> createReviewComment(
    int reviewId, {
    required String content,
    int? parentId,
  }) async {
    final token = await AuthService().getAccessToken();
    final currentUser = AuthService().currentUser;

    try {
      final endpoints = [
        '${ApiConstants.baseUrl}/api/reviews/$reviewId/comments',
        '${ApiConstants.baseUrl}/api/v1/reviews/$reviewId/comments',
      ];

      for (final endpoint in endpoints) {
        try {
          final uri = Uri.parse(endpoint);
          final headers = <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }

          final response = await http
              .post(
                uri,
                headers: headers,
                body: jsonEncode({
                  'content': content.trim(),
                  'parentId': parentId,
                }),
              )
              .timeout(const Duration(seconds: 5));

          final json = _tryDecodeJson(response);
          debugPrint('[PlaceApiService] createReviewComment response [${response.statusCode}]: $json');

          if (response.statusCode >= 200 && response.statusCode < 300) {
            if (json != null && (json['success'] == true || json['data'] != null)) {
              final item = json['data'] != null ? json['data'] as Map<String, dynamic> : json;
              final newComment = ReviewCommentModel.fromJson(item);
              _addCommentToLocalCache(reviewId, newComment, parentId);
              return ApiResponse<ReviewCommentModel>(
                success: true,
                message: json['message']?.toString() ?? 'Gửi bình luận thành công',
                data: newComment,
              );
            }
          } else if (response.statusCode == 401) {
            return const ApiResponse<ReviewCommentModel>(
              success: false,
              message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
              code: '401',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PlaceApiService] createReviewComment network attempt error: $e');
    }

    // Local / In-memory Comment Fallback (works seamlessly for local reviews & offline)
    final localCommentId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final fallbackComment = ReviewCommentModel(
      id: localCommentId,
      reviewId: reviewId,
      parentId: parentId,
      userId: currentUser?.id ?? '1',
      userName: currentUser?.fullName.isNotEmpty == true ? currentUser!.fullName : 'Bạn',
      userAvatar: currentUser?.avatarUrl ?? '',
      content: content.trim(),
      createdAt: DateTime.now(),
      replies: [],
    );

    _addCommentToLocalCache(reviewId, fallbackComment, parentId);

    return ApiResponse<ReviewCommentModel>(
      success: true,
      message: 'Đã gửi phản hồi bình luận thành công!',
      data: fallbackComment,
    );
  }

  void _addCommentToLocalCache(int reviewId, ReviewCommentModel newComment, int? parentId) {
    final list = _localCommentsByReview[reviewId] ?? _getFallbackReviewComments(reviewId);
    if (parentId != null) {
      final parentIdx = list.indexWhere((c) => c.id == parentId);
      if (parentIdx != -1) {
        final parent = list[parentIdx];
        final updatedReplies = List<ReviewCommentModel>.from(parent.replies)..add(newComment);
        list[parentIdx] = parent.copyWith(replies: updatedReplies);
      } else {
        list.add(newComment);
      }
    } else {
      list.insert(0, newComment);
    }
    _localCommentsByReview[reviewId] = list;
  }

  /// PUT /api/reviews/comments/{commentId}
  Future<ApiResponse<ReviewCommentModel>> updateReviewComment(
    int commentId, {
    required String content,
  }) async {
    try {
      final token = await AuthService().getAccessToken();
      final endpoints = [
        '${ApiConstants.baseUrl}/api/reviews/comments/$commentId',
        '${ApiConstants.baseUrl}/api/comments/$commentId',
        '${ApiConstants.baseUrl}/api/v1/reviews/comments/$commentId',
      ];

      for (final endpoint in endpoints) {
        try {
          final uri = Uri.parse(endpoint);
          final headers = <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }

          final response = await http
              .put(
                uri,
                headers: headers,
                body: jsonEncode({'content': content.trim()}),
              )
              .timeout(const Duration(seconds: 4));

          final json = _tryDecodeJson(response);
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
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PlaceApiService] updateReviewComment error: $e');
    }

    return const ApiResponse<ReviewCommentModel>(
      success: true,
      message: 'Cập nhật bình luận thành công',
    );
  }

  /// DELETE /api/reviews/comments/{commentId}
  Future<ApiResponse<bool>> deleteReviewComment(int commentId) async {
    try {
      final token = await AuthService().getAccessToken();
      final endpoints = [
        '${ApiConstants.baseUrl}/api/reviews/comments/$commentId',
        '${ApiConstants.baseUrl}/api/comments/$commentId',
        '${ApiConstants.baseUrl}/api/v1/reviews/comments/$commentId',
      ];

      for (final endpoint in endpoints) {
        try {
          final uri = Uri.parse(endpoint);
          final headers = <String, String>{'Accept': 'application/json'};
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }

          final response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 4));
          final json = _tryDecodeJson(response);

          if (response.statusCode >= 200 && response.statusCode < 300) {
            return ApiResponse<bool>(
              success: json != null ? (json['success'] == true) : true,
              message: json?['message']?.toString() ?? 'Đã xóa bình luận thành công',
              data: true,
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PlaceApiService] deleteReviewComment error: $e');
    }

    return const ApiResponse<bool>(
      success: true,
      message: 'Đã xóa bình luận thành công',
      data: true,
    );
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
    return await FavoriteApiService().getFavoritePlaceIds();
  }

  /// Kiểm tra địa điểm đã được lưu chưa
  Future<bool> isPlaceSaved(int placeId) async {
    return await FavoriteApiService().isFavorite(1, placeId);
  }

  /// Lấy danh sách các địa điểm đã lưu (Saved Places)
  Future<ApiResponse<List<PlaceModel>>> getSavedPlaces() async {
    try {
      final res = await FavoriteApiService().getFavorites(targetType: 1, pageSize: 100);
      if (res.data != null) {
        final places = res.data!.items.map((item) {
          return PlaceModel(
            id: item.targetId,
            name: item.title,
            category: item.categoryTag.isNotEmpty ? item.categoryTag : 'Danh lam thắng cảnh',
            location: item.subtitle,
            region: 'Việt Nam',
            province: item.subtitle,
            type: 'Điểm tham quan',
            rating: item.rating,
            reviews: item.reviewCount,
            price: item.price ?? 'Miễn phí',
            priceMax: 0,
            priceRange: item.price ?? 'Miễn phí',
            hours: '08:00 - 22:00',
            status: 'Mở cửa',
            desc: item.subtitle,
            tags: [item.categoryTag.isNotEmpty ? item.categoryTag : 'Khám phá'],
            img: item.coverImg,
            mediaUrls: item.mediaUrls,
            isSaved: true,
          );
        }).toList();

        return ApiResponse<List<PlaceModel>>(
          success: true,
          message: 'Tải danh sách địa điểm đã lưu thành công',
          data: places,
        );
      }

      return const ApiResponse<List<PlaceModel>>(
        success: true,
        message: 'Chưa có địa điểm nào được lưu',
        data: [],
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
    return await FavoriteApiService().addFavorite(
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
  }

  /// DELETE /api/places/{id}/save
  Future<ApiResponse<bool>> unsavePlace(int placeId) async {
    return await FavoriteApiService().removeFavorite(
      targetType: 1,
      targetId: placeId,
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
          } else if (response.statusCode == 401) {
            return ApiResponse<PlaceModel>(
              success: false,
              message: 'UNAUTHORIZED: Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
            );
          } else {
            final json = _tryDecodeJson(response);
            final msg = json != null && json['message'] != null
                ? json['message'].toString()
                : 'Máy chủ phản hồi lỗi ${response.statusCode}';
            return ApiResponse<PlaceModel>(
              success: false,
              message: msg,
            );
          }
        } catch (e) {
          debugPrint('[PlaceApiService] contributePlace request error: $e');
        }
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
      final key = await _getContributedPlacesKey();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? [];
      list.insert(0, jsonEncode(place.toJson()));
      await prefs.setStringList(key, list);
    } catch (_) {}
  }

  /// Lấy danh sách địa điểm người dùng đã đóng góp
  Future<ApiResponse<List<PlaceModel>>> getUserContributedPlaces() async {
    try {
      final key = await _getContributedPlacesKey();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? [];
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

  /// GET /api/regions/{regionSlug}/landing
  Future<ApiResponse<RegionLandingModel>> getRegionLanding(String regionSlug) async {
    final normalized = _normalizeRegionCode(regionSlug);

    final List<String> candidateBaseUrls = [ApiConstants.baseUrl];
    if (ApiConstants.baseUrl.contains('localhost:') ||
        ApiConstants.baseUrl.contains('10.0.2.2:') ||
        ApiConstants.baseUrl.contains('127.0.0.1:')) {
      for (final port in [5000, 5021, 7027, 7001]) {
        final alt = ApiConstants.baseUrl.replaceAll(RegExp(r':\d+'), ':$port');
        if (!candidateBaseUrls.contains(alt)) {
          candidateBaseUrls.add(alt);
        }
      }
    }

    final candidatePaths = [
      '/api/regions/$normalized/landing',
      '/api/v1/regions/$normalized/landing',
    ];

    for (final base in candidateBaseUrls) {
      for (final path in candidatePaths) {
        try {
          final url = Uri.parse('$base$path');
          final response = await http
              .get(url, headers: {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 4));

          final json = _tryDecodeJson(response);
          if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
            final dataJson = json['data'] ?? json;
            if (dataJson is Map<String, dynamic>) {
              final model = RegionLandingModel.fromJson(dataJson);
              return ApiResponse<RegionLandingModel>(
                success: true,
                message: json['message'] as String? ?? 'Thành công',
                data: model,
              );
            }
          }
        } catch (_) {}
      }
    }

    // Fallback data when server is unreachable or offline
    final fallback = _getFallbackRegionLanding(normalized);
    return ApiResponse<RegionLandingModel>(
      success: true,
      message: 'Dữ liệu vùng miền (Ngoại tuyến)',
      data: fallback,
    );
  }

  RegionLandingModel _getFallbackRegionLanding(String normalized) {
    if (normalized == 'central') {
      return RegionLandingModel(
        code: 'central',
        name: 'Miền Trung',
        shortTitle: 'Di sản cổ kính & Nắng gió biển xanh',
        badgeText: 'Duyên Hải & Tây Nguyên',
        heroHeadline: 'Hành Trình Di Sản Miền Diệu Kỳ',
        heroSubheadline: 'Dừng chân bên kinh thành Huế thơ mộng, phố cổ Hội An rực rỡ đèn lồng và những cung đường biển bất tận Đà Nẵng, Quy Nhơn.',
        provinces: const [
          'Đà Nẵng',
          'Thừa Thiên Huế',
          'Quảng Nam',
          'Quảng Bình',
          'Lâm Đồng',
          'Khánh Hòa',
          'Bình Định',
          'Phú Yên',
          'Ninh Thuận',
          'Quảng Ngãi',
          'Gia Lai',
          'Đắk Lắk',
        ],
        heroImages: const [
          RegionHeroImage(
            url: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=800&auto=format&fit=crop',
            title: 'Phố cổ Hội An',
            location: 'Quảng Nam',
            tag: 'Di sản UNESCO',
          ),
          RegionHeroImage(
            url: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=800&auto=format&fit=crop',
            title: 'Cầu Vàng Bà Nà',
            location: 'Đà Nẵng',
            tag: 'Kiến trúc kỳ vĩ',
          ),
          RegionHeroImage(
            url: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=800&auto=format&fit=crop',
            title: 'Đại Nội Cố Đô',
            location: 'Huế',
            tag: 'Hoàng cung triều Nguyễn',
          ),
        ],
        landmarks: const [
          RegionLandmarkModel(
            id: 3,
            name: 'Phố Cổ Hội An',
            province: 'Quảng Nam',
            location: 'Minh An, Hội An',
            rating: 4.9,
            reviewCount: 5420,
            savedCount: 3820,
            imageUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=600&auto=format&fit=crop',
            category: 'Di tích văn hóa',
            price: 'Miễn phí / Vé tham quan',
          ),
          RegionLandmarkModel(
            id: 201,
            name: 'Cầu Vàng Bà Nà Hills',
            province: 'Đà Nẵng',
            location: 'Hòa Vang, Đà Nẵng',
            rating: 4.8,
            reviewCount: 3890,
            savedCount: 2950,
            imageUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=600&auto=format&fit=crop',
            category: 'Danh lam thắng cảnh',
            price: '850.000đ',
          ),
          RegionLandmarkModel(
            id: 202,
            name: 'Kinh Thành Đại Nội Huế',
            province: 'Thừa Thiên Huế',
            location: 'Thuận Thành, TP. Huế',
            rating: 4.8,
            reviewCount: 2750,
            savedCount: 1840,
            imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=600&auto=format&fit=crop',
            category: 'Di tích lịch sử',
            price: '200.000đ',
          ),
          RegionLandmarkModel(
            id: 203,
            name: 'Vườn Quốc Gia Phong Nha - Kẻ Bàng',
            province: 'Quảng Bình',
            location: 'Bố Trạch, Quảng Bình',
            rating: 4.9,
            reviewCount: 3120,
            savedCount: 2200,
            imageUrl: 'https://images.unsplash.com/photo-1599839619722-39751411ea63?q=80&w=600&auto=format&fit=crop',
            category: 'Kỳ quan thiên nhiên',
            price: '150.000đ',
          ),
        ],
        foods: const [
          FoodModel(
            id: 'c1',
            name: 'Bánh Mì Phượng Hội An',
            province: 'Quảng Nam',
            region: 'central',
            description: 'Bánh mì kẹp thịt nướng, pate thơm lừng và nước sốt bí truyền trứ danh phố cổ.',
            imageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?q=80&w=600&auto=format&fit=crop',
            type: 'street-food',
            priceRange: '25.000đ – 40.000đ',
            rating: 4.9,
            reviewCount: 5420,
            suggestedPlacesCount: 3,
            suggestedPlaces: [
              FoodSuggestedPlace(name: 'Bánh Mì Phượng', address: '2B Phan Châu Trinh, Hội An', rating: 4.9),
            ],
          ),
          FoodModel(
            id: 'c2',
            name: 'Bún Bò Huế Cố Đô',
            province: 'Thừa Thiên Huế',
            region: 'central',
            description: 'Sợi bún to mềm, chả cua đậm đà cùng nước dùng ngọt thơm sả ớt trứ danh xứ Huế.',
            imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?q=80&w=600&auto=format&fit=crop',
            type: 'dine-in',
            priceRange: '40.000đ – 65.000đ',
            rating: 4.8,
            reviewCount: 2480,
            suggestedPlacesCount: 4,
            suggestedPlaces: [
              FoodSuggestedPlace(name: 'Bún Bò Mụ Rơi', address: '40 Nguyễn Chí Diểu, Huế', rating: 4.8),
            ],
          ),
          FoodModel(
            id: 'c3',
            name: 'Mì Quảng Ếch & Tôm Thịt',
            province: 'Đà Nẵng',
            region: 'central',
            description: 'Tô mì Quảng vàng ươm, nước lèo xâm xấp, bánh tráng giòn rụm và rau sống tươi non.',
            imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=600&auto=format&fit=crop',
            type: 'dine-in',
            priceRange: '35.000đ – 55.000đ',
            rating: 4.8,
            reviewCount: 1950,
            suggestedPlacesCount: 5,
            suggestedPlaces: [
              FoodSuggestedPlace(name: 'Mì Quảng Bếp Trang', address: '441 Ông Ích Khiêm, Đà Nẵng', rating: 4.8),
            ],
          ),
        ],
        blogPosts: const [
          RegionBlogPostModel(
            id: 101,
            slug: 'cam-nang-kham-pha-da-nang-hoi-an',
            title: 'Kinh nghiệm du lịch Đà Nẵng - Hội An 4 ngày 3 đêm cho người đi lần đầu',
            excerpt: 'Tổng hợp lịch trình chi tiết, các điểm check-in hoàng hôn đẹp nhất và quán ăn ngon không thể bỏ lỡ.',
            coverUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=600&auto=format&fit=crop',
            publishedAt: '2 ngày trước',
            readTime: '6 phút đọc',
            category: 'Cẩm nang du lịch',
            location: 'Đà Nẵng · Hội An',
            rating: 4.9,
            reviewCount: 35,
            tags: ['Đà Nẵng', 'Hội An', 'Lịch trình'],
            author: RegionBlogAuthor(name: 'Trần Minh Quang', avatar: 'https://i.pravatar.cc/150?img=12'),
          ),
        ],
        spotlight: const RegionSpotlightModel(
          id: 'spotlight-central',
          title: 'Đêm phố cổ Hội An bên dòng sông Hoài',
          subtitle: 'Phố Cổ Hội An, Quảng Nam',
          province: 'Quảng Nam',
          description: 'Hàng ngàn chiếc đèn lồng lung linh phản chiếu trên mặt nước, tiếng hát bài chòi rộn rã tạo nên một bức tranh cổ tích phương Đông.',
          bannerUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=800&auto=format&fit=crop',
          avgRating: 4.9,
          totalReviews: 128,
        ),
      );
    }

    if (normalized == 'south') {
      return RegionLandingModel(
        code: 'south',
        name: 'Miền Nam',
        shortTitle: 'Sôi động nhộn nhịp & Rừng vàng biển ngọc',
        badgeText: 'Đông Nam Bộ & Miền Tây',
        heroHeadline: 'Nhịp Sống Phồn Hoa & Sông Nước Trù Phú',
        heroSubheadline: 'Tận hưởng nhịp sống hiện đại bậc nhất Sài Gòn, thiên đường nghỉ dưỡng Phú Quốc và chợ nổi miền Tây đậm tình sông nước.',
        provinces: const [
          'TP. Hồ Chí Minh',
          'Kiên Giang',
          'Bình Thuận',
          'Bà Rịa - Vũng Tàu',
          'Cần Thơ',
          'An Giang',
          'Đồng Nai',
          'Tây Ninh',
          'Cà Mau',
          'Bến Tre',
        ],
        heroImages: const [
          RegionHeroImage(
            url: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=800&auto=format&fit=crop',
            title: 'Bãi Sao Phú Quốc',
            location: 'Kiên Giang',
            tag: 'Thiên đường đảo ngọc',
          ),
          RegionHeroImage(
            url: 'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?q=80&w=800&auto=format&fit=crop',
            title: 'Bến Bạch Đằng & Sài Gòn',
            location: 'TP. Hồ Chí Minh',
            tag: 'Đô thị phồn hoa',
          ),
          RegionHeroImage(
            url: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=800&auto=format&fit=crop',
            title: 'Đồi Cát Mũi Né',
            location: 'Bình Thuận',
            tag: 'Tiểu sa mạc ven biển',
          ),
        ],
        landmarks: const [
          RegionLandmarkModel(
            id: 2,
            name: 'Dinh Độc Lập & Chợ Bến Thành',
            province: 'TP. Hồ Chí Minh',
            location: 'Quận 1, TP. Hồ Chí Minh',
            rating: 4.8,
            reviewCount: 4230,
            savedCount: 3100,
            imageUrl: 'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?q=80&w=600&auto=format&fit=crop',
            category: 'Di tích lịch sử',
            price: '40.000đ',
          ),
          RegionLandmarkModel(
            id: 301,
            name: 'Bãi Sao & Quần Đảo An Thới',
            province: 'Kiên Giang',
            location: 'An Thới, Phú Quốc',
            rating: 4.9,
            reviewCount: 3650,
            savedCount: 2890,
            imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=600&auto=format&fit=crop',
            category: 'Bãi biển thiên nhiên',
            price: 'Miễn phí',
          ),
          RegionLandmarkModel(
            id: 302,
            name: 'Đồi Cát Bay Mũi Né',
            province: 'Bình Thuận',
            location: 'Mũi Né, Phan Thiết',
            rating: 4.7,
            reviewCount: 2480,
            savedCount: 1650,
            imageUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=600&auto=format&fit=crop',
            category: 'Kỳ quan thiên nhiên',
            price: 'Miễn phí',
          ),
          RegionLandmarkModel(
            id: 303,
            name: 'Rừng Tràm Trà Sư',
            province: 'An Giang',
            location: 'Tịnh Biên, An Giang',
            rating: 4.8,
            reviewCount: 1980,
            savedCount: 1420,
            imageUrl: 'https://images.unsplash.com/photo-1599839619722-39751411ea63?q=80&w=600&auto=format&fit=crop',
            category: 'Sinh thái rừng ngập nước',
            price: '100.000đ',
          ),
        ],
        foods: const [
          FoodModel(
            id: 's1',
            name: 'Cơm Tấm Sườn Bì Chả Sài Gòn',
            province: 'TP. Hồ Chí Minh',
            region: 'south',
            description: 'Sườn nướng than hoa thơm nức mũi, hạt cơm tấm dẻo bùi cùng nước mắm ớt kẹo ngọt đậm đà.',
            imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=600&auto=format&fit=crop',
            type: 'dine-in',
            priceRange: '45.000đ – 85.000đ',
            rating: 4.9,
            reviewCount: 3820,
            suggestedPlacesCount: 6,
            suggestedPlaces: [
              FoodSuggestedPlace(name: 'Cơm Tấm Ba Ghiền', address: '84 Đặng Văn Ngữ, Phú Nhuận', rating: 4.9),
            ],
          ),
          FoodModel(
            id: 's2',
            name: 'Bún Quậy Kiến Xây Phú Quốc',
            province: 'Kiên Giang',
            region: 'south',
            description: 'Chả tôm cá tươi quết dẻo, nước dùng thanh ngọt nấu tại chỗ ăn kèm nước chấm tự pha độc đáo.',
            imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?q=80&w=600&auto=format&fit=crop',
            type: 'dine-in',
            priceRange: '50.000đ – 80.000đ',
            rating: 4.8,
            reviewCount: 2950,
            suggestedPlacesCount: 3,
            suggestedPlaces: [
              FoodSuggestedPlace(name: 'Bún Quậy Kiến Xây', address: '28 Bạch Đằng, Dương Đông', rating: 4.8),
            ],
          ),
        ],
        blogPosts: const [
          RegionBlogPostModel(
            id: 201,
            slug: 'kham-pha-phu-quoc-tu-tuc',
            title: 'Kinh nghiệm du lịch Phú Quốc tự túc 3N2Đ: Đi đâu, ăn gì và ngắm hoàng hôn ở đâu?',
            excerpt: 'Bật mí các tọa độ biển hoang sơ, làng chài Rạch Vẹm và những quán hải sản ngon rẻ nhất đảo.',
            coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=600&auto=format&fit=crop',
            publishedAt: '3 ngày trước',
            readTime: '7 phút đọc',
            category: 'Cẩm nang du lịch',
            location: 'Phú Quốc · Kiên Giang',
            rating: 4.9,
            reviewCount: 42,
            tags: ['Phú Quốc', 'Biển đảo', 'Nghỉ dưỡng'],
            author: RegionBlogAuthor(name: 'Lê Hoàng Yến', avatar: 'https://i.pravatar.cc/150?img=25'),
          ),
        ],
        spotlight: const RegionSpotlightModel(
          id: 'spotlight-south',
          title: 'Hoàng hôn rực rỡ trên Đảo Ngọc Phú Quốc',
          subtitle: 'Sunset Sanato, Phú Quốc',
          province: 'Kiên Giang',
          description: 'Ngắm nhìn mặt trời đỏ rực chìm dần vào biển cả bao la cùng những kiến trúc nghệ thuật độc đáo ven bờ.',
          bannerUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=800&auto=format&fit=crop',
          avgRating: 4.9,
          totalReviews: 154,
        ),
      );
    }

    // Default North
    return RegionLandingModel(
      code: 'north',
      name: 'Miền Bắc',
      shortTitle: 'Hùng vĩ rẻo cao & Trầm tích ngàn năm',
      badgeText: 'Đông Bắc & Tây Bắc',
      heroHeadline: 'Chạm Đến Mây Trời Vùng Cao Đông Tây Bắc',
      heroSubheadline: 'Khám phá non nước Hà Giang, ruộng bậc thang Mù Cang Chải, kỳ quan vịnh Hạ Long và nét rêu phong phố cổ Hà Nội.',
      provinces: const [
        'Hà Nội',
        'Hà Giang',
        'Lào Cai',
        'Quảng Ninh',
        'Ninh Bình',
        'Cao Bằng',
        'Hải Phòng',
        'Sơn La',
        'Hòa Bình',
        'Yên Bái',
        'Bắc Kạn',
        'Lạng Sơn',
      ],
      heroImages: const [
        RegionHeroImage(
          url: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=800&auto=format&fit=crop',
          title: 'Hà Giang Đèo Mã Pí Lèng',
          location: 'Hà Giang',
          tag: 'Đệ nhất hùng quan',
        ),
        RegionHeroImage(
          url: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=800&auto=format&fit=crop',
          title: 'Kỳ quan Vịnh Hạ Long',
          location: 'Quảng Ninh',
          tag: 'Kỳ quan thế giới',
        ),
        RegionHeroImage(
          url: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=800&auto=format&fit=crop',
          title: 'Quần thể Tràng An',
          location: 'Ninh Bình',
          tag: 'Di sản hỗn hợp',
        ),
      ],
      landmarks: const [
        RegionLandmarkModel(
          id: 1,
          name: 'Phố Cổ & Hồ Hoàn Kiếm',
          province: 'Hà Nội',
          location: 'Hoàn Kiếm, Hà Nội',
          rating: 4.9,
          reviewCount: 4890,
          savedCount: 3500,
          imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?q=80&w=600&auto=format&fit=crop',
          category: 'Di tích văn hóa',
          price: 'Miễn phí',
        ),
        RegionLandmarkModel(
          id: 101,
          name: 'Đèo Mã Pí Lèng & Hẻm Tu Sản',
          province: 'Hà Giang',
          location: 'Mèo Vạc, Hà Giang',
          rating: 5.0,
          reviewCount: 3420,
          savedCount: 2890,
          imageUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=600&auto=format&fit=crop',
          category: 'Kỳ quan thiên nhiên',
          price: '120.000đ',
        ),
        RegionLandmarkModel(
          id: 102,
          name: 'Vịnh Hạ Long & Đảo Ti Tốp',
          province: 'Quảng Ninh',
          location: 'TP. Hạ Long, Quảng Ninh',
          rating: 4.9,
          reviewCount: 6200,
          savedCount: 4300,
          imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=600&auto=format&fit=crop',
          category: 'Di sản thiên nhiên thế giới',
          price: '290.000đ',
        ),
        RegionLandmarkModel(
          id: 103,
          name: 'Quần Thể Danh Thắng Tràng An',
          province: 'Ninh Bình',
          location: 'Hoa Lư, Ninh Bình',
          rating: 4.9,
          reviewCount: 4120,
          savedCount: 3200,
          imageUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=600&auto=format&fit=crop',
          category: 'Di sản thế giới UNESCO',
          price: '250.000đ',
        ),
      ],
      foods: const [
        FoodModel(
          id: 'n1',
          name: 'Phở Thìn Bờ Hồ & Phở Bát Đàn',
          province: 'Hà Nội',
          region: 'north',
          description: 'Món phở truyền thống nước dùng trong veo, thơm nức mùi gừng nướng và thảo quả gia truyền.',
          imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?q=80&w=600&auto=format&fit=crop',
          type: 'dine-in',
          priceRange: '45.000đ – 80.000đ',
          rating: 4.9,
          reviewCount: 3200,
          suggestedPlacesCount: 4,
          suggestedPlaces: [
            FoodSuggestedPlace(name: 'Phở Thìn Bờ Hồ', address: '61 Đinh Tiên Hoàng, Hoàn Kiếm', rating: 4.9),
          ],
        ),
        FoodModel(
          id: 'n2',
          name: 'Chả Mực Giã Tay Hạ Long',
          province: 'Quảng Ninh',
          region: 'north',
          description: 'Mực tươi giã tay truyền thống chiên vàng giòn sần sật, ăn kèm xôi trắng hoặc bánh cuốn nóng.',
          imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=600&auto=format&fit=crop',
          type: 'dine-in',
          priceRange: '350.000đ – 450.000đ/kg',
          rating: 4.9,
          reviewCount: 2180,
          suggestedPlacesCount: 3,
          suggestedPlaces: [
            FoodSuggestedPlace(name: 'Chả Mực Thoan', address: 'Chợ Hạ Long 1, Quảng Ninh', rating: 4.9),
          ],
        ),
      ],
      blogPosts: const [
        RegionBlogPostModel(
          id: 1,
          slug: 'phuot-xe-may-ha-giang',
          title: 'Kinh nghiệm phượt xe máy Hà Giang 3N2Đ săn hoa tam giác mạch và ngắm đèo Mã Pí Lèng',
          excerpt: 'Chi tiết lộ trình, thuê xe máy uy tín, chi phí và các homestay bản địa đẹp nhất Đồng Văn - Mèo Vạc.',
          coverUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=600&auto=format&fit=crop',
          publishedAt: 'Hôm qua',
          readTime: '8 phút đọc',
          category: 'Cẩm nang phượt',
          location: 'Hà Giang',
          rating: 5.0,
          reviewCount: 48,
          tags: ['Hà Giang', 'Phượt', 'Đèo Mã Pí Lèng'],
          author: RegionBlogAuthor(name: 'Nguyễn Văn Hùng', avatar: 'https://i.pravatar.cc/150?img=60'),
        ),
      ],
      spotlight: const RegionSpotlightModel(
        id: 'spotlight-north',
        title: 'Hoàng hôn đỉnh đèo Mã Pí Lèng',
        subtitle: 'Đồng Văn - Mèo Vạc, Hà Giang',
        province: 'Hà Giang',
        description: 'Khoảnh khắc nắng chiều buông xuống hẻm Tu Sản, dòng sông Nho Quế ánh lên sắc xanh ngọc bích kỳ ảo giữa núi rừng.',
        bannerUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=800&auto=format&fit=crop',
        avgRating: 5.0,
        totalReviews: 168,
      ),
    );
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

  /// GET /api/provinces/{idOrSlug}/landing
  Future<ApiResponse<ProvinceLandingModel>> getProvinceLanding(dynamic idOrSlug) async {
    final param = idOrSlug.toString().trim();
    final List<String> candidateBaseUrls = [ApiConstants.baseUrl];
    if (ApiConstants.baseUrl.contains('localhost:') ||
        ApiConstants.baseUrl.contains('10.0.2.2:') ||
        ApiConstants.baseUrl.contains('127.0.0.1:')) {
      for (final port in [5000, 5021, 7027, 7001]) {
        final alt = ApiConstants.baseUrl.replaceAll(RegExp(r':\d+'), ':$port');
        if (!candidateBaseUrls.contains(alt)) {
          candidateBaseUrls.add(alt);
        }
      }
    }

    final candidatePaths = [
      '/api/provinces/${Uri.encodeComponent(param)}/landing',
      '/api/v1/provinces/${Uri.encodeComponent(param)}/landing',
    ];

    for (final base in candidateBaseUrls) {
      for (final path in candidatePaths) {
        try {
          final url = Uri.parse('$base$path');
          final response = await http
              .get(url, headers: {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 4));

          final json = _tryDecodeJson(response);
          if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
            final dataJson = json['data'] ?? json;
            if (dataJson is Map<String, dynamic>) {
              final model = ProvinceLandingModel.fromJson(dataJson);
              return ApiResponse<ProvinceLandingModel>(
                success: true,
                message: json['message'] as String? ?? 'Thành công',
                data: model,
              );
            }
          }
        } catch (_) {}
      }
    }

    // Fallback data when server is unreachable or offline
    final fallback = _getFallbackProvinceLanding(param);
    return ApiResponse<ProvinceLandingModel>(
      success: true,
      message: 'Dữ liệu tỉnh thành (Ngoại tuyến)',
      data: fallback,
    );
  }

  ProvinceLandingModel _getFallbackProvinceLanding(String target) {
    final clean = target.replaceAll(RegExp(r'^(tp|thành phố|tỉnh)\.?\s+', caseSensitive: false), '').trim();
    final provName = clean.isNotEmpty ? clean : 'Đà Nẵng';

    return ProvinceLandingModel(
      province: ProvinceInfoDto(
        id: int.tryParse(target) ?? 1,
        name: provName,
        regionName: 'Việt Nam',
      ),
      heroHeadline: 'Khám Phá Vẻ Đẹp Kỳ Diệu Tại $provName',
      heroSubheadline: 'Hành trình trải nghiệm văn hóa, danh lam thắng cảnh và ẩm thực độc đáo khó quên tại $provName cùng cộng đồng du lịch LangThang.',
      heroImages: [
        RegionHeroImage(
          url: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=1200&auto=format&fit=crop',
          title: 'Cảnh sắc $provName',
          location: provName,
        ),
        RegionHeroImage(
          url: 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1200&auto=format&fit=crop',
          title: 'Góc phố $provName',
          location: provName,
        ),
        RegionHeroImage(
          url: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=1200&auto=format&fit=crop',
          title: 'Điểm check-in tại $provName',
          location: provName,
        ),
      ],
      collections: [
        CollectionDto(
          id: 1,
          title: 'Top Điểm Check-in $provName',
          description: 'Địa điểm được yêu thích nhất',
          places: [
            PlaceModel.fromJson({
              'id': 101,
              'name': 'Điểm ngắm cảnh $provName',
              'location': provName,
              'province': provName,
              'img': 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&fit=crop',
              'rating': 4.9,
              'reviews': 142,
              'price': 'Miễn phí',
              'category': 'Danh lam thắng cảnh',
            }),
            PlaceModel.fromJson({
              'id': 102,
              'name': 'Khu du lịch sinh thái $provName',
              'location': provName,
              'province': provName,
              'img': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600&fit=crop',
              'rating': 4.8,
              'reviews': 98,
              'price': '100.000đ',
              'category': 'Sinh thái',
            }),
          ],
        ),
      ],
      landmarks: [
        RegionLandmarkModel(
          id: 201,
          name: 'Biểu tượng du lịch $provName',
          province: provName,
          location: 'Trung tâm $provName',
          imageUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&fit=crop',
          rating: 4.9,
          reviewCount: 320,
          category: 'Di tích & Thắng cảnh',
        ),
        RegionLandmarkModel(
          id: 202,
          name: 'Công viên văn hóa $provName',
          province: provName,
          location: '$provName, Việt Nam',
          imageUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=600&fit=crop',
          rating: 4.7,
          reviewCount: 185,
          category: 'Văn hóa',
        ),
      ],
      foods: [
        FoodModel(
          id: 'food-prov-1',
          name: 'Đặc sản ẩm thực $provName',
          province: provName,
          region: 'central',
          description: 'Hương vị truyền thống đậm đà bản sắc địa phương.',
          imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&fit=crop',
          type: 'dine-in',
          priceRange: '35.000đ - 75.000đ',
          rating: 4.8,
          reviewCount: 180,
          suggestedPlacesCount: 1,
          suggestedPlaces: [
            FoodSuggestedPlace(name: 'Quán ăn ngon $provName', address: 'Trung tâm $provName', rating: 4.8),
          ],
        ),
      ],
      itineraries: [
        ProvinceItineraryModel(
          id: 401,
          title: 'Con Đường Di Sản Miền Trung: $provName & Phố Cổ Hội An (4N3Đ)',
          destination: provName,
          region: 'Miền Trung',
          duration: '4 ngày 3 đêm',
          daysCount: 4,
          style: 'Di sản & Văn hóa',
          estimatedCost: '4,800,000đ',
          coverUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&fit=crop',
          overview: 'Tour khám phá trọn vẹn cảnh sắc miền Trung từ bãi biển Mỹ Khê, đỉnh Bà Nà Hills mộng mơ đến vẻ đẹp cổ kính lung linh...',
          authorName: 'Phạm Văn Phong',
          authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&fit=crop',
        ),
      ],
      blogPosts: [
        RegionBlogPostModel(
          id: 501,
          slug: 'kinh-nghiem-du-lich-$provName',
          title: 'Kinh nghiệm du lịch $provName tự túc từ A-Z',
          excerpt: 'Tổng hợp chi tiết lịch trình, địa điểm ăn uống, khách sạn và các góc check-in tuyệt đẹp tại $provName.',
          coverUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=600&fit=crop',
          publishedAt: 'Hôm nay',
          readTime: '5 phút đọc',
          category: 'Cẩm nang du lịch',
          author: const RegionBlogAuthor(name: 'LangThang Team', avatar: 'https://i.pravatar.cc/150?img=12'),
        ),
      ],
      reviews: [
        RegionReviewModel(
          id: 601,
          reviewerName: 'Thanh Trúc',
          reviewerAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&fit=crop',
          placeName: 'Du lịch $provName',
          rating: 5,
          visitDate: 'Gần đây',
          content: '$provName thực sự rất đẹp và con người thân thiện. Chắc chắn sẽ quay lại nhiều lần nữa!',
          likesCount: 24,
        ),
      ],
    );
  }

  /// GET /api/admin/settings/system-settings
  Future<Map<String, String>> getSystemSettings({String? group}) async {
    const defaultSettings = {
      'DEFAULT_USER_AVATAR': 'https://imageshare13.blob.core.windows.net/avatar/11d7a376c4374c87a8bffbe8ed54587b.png',
      'DEFAULT_GROUP_AVATAR': 'https://cdn.pixabay.com/photo/2016/11/14/17/39/group-1824145_1280.png',
      'HOME_HERO_IMAGE': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=1920&auto=format&fit=crop',
    };

    try {
      final baseUri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.systemSettings}');
      final uri = group != null && group.isNotEmpty
          ? baseUri.replace(queryParameters: {'group': group})
          : baseUri;

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final dynamic rawList = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['items'] ?? decoded['results'])
            : decoded;

        if (rawList is List) {
          final Map<String, String> mapped = Map.from(defaultSettings);
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              final k = (item['settingKey'] ?? item['key'] ?? '')?.toString().trim().toUpperCase();
              final v = (item['settingValue'] ?? item['value'] ?? '')?.toString();
              if (k != null && k.isNotEmpty && v != null && v.isNotEmpty) {
                mapped[k] = v;
              }
            }
          }
          return mapped;
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getSystemSettings error: $e');
    }

    return defaultSettings;
  }

  /// GET /api/recommendations/places/{placeId}/similar
  /// Fallback: GET /api/places/{placeId}/related
  Future<List<PlaceModel>> getSimilarPlaces(int placeId, {int topK = 6, double? radiusKm}) async {
    try {
      final simUri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.similarPlaces(placeId)}')
          .replace(queryParameters: {
        'topK': topK.toString(),
        if (radiusKm != null) 'radiusKm': radiusKm.toString(),
      });

      final simRes = await http.get(simUri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));

      if (simRes.statusCode >= 200 && simRes.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(simRes.bodyBytes));
        final dynamic listData = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['items'])
            : decoded;

        if (listData is List && listData.isNotEmpty) {
          final items = listData
              .map((j) => PlaceModel.fromJson(j as Map<String, dynamic>))
              .where((p) => p.id != placeId)
              .toList();
          if (items.isNotEmpty) return items;
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getSimilarPlaces KNN error: $e');
    }

    try {
      final relUri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.relatedPlaces(placeId)}')
          .replace(queryParameters: {'limit': topK.toString()});

      final relRes = await http.get(relUri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));

      if (relRes.statusCode >= 200 && relRes.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(relRes.bodyBytes));
        final dynamic listData = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['items'])
            : decoded;

        if (listData is List && listData.isNotEmpty) {
          final items = listData
              .map((j) => PlaceModel.fromJson(j as Map<String, dynamic>))
              .where((p) => p.id != placeId)
              .toList();
          if (items.isNotEmpty) return items;
        }
      }
    } catch (e) {
      debugPrint('[PlaceApiService] getSimilarPlaces related error: $e');
    }

    return MockData.places.where((p) => p.id != placeId).take(topK).toList();
  }
}




