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
import 'itinerary_api_service.dart';
import 'blog_api_service.dart';

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

      final baseUri = Uri.parse('${ApiConstants.baseUrl}/api/foods');
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

  /// Lấy danh sách lịch trình từ API database backend
  Future<List<ItineraryModel>> getItineraries({
    String? duration,
    String? keyword,
    String? region,
    String? budget,
    int page = 1,
    int pageSize = 50,
  }) async {
    return ItineraryApiService().getItineraries(
      duration: duration,
      keyword: keyword,
      region: region,
      budget: budget,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Lấy chi tiết lịch trình từ database
  Future<ItineraryModel?> getItineraryDetail(int id) async {
    return ItineraryApiService().getItineraryDetail(id);
  }

  /// Lưu hoặc bỏ lưu lịch trình
  Future<bool> saveItinerary(int id, {ItineraryModel? itinerary, bool isSaving = true}) async {
    return ItineraryApiService().saveItinerary(id, itinerary: itinerary, isSaving: isSaving);
  }

  /// Lấy danh sách ID các lịch trình đã áp dụng
  Future<Set<int>> getAppliedItineraryIds() async {
    return ItineraryApiService().getAppliedItineraryIds();
  }

  /// Áp dụng hoặc bỏ áp dụng lịch trình chuyến đi
  Future<bool> applyItinerary(int id, {ItineraryModel? itinerary, bool isApplying = true}) async {
    return ItineraryApiService().applyItinerary(id, itinerary: itinerary, isApplying: isApplying);
  }

  /// Tạo chuyến đi mới trên Database
  Future<ItineraryModel?> createNewTrip({
    String title = 'Chuyến đi của tôi',
    String? description,
    String? destination = 'Việt Nam',
    String? region = 'Miền Bắc',
  }) async {
    return ItineraryApiService().createNewTrip(
      title: title,
      description: description,
      destination: destination,
      region: region,
    );
  }

  /// Lấy danh sách bài viết blog
  Future<List<BlogModel>> getBlogs({
    String? category,
    String? keyword,
    String? region,
    String? province,
    int page = 1,
    int pageSize = 50,
  }) async {
    return BlogApiService().getBlogs(
      category: category,
      keyword: keyword,
      region: region,
      province: province,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Lấy bài viết cẩm nang nổi bật
  Future<BlogModel?> getFeaturedBlog() async {
    return BlogApiService().getFeaturedBlog();
  }

  /// Lấy chi tiết bài viết cẩm nang
  Future<BlogModel?> getBlogDetail(dynamic idOrSlug) async {
    return BlogApiService().getBlogDetail(idOrSlug);
  }

  /// Thích / Bỏ thích bài viết cẩm nang
  Future<bool> toggleBlogLike(dynamic id) async {
    return BlogApiService().toggleLike(id);
  }

  /// Lưu / Bỏ lưu bài viết cẩm nang
  Future<bool> toggleBlogSave(dynamic id) async {
    return BlogApiService().toggleSave(id);
  }

  /// Lấy danh sách địa điểm khám phá tìm kiếm & lọc
  Future<List<PlaceModel>> getPlaces() async {
    final res = await PlaceApiService().searchPlaces(const PlaceFilterParams(pageSize: 50));
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      return res.data!;
    }
    return MockData.places;
  }

  /// Lấy danh sách tours trải nghiệm từ địa điểm thực tế
  Future<List<TourModel>> getTours() async {
    try {
      final res = await PlaceApiService().searchPlaces(const PlaceFilterParams(pageSize: 10));
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        return res.data!.map((p) => TourModel(
          id: p.id.toString(),
          title: p.name,
          price: 'Miễn phí / Khám phá',
          priceValue: 0,
          rating: p.rating,
          reviews: p.reviews,
          imageUrl: p.img.isNotEmpty ? p.img : 'https://images.unsplash.com/photo-1528127269322-539801943592?w=900&h=600&fit=crop&auto=format',
          badge: p.category.isNotEmpty ? p.category : 'Điểm đến',
          location: p.province,
          description: p.desc,
        )).toList();
      }
    } catch (_) {}
    return MockData.tours;
  }

  /// Lấy bộ sưu tập nổi bật từ cơ sở dữ liệu
  Future<CollectionModel> getFeaturedCollection() async {
    try {
      final res = await PlaceApiService().getFeaturedCollections(count: 1);
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final col = res.data!.first;
        final tours = await getTours();
        return CollectionModel(
          id: col.id.toString(),
          title: col.title,
          subtitle: col.description ?? 'Bộ sưu tập tuyển chọn',
          description: col.description ?? '',
          badge: 'Nổi bật',
          tours: tours,
        );
      }
    } catch (_) {}
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
