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
    // Giả lập độ trễ mạng nhẹ (mô phỏng gọi API thực tế)
    await Future.delayed(const Duration(milliseconds: 200));

    if (region == null) {
      return MockData.destinations;
    }
    return MockData.destinations.where((d) => d.region == region).toList();
  }

  /// Lấy chi tiết một điểm đến theo ID
  Future<DestinationModel?> getDestinationById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return MockData.destinations.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách ẩm thực địa phương
  Future<List<FoodModel>> getFoods() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.foods;
  }

  /// Lấy danh sách lịch trình gợi ý
  Future<List<ItineraryModel>> getItineraries() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.itineraries;
  }

  /// Lấy danh sách bài viết blog
  Future<List<BlogModel>> getBlogs() async {
    await Future.delayed(const Duration(milliseconds: 200));
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
