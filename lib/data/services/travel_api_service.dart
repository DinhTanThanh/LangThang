import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/destination_model.dart';
import '../models/food_model.dart';
import '../models/itinerary_model.dart';
import '../models/blog_model.dart';
import '../models/user_model.dart';
import '../models/place_model.dart';
import '../models/place_filter_dto.dart';
import '../models/collection_model.dart';
import '../mock/mock_data.dart';
import 'auth_service.dart';
import 'place_api_service.dart';

class TravelApiService {
  // Singleton pattern
  static final TravelApiService _instance = TravelApiService._internal();
  factory TravelApiService() => _instance;
  TravelApiService._internal();

  /// Lấy danh sách toàn bộ điểm đến hoặc lọc theo vùng miền
  Future<List<DestinationModel>> getDestinations({Region? region}) async {
    try {
      final res = await PlaceApiService().searchPlaces(const PlaceFilterParams(pageSize: 50));
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final places = res.data!;
        final list = places.map((p) => DestinationModel(
          id: p.id.toString(),
          title: p.name,
          location: p.location,
          region: p.region.toLowerCase().contains('bắc')
              ? Region.north
              : (p.region.toLowerCase().contains('trung') ? Region.central : Region.south),
          rating: p.rating,
          reviewCount: p.reviews,
          imageUrl: p.img,
          badgeText: p.category,
          description: p.desc,
          tags: p.tags,
        )).toList();

        if (region == null) {
          return list;
        }
        return list.where((d) => d.region == region).toList();
      }
    } catch (_) {}

    if (region == null) {
      return MockData.destinations;
    }
    return MockData.destinations.where((d) => d.region == region).toList();
  }

  /// Lấy chi tiết một điểm đến theo ID
  Future<DestinationModel?> getDestinationById(String id) async {
    final numId = int.tryParse(id);
    if (numId != null) {
      final res = await PlaceApiService().getPlaceDetail(numId);
      if (res.success && res.data != null) {
        final p = res.data!;
        return DestinationModel(
          id: p.id.toString(),
          title: p.name,
          location: p.location,
          region: p.region.toLowerCase().contains('bắc')
              ? Region.north
              : (p.region.toLowerCase().contains('trung') ? Region.central : Region.south),
          rating: p.rating,
          reviewCount: p.reviews,
          imageUrl: p.img,
          badgeText: p.category,
          description: p.desc,
          tags: p.tags,
        );
      }
    }
    try {
      return MockData.destinations.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách ẩm thực địa phương (theo vùng miền, tỉnh hoặc từ khóa)
  Future<List<FoodModel>> getFoods({
    String? region,
    String? province,
    String? keyword,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (region != null && region.isNotEmpty && region != 'all') {
        queryParams['region'] = region;
      }
      if (province != null && province.isNotEmpty && province != 'all') {
        queryParams['province'] = province;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['keyword'] = keyword.trim();
      }

      final baseUri = Uri.parse('${ApiConstants.baseUrl}/api/v1/foods');
      final uri = queryParams.isEmpty ? baseUri : baseUri.replace(queryParameters: queryParams);

      final token = await AuthService().getAccessToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final dynamic items = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded['items']) : decoded;
        if (items is List && items.isNotEmpty) {
          return items.map((e) => FoodModel.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    // Fallback: Local filtering on MockData.foods
    List<FoodModel> list = List.from(MockData.foods);

    if (region != null && region.isNotEmpty && region != 'all') {
      final reg = region.toLowerCase();
      list = list.where((f) {
        if (reg == 'north' || reg.contains('bắc')) {
          return f.region == 'north' || f.province.contains('Hà Nội') || f.province.contains('Hải Phòng') || f.province.contains('Ninh Bình') || f.province.contains('Lào Cai') || f.province.contains('Sa Pa');
        }
        if (reg == 'central' || reg.contains('trung')) {
          return f.region == 'central' || f.province.contains('Huế') || f.province.contains('Đà Nẵng') || f.province.contains('Hội An') || f.province.contains('Quảng Nam') || f.province.contains('Nha Trang') || f.province.contains('Khánh Hòa') || f.province.contains('Lâm Đồng') || f.province.contains('Đà Lạt');
        }
        if (reg == 'south' || reg.contains('nam')) {
          return f.region == 'south' || f.province.contains('Hồ Chí Minh') || f.province.contains('Sài Gòn') || f.province.contains('Cần Thơ') || f.province.contains('Kiên Giang') || f.province.contains('Phú Quốc') || f.province.contains('An Giang');
        }
        return f.region.toLowerCase() == reg || f.province.toLowerCase().contains(reg);
      }).toList();
    }

    if (province != null && province.isNotEmpty && province != 'all') {
      final prov = province.toLowerCase();
      list = list.where((f) => f.province.toLowerCase().contains(prov) || f.address.toLowerCase().contains(prov)).toList();
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.trim().toLowerCase();
      list = list.where((f) {
        return f.name.toLowerCase().contains(q) ||
            f.description.toLowerCase().contains(q) ||
            f.province.toLowerCase().contains(q) ||
            f.suggestedPlaces.any((p) => p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q));
      }).toList();
    }

    return list;
  }

  /// Lấy danh sách lịch trình gợi ý (Gọi API hoặc Fallback)
  Future<List<ItineraryModel>> getItineraries({
    String? duration,
    String? keyword,
    String? region,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (duration != null && duration.isNotEmpty && duration != 'all') {
        queryParams['duration'] = duration;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['keyword'] = keyword.trim();
      }
      if (region != null && region.isNotEmpty && region != 'all') {
        queryParams['region'] = region;
      }

      final baseUri = Uri.parse('${ApiConstants.baseUrl}/api/v1/itineraries');
      final uri = queryParams.isEmpty ? baseUri : baseUri.replace(queryParameters: queryParams);

      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final dynamic items = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded['items']) : decoded;
        if (items is List && items.isNotEmpty) {
          return items.map((e) => ItineraryModel.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    // Fallback filter
    List<ItineraryModel> list = List.from(MockData.itineraries);

    if (duration != null && duration != 'all') {
      if (duration == '1_day') {
        list = list.where((i) => i.daysCount == 1 || i.duration.contains('1 Ngày')).toList();
      } else if (duration == '2d1n') {
        list = list.where((i) => i.daysCount == 2 || i.duration.contains('2 Ngày')).toList();
      } else if (duration == '3d2n') {
        list = list.where((i) => i.daysCount == 3 || i.duration.contains('3 Ngày')).toList();
      } else if (duration == '4d3n') {
        list = list.where((i) => i.daysCount >= 4 || i.duration.contains('4 Ngày')).toList();
      }
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.trim().toLowerCase();
      list = list.where((i) {
        return i.title.toLowerCase().contains(q) ||
            i.destination.toLowerCase().contains(q) ||
            (i.overview?.toLowerCase().contains(q) ?? false) ||
            i.days.any((d) => d.stops.any((s) => s.location.toLowerCase().contains(q) || s.activity.toLowerCase().contains(q)));
      }).toList();
    }

    if (region != null && region != 'all') {
      list = list.where((i) => i.region.toLowerCase() == region.toLowerCase()).toList();
    }

    return list;
  }

  /// Lưu lịch trình
  Future<bool> saveItinerary(int id) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) return false;

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/itineraries/$id/save');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return true; // Optimistic
    }
  }

  /// Lấy danh sách bài viết blog
  Future<List<BlogModel>> getBlogs({
    String? category,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'Page': page.toString(),
        'PageSize': pageSize.toString(),
      };
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['Category'] = category;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['Keyword'] = keyword.trim();
      }

      final baseUri = Uri.parse('${ApiConstants.baseUrl}/api/v1/blogs');
      final uri = baseUri.replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final dynamic items = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['items'])
            : decoded;
        if (items is List && items.isNotEmpty) {
          return items.map((e) => BlogModel.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    return MockData.blogs;
  }

  /// Lấy danh sách địa điểm khám phá tìm kiếm & lọc
  Future<List<PlaceModel>> getPlaces() async {
    final res = await PlaceApiService().searchPlaces(const PlaceFilterParams(pageSize: 50));
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      return res.data!;
    }
    return MockData.places;
  }

  /// Lấy danh sách tours trải nghiệm
  Future<List<TourModel>> getTours() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.tours;
  }

  /// Lấy bộ sưu tập nổi bật
  Future<CollectionModel> getFeaturedCollection() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.featuredCollection;
  }

  /// Lấy thông tin tài khoản người dùng hiện tại
  Future<UserModel> getUserProfile({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await AuthService().getCachedUser();
      if (cached != null) return cached;
    }

    final profileRes = await AuthService().getProfile();
    if (profileRes.success && profileRes.data != null) {
      return profileRes.data!;
    }

    final cached = await AuthService().getCachedUser();
    if (cached != null) return cached;

    return MockData.currentUser;
  }

  /// Đăng nhập
  Future<bool> login(String email, String password) async {
    final res = await AuthService().login(email: email, password: password);
    return res.success;
  }

  /// Đăng ký
  Future<bool> register({
    required String fullName,
    String? username,
    required String email,
    required String password,
  }) async {
    final res = await AuthService().register(
      fullName: fullName,
      email: email,
      password: password,
    );
    return res.success;
  }
}
