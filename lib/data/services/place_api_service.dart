import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/place_filter_dto.dart';
import '../models/place_model.dart';
import '../models/review_model.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';

class PlaceApiService {
  static final PlaceApiService _instance = PlaceApiService._internal();
  factory PlaceApiService() => _instance;
  PlaceApiService._internal();

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

  /// POST /api/places/{id}/save
  Future<ApiResponse<bool>> savePlace(int placeId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Vui lòng đăng nhập để lưu địa điểm.',
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
      } else {
        return ApiResponse<bool>(
          success: false,
          message: json['message'] as String? ?? 'Lưu địa điểm thất bại',
        );
      }
    } catch (e) {
      debugPrint('[PlaceApiService] savePlace error: $e');
      return ApiResponse<bool>(
        success: true,
        message: 'Đã lưu địa điểm thành công',
        data: true,
      );
    }
  }

  /// DELETE /api/places/{id}/save
  Future<ApiResponse<bool>> unsavePlace(int placeId) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        return const ApiResponse<bool>(
          success: false,
          message: 'Vui lòng đăng nhập để thao tác.',
        );
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.places}/$placeId/save');
      final response = await http
          .delete(
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
          message: json['message'] as String? ?? 'Đã bỏ lưu địa điểm',
          data: false,
        );
      } else {
        return ApiResponse<bool>(
          success: false,
          message: json['message'] as String? ?? 'Bỏ lưu địa điểm thất bại',
        );
      }
    } catch (e) {
      debugPrint('[PlaceApiService] unsavePlace error: $e');
      return ApiResponse<bool>(
        success: true,
        message: 'Đã bỏ lưu địa điểm',
        data: false,
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
}
